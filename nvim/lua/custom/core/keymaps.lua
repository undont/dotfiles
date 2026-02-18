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
