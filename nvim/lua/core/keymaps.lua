-- basic editing keymaps, plus setup() of the modules that own the rest

local M = {}

local function git_root()
  local buf = vim.api.nvim_buf_get_name(0)
  return vim.fs.root(buf ~= '' and buf or vim.fn.getcwd(), '.git')
end

function M.setup()
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- `unnamedplus` routes deletes through + too; "0 only holds the last yank
  vim.keymap.set({ 'n', 'x' }, '<leader>v', '"0p', { desc = 'Paste last yank' })
  vim.keymap.set({ 'n', 'x' }, '<leader>V', '"0P', { desc = 'Paste last yank (above)' })

  -- i/a on an empty line reindent via cc, which respects indentexpr
  local function smart_insert(fallback)
    return function()
      return #vim.api.nvim_get_current_line() == 0 and '"_cc' or fallback
    end
  end
  vim.keymap.set('n', 'i', smart_insert 'i', { expr = true, desc = 'Insert (smart indent on empty line)' })
  vim.keymap.set('n', 'a', smart_insert 'a', { expr = true, desc = 'Append (smart indent on empty line)' })

  -- m/M take over line ends, so gm sets marks
  vim.keymap.set({ 'n', 'x', 'o' }, 'm', '^', { desc = 'First non-blank character' })
  vim.keymap.set({ 'n', 'x', 'o' }, 'M', '$', { desc = 'End of line' })
  vim.keymap.set('n', 'gm', 'm', { desc = 'Set mark' })

  vim.keymap.set('n', '<leader>i', 'i<Space><Esc>', { desc = '[I]nsert space' })

  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- wrapper chars (<>, (), [], quotes) come through when the treesitter
  -- highlighter is inactive or the <cfile> fallback is used
  vim.keymap.set('n', 'gx', function()
    local urls = require('vim.ui')._get_urls()
    for _, url in ipairs(urls) do
      local cleaned = url:gsub('^[%<%(%[%"\']+', ''):gsub('[%>%)%]%"\']+$', '')
      vim.ui.open(cleaned)
    end
  end, { desc = 'Open URL/file under cursor (strip wrappers)' })

  vim.keymap.set('n', '<leader>by', function()
    local path = vim.fn.expand '%:p'
    vim.fn.setreg('+', path)
    vim.notify(path, vim.log.levels.INFO)
  end, { desc = '[Y]ank file path' })

  vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>', { desc = 'File [E]xplorer' })

  vim.keymap.set('n', '<leader>g', function()
    if not git_root() and not (vim.env.GIT_DIR and vim.env.GIT_WORK_TREE) then
      vim.notify('not in a git repository', vim.log.levels.WARN)
      return
    end
    vim.cmd 'LazyGit'
  end, { desc = 'Lazy[G]it' })

  vim.keymap.set('n', '<leader>u', function()
    vim.cmd 'packadd nvim.undotree'
    require('undotree').open { command = '60vnew' }
  end, { desc = '[U]ndo tree' })

  require('core.folding').setup()
  require('features.lists').setup()
  require('features.diag-scan').setup()
  require('core.windows').setup()
  require('core.macos-nav').setup()
  require('core.refresh').setup()
  require('core.spellcheck').setup()
  require('features.build').setup()
  require('features.qf-auto-clear').setup()
  require('features.binary-view').setup()
  require('features.go').setup()
  require('features.snippets').setup()
end

return M
