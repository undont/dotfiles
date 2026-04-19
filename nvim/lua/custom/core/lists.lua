-- Quickfix and location list keymaps: toggle, navigate, clear, and
-- route diagnostics into the native lists.

local M = {}

local function toggle_quickfix()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 and win.loclist == 0 then
      vim.cmd 'cclose'
      return
    end
  end
  vim.cmd 'botright copen'
end

local function toggle_loclist()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.loclist == 1 then
      vim.cmd 'lclose'
      return
    end
  end
  local ok = pcall(vim.cmd.lopen)
  if not ok then
    vim.notify('No location list for current window', vim.log.levels.WARN)
  end
end

-- Override mini.bracketed's ]q/[q and ]l/[l with empty-list notifications.
-- mini.bracketed silently no-ops when the list is empty, which is confusing.
-- :cnext/:cprev echo "(N of M): ..." which ui2 surfaces as a notification.
-- Silence via the :silent! modifier while keeping mini.bracketed's wrap-around.
local function bracketed_qf(direction)
  return function()
    if vim.tbl_isempty(vim.fn.getqflist()) then
      vim.notify('Quickfix list is empty', vim.log.levels.WARN)
      return
    end
    vim.cmd(string.format([[silent! lua require('mini.bracketed').quickfix(%q)]], direction))
  end
end

local function bracketed_loc(direction)
  return function()
    if vim.tbl_isempty(vim.fn.getloclist(0)) then
      vim.notify('Location list is empty', vim.log.levels.WARN)
      return
    end
    vim.cmd(string.format([[silent! lua require('mini.bracketed').location(%q)]], direction))
  end
end

function M.setup()
  -- Dashboard escape is handled globally in autocmds.lua (FileType qf autocmd)
  vim.keymap.set('n', '<leader>xq', toggle_quickfix, { desc = '[Q]uickfix list toggle' })
  vim.keymap.set('n', '<leader>xl', toggle_loclist, { desc = '[L]ocation list toggle' })

  -- Diagnostics into native lists
  vim.keymap.set('n', '<leader>xx', function()
    vim.diagnostic.setqflist()
  end, { desc = 'All [D]iagnostics to quickfix' })
  vim.keymap.set('n', '<leader>xX', function()
    vim.diagnostic.setloclist()
  end, { desc = 'Buffer diagnostics to loclist' })

  vim.keymap.set('n', ']q', bracketed_qf 'forward', { desc = 'Next quickfix entry' })
  vim.keymap.set('n', '[q', bracketed_qf 'backward', { desc = 'Previous quickfix entry' })
  vim.keymap.set('n', ']l', bracketed_loc 'forward', { desc = 'Next location entry' })
  vim.keymap.set('n', '[l', bracketed_loc 'backward', { desc = 'Previous location entry' })

  vim.keymap.set('n', '<leader>xcq', function()
    vim.fn.setqflist({}, 'r')
    vim.cmd 'cclose'
  end, { desc = '[C]lear [Q]uickfix list' })

  vim.keymap.set('n', '<leader>xcl', function()
    vim.fn.setloclist(0, {}, 'r')
    vim.cmd 'lclose'
  end, { desc = '[C]lear [L]ocation list' })

  vim.keymap.set('n', '<leader>xcc', function()
    vim.fn.setqflist({}, 'r')
    vim.fn.setloclist(0, {}, 'r')
    vim.cmd 'cclose'
    vim.cmd 'lclose'
  end, { desc = '[C]lear both quickfix and location lists' })
end

return M
