-- Core autocommands

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
    command = 'checktime',
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
      local _, win = vim.diagnostic.open_float(nil, { focusable = false, scope = 'cursor' })
      if win then
        vtext_hidden = true
        vim.diagnostic.config { virtual_text = false }
      end
    end,
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    desc = 'Restore virtual text after diagnostic float closes',
    group = diag_float_group,
    callback = function()
      if vtext_hidden then
        vtext_hidden = false
        vim.diagnostic.config { virtual_text = { source = 'if_many', spacing = 2 } }
      end
    end,
  })

  -- Dynamic diff highlights (fugitive, diffview, octo)
  require('custom.core.diff-highlights').setup()

  -- Disable swap file for Octo buffers (not needed and causes warnings)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'octo',
    callback = function()
      vim.bo.swapfile = false
    end,
  })

  -- Auto-delete stale swap files instead of showing E325 prompt
  -- If the swap owner process is dead, the swap is stale — delete it and edit normally
  vim.api.nvim_create_autocmd('SwapExists', {
    desc = 'Auto-delete stale swap files',
    callback = function()
      local info = vim.fn.swapinfo(vim.v.swapname)
      local pid = tonumber(info.pid) or 0
      -- pid 0 means the process info is unavailable/corrupt — treat as stale
      -- Otherwise check if the process is still running
      if pid == 0 or vim.fn.getpid() == pid or os.execute('kill -0 ' .. pid .. ' 2>/dev/null') ~= 0 then
        vim.v.swapchoice = 'e' -- edit the file, swap will be overwritten
        vim.notify('Deleted stale swap: ' .. vim.fs.basename(vim.v.swapname), vim.log.levels.INFO)
        os.remove(vim.v.swapname)
      end
      -- If the process IS running, fall through to the default E325 prompt
    end,
  })

  -- Sort JSON keys (strip trailing commas, sort with jq, reformat with prettier)
  local function sort_json_keys(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, '\n')
    local result = vim.fn.system([[perl -0777 -pe 's/,(\s*[\]}])/$1/g' | jq -S . | prettier --parser json]], content)
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

  -- Clean up unnamed empty buffers when opening a file
  -- Removes the default [No Name] buffer that nvim creates at startup
  local cleanup_group = vim.api.nvim_create_augroup('cleanup-empty-buffers', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    desc = 'Delete unnamed empty buffers',
    group = cleanup_group,
    callback = function()
      -- Get all buffers
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        -- Check if buffer is: unnamed, empty, not modified, not the current buffer, and a normal buffer
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
    end,
  })
end

return M
