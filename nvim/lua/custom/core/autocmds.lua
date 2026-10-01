-- core autocommands

vim.filetype.add {
  extension = {
    template = 'template',
  },
}

local M = {}

function M.setup()
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight on yank',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
      if vim.hl.hl_op then
        vim.hl.hl_op(nil)
      else
        vim.hl.on_yank()
      end
    end,
  })

  -- no BufEnter: a plugin spawning buffers (e.g. differ) would run :checktime
  -- across every loaded buffer, racing the autosave below into a
  -- `(L)oad File` prompt
  local reload_group = vim.api.nvim_create_augroup('auto-reload', { clear = true })
  vim.api.nvim_create_autocmd({ 'FocusGained', 'CursorHold' }, {
    desc = 'Check for external file changes',
    group = reload_group,
    callback = function()
      if vim.fn.getcmdwintype() == '' then
        vim.cmd.checktime()
      end
    end,
  })

  -- `autoread` is bypassed for a `modified` buffer and prompts instead. the
  -- auto-save below has already written local edits by then
  vim.api.nvim_create_autocmd('FileChangedShell', {
    desc = 'Always reload externally-changed files without prompting',
    group = reload_group,
    callback = function()
      vim.v.fcs_choice = 'reload'
    end,
  })

  -- restore the cursor to the `"` mark, centred. a background bufload runs
  -- this in an autocmd window that is gone when the scheduled zz fires, hence
  -- the window re-check. git reuses one path for commit messages, so its mark
  -- points into the previous one
  vim.api.nvim_create_autocmd('BufReadPost', {
    callback = function(args)
      if vim.tbl_contains({ 'gitcommit', 'gitrebase' }, vim.bo[args.buf].filetype) then
        return
      end
      local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
      if mark[1] < 1 or mark[1] > vim.api.nvim_buf_line_count(args.buf) then
        return
      end
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_cursor(win, mark)
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == args.buf then
          vim.api.nvim_win_call(win, function()
            vim.cmd 'normal! zz'
          end)
        end
      end)
    end,
  })

  -- auto-save. FocusLost/BufLeave leave the buffer clean before an external
  -- edit, so the FocusGained checktime above reloads without prompting
  local autosave_group = vim.api.nvim_create_augroup('auto-save', { clear = true })
  local autosaving = false
  vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged', 'FocusLost', 'BufLeave' }, {
    desc = 'Auto-save on text change or focus loss',
    group = autosave_group,
    callback = function(ev)
      local buf = ev.buf
      if autosaving or not (vim.bo[buf].modifiable and vim.bo[buf].modified and vim.fn.bufname(buf) ~= '' and vim.bo[buf].buftype == '') then
        return
      end
      autosaving = true
      pcall(function()
        vim.api.nvim_buf_call(buf, function()
          vim.cmd 'silent! write'
        end)
        -- autocmds don't nest, so this `:write` emits no write events.
        -- BufWritePost is re-emitted for its consumers (neotest re-discovers
        -- test positions there); `nested` would also run BufWritePre
        -- (format-on-save) on every edit
        if not vim.bo[buf].modified then
          vim.api.nvim_exec_autocmds('BufWritePost', { buffer = buf })
        end
      end)
      autosaving = false
    end,
  })

  -- vault notes are written in place. `backupcopy=auto` may rename the
  -- original and create a new file, which a sync watcher on the vault
  -- replicates as a delete followed by a create. `backupcopy=yes` keeps the
  -- inode, so the watcher sees a change
  local vault_group = vim.api.nvim_create_augroup('vault-inplace-write', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
    desc = 'Write vault notes in place so the sync watcher sees no delete',
    group = vault_group,
    pattern = vim.env.HOME .. '/obsidian/*',
    callback = function()
      vim.bo.backupcopy = 'yes'
    end,
  })

  -- gopls has no `constant` token type: consts, nil and iota arrive as
  -- `variable` + `readonly`, func-typed vars as `variable` + `signature`.
  -- clearing @lsp.type.variable lets treesitter's @constant and
  -- @function.call show through the higher-priority semantic token.
  -- treesitter only captures @constant at the declaration, so the readonly
  -- typemod carries it to reference sites
  local function lsp_semantic_token_hls()
    vim.api.nvim_set_hl(0, '@lsp.type.variable', {})
    vim.api.nvim_set_hl(0, '@lsp.typemod.variable.readonly', { link = '@constant' })
    local call = vim.api.nvim_get_hl(0, { name = '@function.call', link = false })
    vim.api.nvim_set_hl(0, '@lsp.typemod.variable.signature', { fg = call.fg, italic = true })
  end
  vim.api.nvim_create_autocmd('ColorScheme', {
    desc = 'Restyle LSP semantic token groups for the new colourscheme',
    group = vim.api.nvim_create_augroup('lsp-semantic-token-overrides', { clear = true }),
    callback = lsp_semantic_token_hls,
  })
  lsp_semantic_token_hls()

  -- lazy.nvim links `LazyDimmed` (chore/deps commits) to `Conceal`, which is
  -- near-invisible on most dark themes
  vim.api.nvim_create_autocmd('ColorScheme', {
    desc = 'Make Lazy.nvim dimmed commit lines legible',
    group = vim.api.nvim_create_augroup('lazy-dimmed-readable', { clear = true }),
    callback = function()
      vim.api.nvim_set_hl(0, 'LazyDimmed', { link = 'Comment' })
    end,
  })
  vim.api.nvim_set_hl(0, 'LazyDimmed', { link = 'Comment' })

  -- SnippetTabstop defaults to Visual, a bright block over the argument just
  -- typed. SnippetTabstopActive links here by default
  local snippet_group = vim.api.nvim_create_augroup('snippet-tabstop', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    desc = 'Subtle snippet tabstop highlight',
    group = snippet_group,
    callback = function()
      vim.api.nvim_set_hl(0, 'SnippetTabstop', { link = 'LspReferenceText' })
    end,
  })
  vim.api.nvim_set_hl(0, 'SnippetTabstop', { link = 'LspReferenceText' })

  -- the built-in session only ends on cursor moves in insert/select mode, so
  -- Esc leaves the tabstop extmark alive. `*:n`, not InsertLeave, so tabstop
  -- jumps via select mode survive
  vim.api.nvim_create_autocmd('ModeChanged', {
    desc = 'Stop snippet session on return to normal mode',
    group = snippet_group,
    pattern = '*:n',
    callback = function()
      if vim.snippet.active() then
        vim.snippet.stop()
      end
    end,
  })

  local diff_highlights = require 'custom.core.diff-highlights'
  diff_highlights.setup()

  -- render-markdown links code blocks to ColorColumn by default, which
  -- matches the CursorLine tint
  local function apply_markdown_code_highlights()
    local function get(group, fallback)
      local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
      return hl.bg or hl.fg or fallback
    end

    local cursorline_bg = get('CursorLine', 0x2a2a2a)
    local colorcolumn_bg = get('ColorColumn', cursorline_bg)
    local normal_fg = get('Normal', 0xd4d4d4)
    local code_bg = diff_highlights.tint_bg(colorcolumn_bg, 0.35)
    local inline_bg = diff_highlights.tint_bg(normal_fg, 0.10)

    vim.api.nvim_set_hl(0, 'RenderMarkdownCode', { bg = code_bg })
    vim.api.nvim_set_hl(0, 'RenderMarkdownCodeBorder', { bg = code_bg })
    vim.api.nvim_set_hl(0, 'RenderMarkdownCodeInline', { bg = inline_bg })
    vim.api.nvim_set_hl(0, 'RenderMarkdownInlineHighlight', { bg = inline_bg })
  end

  vim.api.nvim_create_autocmd('ColorScheme', {
    desc = 'Make render-markdown code blocks distinct from CursorLine',
    group = vim.api.nvim_create_augroup('render-markdown-highlights', { clear = true }),
    callback = apply_markdown_code_highlights,
  })
  apply_markdown_code_highlights()

  -- `User RealDotnetFile` fires only for real cs/razor files. roslyn.nvim
  -- lazy-loads on it instead of `ft = 'cs'`, so diff buffers don't load it
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'cs', 'razor' },
    callback = function(args)
      if vim.bo[args.buf].buftype ~= '' then
        return
      end
      vim.api.nvim_exec_autocmds('User', { pattern = 'RealDotnetFile' })
    end,
  })

  -- strip trailing commas, sort keys with jq, reformat with prettier
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

  -- shada restores the jumplist regardless of cwd, so <C-o> in a fresh
  -- instance would walk into the last session's repo. only the current
  -- window's jumplist is stored
  vim.api.nvim_create_autocmd('VimEnter', {
    desc = 'Drop the shada-restored jumplist',
    group = vim.api.nvim_create_augroup('jumplist-scope', { clear = true }),
    command = 'clearjumps',
  })

  -- stop LSP servers and terminal jobs on exit so they don't orphan (roslyn,
  -- easy-dotnet build servers)
  vim.api.nvim_create_autocmd('VimLeavePre', {
    desc = 'Stop LSP clients, DAP, and terminal jobs on exit',
    group = vim.api.nvim_create_augroup('cleanup-on-exit', { clear = true }),
    callback = function()
      for _, client in ipairs(vim.lsp.get_clients()) do
        client:stop(true)
      end

      -- a require here would load the whole plugin at exit
      if package.loaded['dap'] then
        pcall(function()
          require('dap').terminate()
        end)
      end

      -- deleting a terminal buffer terminates its child process
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end,
  })

  -- delete unnamed empty buffers when a file opens: the startup [No Name]
  -- buffer and blank landing buffers. only buffers created unnamed are
  -- tracked, so BufEnter checks that set rather than every open buffer. a
  -- tracked buffer that has been named, filled or given a buftype drops out
  local cleanup_group = vim.api.nvim_create_augroup('cleanup-empty-buffers', { clear = true })
  local unnamed = {}

  local function track(buf)
    if vim.api.nvim_buf_is_valid(buf) and vim.fn.bufname(buf) == '' then
      unnamed[buf] = true
    end
  end

  -- the startup [No Name] buffer predates this autocmd, so seed from the list
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    track(buf)
  end

  vim.api.nvim_create_autocmd({ 'BufNew', 'BufAdd' }, {
    desc = 'Track unnamed buffers as deletion candidates',
    group = cleanup_group,
    callback = function(args)
      track(args.buf)
    end,
  })

  local function is_disposable(buf)
    return vim.api.nvim_buf_is_valid(buf)
      and vim.fn.bufname(buf) == ''
      and vim.api.nvim_buf_line_count(buf) == 1
      and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''
      and not vim.bo[buf].modified
      and vim.bo[buf].buftype == ''
  end

  vim.api.nvim_create_autocmd('BufEnter', {
    desc = 'Delete unnamed empty buffers',
    group = cleanup_group,
    callback = function()
      if next(unnamed) == nil then
        return
      end
      -- scheduled: a plugin splitting windows can trigger BufEnter mid-layout
      vim.schedule(function()
        local current = vim.api.nvim_get_current_buf()
        for buf in pairs(unnamed) do
          if not is_disposable(buf) then
            unnamed[buf] = nil
          elseif buf ~= current then
            unnamed[buf] = nil
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end
      end)
    end,
  })
end

return M
