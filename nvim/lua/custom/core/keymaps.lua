-- Core keymaps: basic editing tweaks plus delegation to focused modules.
-- Plugin-specific keymaps are defined with their plugins.

local M = {}

function M.setup()
  -- Clear search highlight
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- dd deletes without yanking; dy yanks and deletes (original dd behaviour).
  -- The operator-pending 'y' motion means "current line" (like _), so dy = d + line.
  vim.keymap.set('n', 'dd', '"_dd')
  vim.keymap.set('o', 'y', '_')

  -- Smart i/a on empty lines: reindent via cc (which respects indentexpr)
  -- rather than dropping the cursor at column 0. Uses the black hole register
  -- so the empty line contents don't clobber the unnamed register.
  local function smart_insert(fallback)
    return function()
      return #vim.api.nvim_get_current_line() == 0 and '"_cc' or fallback
    end
  end
  vim.keymap.set('n', 'i', smart_insert 'i', { expr = true, desc = 'Insert (smart indent on empty line)' })
  vim.keymap.set('n', 'a', smart_insert 'a', { expr = true, desc = 'Append (smart indent on empty line)' })

  -- Line navigation: m/M for beginning/end of line, gm for marks
  vim.keymap.set({ 'n', 'v', 'o' }, 'm', '^', { desc = 'First non-blank character' })
  vim.keymap.set({ 'n', 'v', 'o' }, 'M', '$', { desc = 'End of line' })
  vim.keymap.set('n', 'gm', 'm', { desc = 'Set mark' })

  -- Insert space at cursor without leaving normal mode
  vim.keymap.set('n', '<leader>i', 'i<Space><Esc>', { desc = '[I]nsert space' })

  -- Terminal mode escape
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- gx: open URL under cursor, stripping wrapper chars (<>, (), [], quotes)
  -- that leak through when the TS highlighter isn't active or the fallback
  -- <cfile> path is used (e.g. markdown autolinks <https://...> in buffers
  -- without markdown_inline parsed).
  vim.keymap.set('n', 'gx', function()
    local urls = require('vim.ui')._get_urls()
    for _, url in ipairs(urls) do
      local cleaned = url:gsub('^[%<%(%[%"\']+', ''):gsub('[%>%)%]%"\']+$', '')
      vim.ui.open(cleaned)
    end
  end, { desc = 'Open URL/file under cursor (strip wrappers)' })

  -- Copy buffer path to clipboard
  vim.keymap.set('n', '<leader>by', function()
    local path = vim.fn.expand '%:p'
    vim.fn.setreg('+', path)
    vim.notify(path, vim.log.levels.INFO)
  end, { desc = '[Y]ank file path' })

  -- File explorer
  vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>', { desc = 'File [E]xplorer' })

  -- Git UI
  vim.keymap.set('n', '<leader>g', '<cmd>LazyGit<CR>', { desc = 'Lazy[G]it' })

  -- Undo tree
  vim.keymap.set('n', '<leader>u', function()
    vim.cmd 'packadd nvim.undotree'
    require('undotree').open { command = '60vnew' }
  end, { desc = '[U]ndo tree' })

  -- Focused modules own their own keymaps
  require('custom.core.folding').setup()
  require('custom.features.lists').setup()
  require('custom.core.windows').setup()
  require('custom.core.macos-nav').setup()
  require('custom.core.refresh').setup()
  require('custom.core.spellcheck').setup()
  require('custom.features.build').setup()
  require('custom.features.binary-view').setup()
end

return M
