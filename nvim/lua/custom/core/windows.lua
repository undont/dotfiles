-- Window navigation, zoom, and resize keymaps.

local M = {}

-- In-tab zoom state, keyed by tabpage. Diffview (and octo's review, a diffview
-- fork) can't use the `tab split` zoom: each scopes its view -- and every panel
-- keymap, e.g. j/k -> next/prev entry -- to the tabpage, so a new tab detaches
-- them and the keys go dead. For those we maximise the window in place instead,
-- stashing the layout to restore later.
local zoom_state = {}

local in_scoped_view = require('custom.core.review-context').is_scoped_view

local function toggle_zoom()
  local tab = vim.api.nvim_get_current_tabpage()

  if vim.t.zoomed then
    local st = zoom_state[tab]
    if st then
      -- In-tab zoom: restore saved window sizes and winfix options.
      if vim.api.nvim_win_is_valid(st.win) then
        vim.api.nvim_win_call(st.win, function()
          vim.cmd(st.restore)
          vim.wo.winfixwidth = st.fixw
          vim.wo.winfixheight = st.fixh
        end)
      end
      zoom_state[tab] = nil
      vim.t.zoomed = false
    else
      -- Tab-split zoom: closing the tab discards its `zoomed` flag.
      vim.cmd 'tab close'
    end
  elseif in_scoped_view() then
    -- winfixwidth/height pin the panel size, so lift them before maximising.
    zoom_state[tab] = {
      win = vim.api.nvim_get_current_win(),
      restore = vim.fn.winrestcmd(),
      fixw = vim.wo.winfixwidth,
      fixh = vim.wo.winfixheight,
    }
    vim.wo.winfixwidth = false
    vim.wo.winfixheight = false
    vim.cmd.wincmd '_'
    vim.cmd.wincmd '|'
    vim.t.zoomed = true
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
