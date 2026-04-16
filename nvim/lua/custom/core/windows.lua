-- Window navigation, zoom, and resize keymaps.

local M = {}

local function toggle_zoom()
  if vim.t.zoomed then
    vim.cmd 'tab close'
  elseif vim.fn.winnr '$' > 1 then
    vim.cmd 'tab split'
    vim.t.zoomed = true
  end
end

function M.setup()
  -- Navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Zoom (toggle via tab)
  vim.keymap.set('n', '<leader>z', toggle_zoom, { desc = 'Toggle [Z]oom' })

  -- Resize (small increments)
  vim.keymap.set('n', '<leader>wh', '<cmd>vertical resize -5<CR>', { desc = 'Resize [H] left' })
  vim.keymap.set('n', '<leader>wl', '<cmd>vertical resize +5<CR>', { desc = 'Resize [L] right' })
  vim.keymap.set('n', '<leader>wj', '<cmd>resize -5<CR>', { desc = 'Resize [J] down' })
  vim.keymap.set('n', '<leader>wk', '<cmd>resize +5<CR>', { desc = 'Resize [K] up' })

  -- Maximise in a direction
  vim.keymap.set('n', '<leader>wH', '<cmd>vertical resize 1<CR>', { desc = 'Maximise [H] left (shrink width)' })
  vim.keymap.set('n', '<leader>wL', '<cmd>vertical resize 999<CR>', { desc = 'Maximise [L] right (expand width)' })
  vim.keymap.set('n', '<leader>wJ', '<cmd>resize 1<CR>', { desc = 'Maximise [J] down (shrink height)' })
  vim.keymap.set('n', '<leader>wK', '<cmd>resize 999<CR>', { desc = 'Maximise [K] up (expand height)' })

  -- Equalise
  vim.keymap.set('n', '<leader>w=', '<C-w>=', { desc = '[=] Equalise window sizes' })
end

return M
