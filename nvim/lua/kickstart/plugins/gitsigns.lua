-- Adds git related signs to the gutter, as well as utilities for managing changes

return {
  {
    'lewis6991/gitsigns.nvim',
    init = function()
      -- Set gitsigns highlight colours and re-apply after colorscheme changes
      local function set_gitsigns_highlights()
        -- Sign column text colours
        vim.api.nvim_set_hl(0, 'GitSignsAdd', { fg = '#a6e3a1', bold = true })
        vim.api.nvim_set_hl(0, 'GitSignsChange', { fg = '#f9e2af', bold = true })
        vim.api.nvim_set_hl(0, 'GitSignsDelete', { fg = '#f38ba8', bold = true })
        vim.api.nvim_set_hl(0, 'GitSignsTopdelete', { fg = '#f38ba8', bold = true })
        vim.api.nvim_set_hl(0, 'GitSignsChangedelete', { fg = '#fab387', bold = true })
        -- Line number background colours (used in fugitive review mode)
        vim.api.nvim_set_hl(0, 'GitSignsAddNr', { fg = '#a6e3a1', bg = '#1a2e1a' })
        vim.api.nvim_set_hl(0, 'GitSignsChangeNr', { fg = '#f9e2af', bg = '#2e2a1a' })
        vim.api.nvim_set_hl(0, 'GitSignsDeleteNr', {})
        -- Full line background colours (used in fugitive review mode)
        vim.api.nvim_set_hl(0, 'GitSignsAddLn', { bg = '#1a2e1a' })
        vim.api.nvim_set_hl(0, 'GitSignsChangeLn', { bg = '#2e2a1a' })
        vim.api.nvim_set_hl(0, 'GitSignsDeleteLn', {})
        -- Virtual text for inline deleted lines (used in Octo unified review mode)
        vim.api.nvim_set_hl(0, 'GitSignsDeleteVirtLn', { fg = '#6c7086' })
      end

      set_gitsigns_highlights()
      vim.api.nvim_create_autocmd('ColorScheme', { callback = set_gitsigns_highlights })
    end,
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      numhl = false,
      linehl = false,
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, mopts)
          mopts = mopts or {}
          mopts.buffer = bufnr
          vim.keymap.set(mode, l, r, mopts)
        end

        -- Navigation: hunks
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk('next', { wrap = false })
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk('prev', { wrap = false })
          end
        end, { desc = 'Jump to previous git [c]hange' })

        -- Actions
        -- visual mode
        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [s]tage hunk' })
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git [r]eset hunk' })
        -- normal mode
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
        map('n', '<leader>hu', gitsigns.undo_stage_hunk, { desc = 'git [u]ndo stage hunk' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
        map('n', '<leader>hb', gitsigns.blame_line, { desc = 'git [b]lame line' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
        map('n', '<leader>hD', function()
          gitsigns.diffthis '@'
        end, { desc = 'git [D]iff against last commit' })
        -- Toggles
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
        map('n', '<leader>tD', gitsigns.preview_hunk_inline, { desc = '[T]oggle git show [D]eleted' })
      end,
    },
  },
}
