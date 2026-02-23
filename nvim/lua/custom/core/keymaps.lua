-- Core keymaps (non-plugin specific)
-- Plugin-specific keymaps are defined with their plugins

local M = {}

function M.setup()
  -- Clear search highlight
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Build
  vim.keymap.set('n', '<leader>q', function()
    require('custom.core.build').run()
  end, { desc = 'Build project' })

  -- File explorer
  vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>', { desc = 'File [E]xplorer' })

  -- Git UI
  vim.keymap.set('n', '<leader>g', '<cmd>LazyGit<CR>', { desc = 'Lazy[G]it' })

  -- Theme reload
  vim.keymap.set('n', '<leader>tr', function()
    require('custom.core.theme').reload(true)
  end, { desc = '[R]eload theme' })

  -- Shift+Enter → Enter (Ghostty sends Alt+Enter / \x1b\r)
  vim.keymap.set({ 'i', 'n', 'v', 'c' }, '<M-CR>', '<CR>')

  -- Terminal mode escape
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- Window navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Window resize
  vim.keymap.set('n', '<leader>wh', '<cmd>vertical resize -5<CR>', { desc = 'Resize [H] left' })
  vim.keymap.set('n', '<leader>wl', '<cmd>vertical resize +5<CR>', { desc = 'Resize [L] right' })
  vim.keymap.set('n', '<leader>wj', '<cmd>resize -5<CR>', { desc = 'Resize [J] down' })
  vim.keymap.set('n', '<leader>wk', '<cmd>resize +5<CR>', { desc = 'Resize [K] up' })

  -- Line navigation: m/M for beginning/end of line, gm for marks
  vim.keymap.set({ 'n', 'v', 'o' }, 'm', '^', { desc = 'First non-blank character' })
  vim.keymap.set({ 'n', 'v', 'o' }, 'M', '$', { desc = 'End of line' })
  vim.keymap.set('n', 'gm', 'm', { desc = 'Set mark' })

  -- macOS-style navigation (Opt+arrows = word, Cmd+arrows = line)
  vim.keymap.set('i', '<M-BS>', '<C-w>', { desc = 'Delete word backward (Opt+Backspace)' })
  vim.keymap.set('i', '<D-BS>', '<C-u>', { desc = 'Delete to beginning of line (Cmd+Backspace)' })
  vim.keymap.set({ 'n', 'v' }, '<M-Right>', 'w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set({ 'n', 'v' }, '<M-Left>', 'b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set({ 'n', 'v' }, '<M-f>', 'w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set({ 'n', 'v' }, '<M-b>', 'b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-Left>', '<C-o>b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-Right>', '<C-o>w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set('i', '<M-b>', '<C-o>b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-f>', '<C-o>w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set('i', '<Home>', '<C-o>0', { desc = 'Beginning of line (Cmd+Left)' })
  vim.keymap.set('i', '<End>', '<C-o>$', { desc = 'End of line (Cmd+Right)' })

  -- LuaSnip: Insert Claude comment template
  vim.keymap.set('n', '<leader>cc', function()
    local ls = require 'luasnip'
    local snippets = ls.get_snippets 'all'
    for _, snip in ipairs(snippets) do
      if snip.trigger == 'claudecomment' then
        vim.cmd 'normal! o'
        ls.snip_expand(snip)
        return
      end
    end
  end, { desc = '[C]omment template' })

  -- LuaSnip: Insert Claude user/exchange snippet
  vim.keymap.set('n', '<leader>cu', function()
    local ls = require 'luasnip'
    local snippets = ls.get_snippets 'all'
    for _, snip in ipairs(snippets) do
      if snip.trigger == 'cu' then
        vim.cmd 'normal! o'
        ls.snip_expand(snip)
        return
      end
    end
  end, { desc = '[U]ser exchange snippet' })

  -- Toggle <comment> block state (open <-> resolved)
  vim.keymap.set('n', '<leader>cr', function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local comment_line
    for i = cursor_line, 1, -1 do
      if lines[i]:match '<comment%s+state=' then
        comment_line = i
        break
      end
      if i < cursor_line and lines[i]:match '</comment>' then
        break
      end
    end
    if not comment_line then
      vim.notify('No comment block at cursor', vim.log.levels.WARN)
      return
    end
    for i = comment_line, #lines do
      if lines[i]:match '</comment>' then
        if cursor_line > i then
          vim.notify('No comment block at cursor', vim.log.levels.WARN)
          return
        end
        break
      end
    end
    local line = lines[comment_line]
    local new_line
    if line:match 'state="open"' then
      new_line = line:gsub('state="open"', 'state="resolved"')
    elseif line:match 'state="resolved"' then
      new_line = line:gsub('state="resolved"', 'state="open"')
    else
      vim.notify('Unknown comment state', vim.log.levels.WARN)
      return
    end
    vim.api.nvim_buf_set_lines(0, comment_line - 1, comment_line, false, { new_line })
  end, { desc = 'Toggle comment [R]esolved' })

  -- Delete <comment> block under cursor
  vim.keymap.set('n', '<leader>cd', function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local comment_start
    for i = cursor_line, 1, -1 do
      if lines[i]:match '<comment%s+state=' then
        comment_start = i
        break
      end
      if i < cursor_line and lines[i]:match '</comment>' then
        break
      end
    end
    if not comment_start then
      vim.notify('No comment block at cursor', vim.log.levels.WARN)
      return
    end
    local comment_end
    for i = comment_start, #lines do
      if lines[i]:match '</comment>' then
        if cursor_line > i then
          vim.notify('No comment block at cursor', vim.log.levels.WARN)
          return
        end
        comment_end = i
        break
      end
    end
    if not comment_end then
      vim.notify('No closing </comment> tag found', vim.log.levels.WARN)
      return
    end
    vim.api.nvim_buf_set_lines(0, comment_start - 1, comment_end, false, {})
  end, { desc = '[D]elete comment block' })

  -- Refresh: wipe all buffers, restart LSP, re-source config
  vim.keymap.set('n', '<leader>lR', function()
    local cur_file = vim.fn.expand '%:p'

    -- Stop all LSP clients
    vim.lsp.stop_client(vim.lsp.get_clients(), true)

    -- Wipe all buffers (closes diffview, stale scratch buffers, etc.)
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end

    -- Re-source config
    vim.cmd 'source $MYVIMRC'

    -- Reopen the file we were editing and let LSP re-attach
    vim.defer_fn(function()
      if cur_file ~= '' and vim.fn.filereadable(cur_file) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(cur_file))
      end
      vim.notify('Neovim refreshed', vim.log.levels.INFO)
    end, 200)
  end, { desc = '[R]efresh Neovim (clear buffers, restart LSP)' })

  -- LuaSnip navigation keymaps
  vim.keymap.set({ 'i', 's' }, '<C-k>', function()
    local ls = require 'luasnip'
    if ls.expand_or_jumpable() then
      ls.expand_or_jump()
    end
  end, { desc = 'LuaSnip: Expand or jump to next placeholder' })

  vim.keymap.set({ 'i', 's' }, '<C-j>', function()
    local ls = require 'luasnip'
    if ls.jumpable(-1) then
      ls.jump(-1)
    end
  end, { desc = 'LuaSnip: Jump to previous placeholder' })
end

return M
