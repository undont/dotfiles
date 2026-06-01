-- File navigation: Harpoon2 for quick marks, Oil for filesystem-as-buffer.

-- Close oil, restoring the dashboard if oil was opened from it. oil.close()
-- restores `oil_original_buffer`, but the snacks dashboard is bufhidden=wipe,
-- so launching oil over it wipes it; oil then falls back to a blank `enew`
-- buffer. Detect that empty landing buffer and re-render the dashboard,
-- matching snacks' own "empty buffer on startup" behaviour.
local function oil_close()
  require('oil').close()
  local buf = vim.api.nvim_get_current_buf()
  local empty = vim.api.nvim_buf_get_name(buf) == ''
    and vim.bo[buf].buftype == ''
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''
  if empty and Snacks and Snacks.dashboard then
    -- open() merges partial opts with the configured dashboard defaults, so the
    -- "missing sections/formats" check on snacks.dashboard.Opts is a false positive.
    ---@diagnostic disable-next-line: missing-fields
    Snacks.dashboard.open { win = vim.api.nvim_get_current_win() }
  end
end

return {
  -- Oil: filesystem-as-buffer
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '-', '<cmd>Oil<CR>', desc = 'Oil: Open parent directory' },
    },
    opts = {
      default_file_explorer = false,
      columns = { 'icon' },
      view_options = { show_hidden = true },
      keymaps = {
        ['-'] = { mode = 'n', callback = oil_close },
        ['<BS>'] = { 'actions.parent', mode = 'n' },
      },
    },
  },

  -- Harpoon2: quick file navigation
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    event = 'VeryLazy',
    config = function()
      local harpoon = require 'harpoon'
      harpoon:setup {
        settings = {
          save_on_toggle = true,
          sync_on_ui_close = true,
        },
      }
      harpoon:extend {
        UI_CREATE = function(cx)
          vim.keymap.set('n', 'o', '<CR>', { buffer = cx.bufnr, remap = true, silent = true })
        end,
      }

      -- Keymaps
      vim.keymap.set('n', '<leader>ha', function()
        harpoon:list():add()
      end, { desc = '[H]arpoon: [a]dd file' })

      vim.keymap.set('n', '<leader>hl', function()
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end, { desc = '[H]arpoon: [l]ist files' })

      -- Quick access to files 1-4 (easier than <leader>h1-4)
      local function select_harpoon_file(index)
        local list = harpoon:list()
        local item = list:get(index)
        if item then
          list:select(index)
        else
          vim.notify('Harpoon: slot ' .. index .. ' is empty', vim.log.levels.INFO)
        end
      end

      vim.keymap.set('n', '<leader>1', function()
        select_harpoon_file(1)
      end, { desc = 'Harpoon: file 1' })

      vim.keymap.set('n', '<leader>2', function()
        select_harpoon_file(2)
      end, { desc = 'Harpoon: file 2' })

      vim.keymap.set('n', '<leader>3', function()
        select_harpoon_file(3)
      end, { desc = 'Harpoon: file 3' })

      vim.keymap.set('n', '<leader>4', function()
        select_harpoon_file(4)
      end, { desc = 'Harpoon: file 4' })

      -- Remove current file from harpoon list
      vim.keymap.set('n', '<leader>hd', function()
        harpoon:list():remove()
      end, { desc = '[H]arpoon: [d]elete current file' })

      -- Clear all harpoon marks (capital X = harder to accidentally press)
      vim.keymap.set('n', '<leader>hX', function()
        harpoon:list():clear()
      end, { desc = '[H]arpoon: clear all (X marks the spot)' })

      -- Telescope integration for harpoon
      local has_telescope, _ = pcall(require, 'telescope')
      if has_telescope then
        vim.keymap.set('n', '<leader>hs', function()
          require('telescope').extensions.harpoon.marks(require('telescope.themes').get_dropdown {})
        end, { desc = '[H]arpoon: [s]earch in Telescope' })
      end
    end,
  },
}
