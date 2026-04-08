-- Core autocommands

-- Custom filetype detection
vim.filetype.add {
  extension = {
    template = 'template',
  },
}

local M = {}

function M.setup()
  -- Highlight on yank
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
      vim.hl.on_yank()
    end,
  })

  -- Auto-reload: Check for external changes on focus/buffer events
  local reload_group = vim.api.nvim_create_augroup('auto-reload', { clear = true })
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
    desc = 'Check for external file changes',
    group = reload_group,
    callback = function()
      if vim.fn.getcmdwintype() == '' then
        vim.cmd.checktime()
      end
    end,
  })

  -- Auto-save: Write buffer on change (with debounce via CursorHold)
  local autosave_group = vim.api.nvim_create_augroup('auto-save', { clear = true })
  vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged' }, {
    desc = 'Auto-save on text change',
    group = autosave_group,
    callback = function(ev)
      local buf = ev.buf
      -- Only save if: buffer is modifiable, has a file, is modified, and not a special buffer
      if vim.bo[buf].modifiable and vim.bo[buf].modified and vim.fn.bufname(buf) ~= '' and vim.bo[buf].buftype == '' then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd 'silent! write'
        end)
      end
    end,
  })

  -- Auto-show diagnostic float on cursor hold; hide virtual_text while float is open
  local diag_float_group = vim.api.nvim_create_augroup('diagnostic-float', { clear = true })
  local vtext_hidden = false

  vim.api.nvim_create_autocmd('CursorHold', {
    desc = 'Show diagnostic float and suppress virtual text',
    group = diag_float_group,
    callback = function()
      -- Skip diagnostic float while LSP hover is open
      if vim.b._hover_open then
        return
      end
      local _, win = vim.diagnostic.open_float(nil, { focusable = false, scope = 'cursor' })
      if win then
        vim.b._diag_float_win = win
        vtext_hidden = true
        vim.diagnostic.config { virtual_text = false }
      end
    end,
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    desc = 'Restore virtual text after diagnostic float closes',
    group = diag_float_group,
    callback = function()
      vim.b._hover_open = nil
      if vtext_hidden then
        vtext_hidden = false
        vim.diagnostic.config { virtual_text = { source = 'if_many', spacing = 2 } }
      end
    end,
  })

  -- Link LSP variable tokens to TreeSitter's @variable styling. Leaving the
  -- group empty does not let lower-priority TreeSitter captures show through;
  -- the semantic token still wins, just with Normal-like styling.
  vim.api.nvim_create_autocmd('ColorScheme', {
    desc = 'Use TreeSitter variable styling for LSP variable tokens',
    group = vim.api.nvim_create_augroup('lsp-semantic-token-overrides', { clear = true }),
    callback = function()
      vim.api.nvim_set_hl(0, '@lsp.type.variable', { link = '@variable' })
    end,
  })
  -- Apply immediately for the current colourscheme
  vim.api.nvim_set_hl(0, '@lsp.type.variable', { link = '@variable' })

  -- Auto-clear command-line messages after 1 second
  local msg_clear_timer = vim.uv.new_timer()
  local function schedule_msg_clear()
    msg_clear_timer:stop()
    msg_clear_timer:start(
      4000,
      0,
      vim.schedule_wrap(function()
        if vim.fn.mode() == 'n' then
          vim.cmd.echon()
        end
      end)
    )
  end
  vim.api.nvim_create_autocmd({ 'CmdlineLeave', 'CursorMoved', 'BufWritePost' }, {
    desc = 'Clear command-line messages after a delay',
    group = vim.api.nvim_create_augroup('clear-cmdline-messages', { clear = true }),
    callback = schedule_msg_clear,
  })

  -- Dynamic diff highlights (diffview, octo)
  require('custom.core.diff-highlights').setup()

  -- Disable swap file for Octo buffers (not needed and causes warnings)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'octo',
    callback = function()
      vim.bo.swapfile = false
    end,
  })

  -- Sort JSON keys (strip trailing commas, sort with jq, reformat with prettier)
  local function sort_json_keys(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, '\n')
    local result = vim.fn.system([[set -o pipefail; perl -0777 -pe 's/,(\s*[\]}])/$1/g' | jq -S . | prettier --parser json]], content)
    if vim.v.shell_error == 0 then
      local new_lines = vim.split(result, '\n', { trimempty = true })
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
    else
      vim.notify('JsonSort failed: ' .. result, vim.log.levels.ERROR)
    end
  end

  vim.api.nvim_create_user_command('JsonSort', function()
    sort_json_keys(vim.api.nvim_get_current_buf())
  end, { desc = 'Sort JSON keys' })

  vim.lsp.commands['json.sort'] = function(_, ctx)
    sort_json_keys(ctx.bufnr)
  end

  -- Graceful process cleanup on exit
  -- Explicitly stops LSP servers and terminal jobs so they don't orphan
  -- (dotnet Roslyn, OmniSharp, EasyDotnet build servers, etc.)
  vim.api.nvim_create_autocmd('VimLeavePre', {
    desc = 'Stop LSP clients, DAP, and terminal jobs on exit',
    group = vim.api.nvim_create_augroup('cleanup-on-exit', { clear = true }),
    callback = function()
      -- Stop all LSP clients (Roslyn, OmniSharp, etc.)
      for _, client in ipairs(vim.lsp.get_clients()) do
        client:stop(true)
      end

      -- Terminate debug adapter if running
      pcall(function()
        require('dap').terminate()
      end)

      -- Close all terminal buffers (forces child process termination)
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end,
  })

  -- Clean up unnamed empty buffers when opening a file
  -- Removes the default [No Name] buffer that nvim creates at startup
  -- Deferred via vim.schedule to avoid interfering with plugin layout creation
  -- (e.g. diffview's find_pivot triggers BufEnter mid-layout via 1windo)
  local cleanup_group = vim.api.nvim_create_augroup('cleanup-empty-buffers', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    desc = 'Delete unnamed empty buffers',
    group = cleanup_group,
    callback = function()
      vim.schedule(function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if
            vim.api.nvim_buf_is_valid(buf)
            and vim.fn.bufname(buf) == ''
            and vim.api.nvim_buf_line_count(buf) == 1
            and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''
            and not vim.bo[buf].modified
            and buf ~= vim.api.nvim_get_current_buf()
            and vim.bo[buf].buftype == ''
          then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end
      end)
    end,
  })
end

return M
