-- Core keymaps (non-plugin specific)
-- Plugin-specific keymaps are defined with their plugins

local M = {}

-- Helper function to show help from external file
local function show_nvim_help()
  local help_file = vim.fn.stdpath 'config' .. '/lua/custom/nvim-help.txt'
  local lines = {}

  local file = io.open(help_file, 'r')
  if file then
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()
  else
    lines = { 'Help file not found: ' .. help_file }
  end

  local width = 78
  local height = math.min(#lines, vim.o.lines - 6)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })

  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2) - 1,
    style = 'minimal',
    border = 'rounded',
  }

  vim.api.nvim_open_win(buf, true, win_opts)
  vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = buf, silent = true })
  vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
end

function M.setup()
  -- Clear search highlight
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostics
  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

  -- File explorer
  vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>', { desc = 'Toggle file [E]xplorer' })

  -- Help
  vim.keymap.set('n', '<leader>h', show_nvim_help, { desc = 'Show Nvim [H]elp' })

  -- Git UI
  vim.keymap.set('n', '<leader>g', '<cmd>LazyGit<CR>', { desc = 'Open [G]it UI (LazyGit)' })

  -- Theme reload
  vim.keymap.set('n', '<leader>tr', function()
    require('custom.core.theme').reload(true)
  end, { desc = '[T]heme [R]eload' })

  -- Terminal mode escape
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- Window navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- macOS-style editing in insert mode
  vim.keymap.set('i', '<M-BS>', '<C-w>', { desc = 'Delete word backward (Opt+Backspace)' })
  vim.keymap.set('i', '<D-BS>', '<C-u>', { desc = 'Delete to beginning of line (Cmd+Backspace)' })
  vim.keymap.set('i', '<M-Left>', '<C-o>b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-Right>', '<C-o>w', { desc = 'Move word right (Opt+Right)' })

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
  end, { desc = 'Insert [C]laude [C]omment template' })

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
