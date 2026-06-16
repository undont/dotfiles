-- window navigation, zoom, and resize keymaps

local M = {}

-- in-tab zoom state, keyed by tabpage. Diffview (and octo's review, a diffview
-- fork) can't use the `tab split` zoom: each scopes its view (and every panel
-- keymap, e.g. j/k -> next/prev entry) to the tabpage, so a new tab detaches
-- them and the keys go dead. for those we maximise the window in place instead,
-- stashing the layout to restore later
local zoom_state = {}

local in_scoped_view = require('custom.core.review-context').is_scoped_view

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
  local tab = vim.api.nvim_get_current_tabpage()

  if vim.t.zoomed then
    local st = zoom_state[tab]
    if st then
      -- in-tab zoom: restore saved window sizes and winfix options
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
      -- tab-split zoom: closing the tab discards its `zoomed` flag
      vim.cmd 'tab close'
    end
  elseif in_scoped_view() then
    -- winfixwidth/height pin the panel size, so lift them before maximising
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
  -- navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- zoom (toggle via tab)
  vim.keymap.set('n', '<leader>z', toggle_zoom, { desc = 'Toggle [Z]oom' })

  -- resize (small increments)
  vim.keymap.set('n', '<leader>wh', '<cmd>vertical resize -5<CR>', { desc = 'Resize [H] left' })
  vim.keymap.set('n', '<leader>wl', '<cmd>vertical resize +5<CR>', { desc = 'Resize [L] right' })
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
