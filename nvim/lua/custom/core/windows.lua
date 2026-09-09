-- window navigation, zoom, and resize keymaps

local M = {}

-- native multicursor (nvim 0.13) tracks cursors as extmarks here, and clears
-- them from the default <C-l> map. <C-l> is window nav instead, so it clears
-- cursors when the buffer has any and only then falls through to the wincmd
local mc_ns = vim.api.nvim_create_namespace 'nvim.multicursor'

local function clear_multicursors()
  if #vim.api.nvim_buf_get_extmarks(0, mc_ns, 0, -1, { limit = 1 }) == 0 then
    return false
  end
  vim.api.nvim_buf_clear_namespace(0, mc_ns, 0, -1)
  return true
end

-- height resize only when a window sits above or below. with cmdheight=0 a
-- height resize on a window with no vertical neighbour (e.g. a left/right side
-- panel layout) has nowhere to put the freed rows, so nvim grows the command
-- line and re-exposes the last typed ':' command. width resizes don't spill
local function resize_height(cmd)
  return function()
    if vim.fn.winnr 'j' ~= vim.fn.winnr() or vim.fn.winnr 'k' ~= vim.fn.winnr() then
      vim.cmd(cmd)
    end
  end
end

local function toggle_zoom()
  if vim.t.zoomed then
    -- closing the tab discards its `zoomed` flag
    vim.cmd 'tab close'
  elseif vim.fn.winnr '$' > 1 then
    vim.cmd 'tab split'
    vim.t.zoomed = true
  end
end

function M.setup()
  -- navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', function()
    if not clear_multicursors() then
      vim.cmd.wincmd 'l'
    end
  end, { desc = 'Clear multicursors, else move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- zoom (toggle via tab)
  vim.keymap.set('n', '<leader>z', toggle_zoom, { desc = 'Toggle [Z]oom' })

  -- resize (small increments)
  vim.keymap.set('n', '<leader>wh', '<cmd>vertical resize +5<CR>', { desc = 'Resize [H] left' })
  vim.keymap.set('n', '<leader>wl', '<cmd>vertical resize -5<CR>', { desc = 'Resize [L] right' })
  vim.keymap.set('n', '<leader>wj', resize_height 'resize -5', { desc = 'Resize [J] down' })
  vim.keymap.set('n', '<leader>wk', resize_height 'resize +5', { desc = 'Resize [K] up' })

  -- maximise in a direction
  vim.keymap.set('n', '<leader>wH', '<cmd>vertical resize 1<CR>', { desc = 'Maximise [H] left (shrink width)' })
  vim.keymap.set('n', '<leader>wL', '<cmd>vertical resize 999<CR>', { desc = 'Maximise [L] right (expand width)' })
  vim.keymap.set('n', '<leader>wJ', resize_height 'resize 1', { desc = 'Maximise [J] down (shrink height)' })
  vim.keymap.set('n', '<leader>wK', resize_height 'resize 999', { desc = 'Maximise [K] up (expand height)' })

  -- equalise
  vim.keymap.set('n', '<leader>w=', '<C-w>=', { desc = '[=] Equalise window sizes' })
end

return M
