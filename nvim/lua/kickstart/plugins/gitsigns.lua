-- Adds git related signs to the gutter, as well as utilities for managing changes

return {
  {
    'lewis6991/gitsigns.nvim',
    config = function(_, opts)
      require('gitsigns').setup(opts)
      -- Git sign colours are defined in nvim/colors/*.lua colourschemes
    end,
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      sign_priority = 30, -- Above easy-dotnet test signs (priority 20)
      numhl = false,
      linehl = false,
      on_attach = function(bufnr)
        -- Skip diffview buffers — gutter signs are useless in diff panes and
        -- each attachment spawns git subprocesses, risking EMFILE exhaustion.
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if bufname:match 'diffview://' then
          return false
        end

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
            gitsigns.nav_hunk('next', { wrap = false, target = 'all' })
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk('prev', { wrap = false, target = 'all' })
          end
        end, { desc = 'Jump to previous git [c]hange' })

        -- Actions
        -- visual mode
        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[S]tage hunk' })
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[R]eset hunk' })
        -- normal mode
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = '[S]tage hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = '[R]eset hunk' })
        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = '[S]tage buffer' })
        map('n', '<leader>hu', gitsigns.undo_stage_hunk, { desc = '[U]ndo stage hunk' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = '[R]eset buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk, { desc = '[P]review hunk' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = '[D]iff against index' })
        map('n', '<leader>hD', function()
          gitsigns.diffthis '@'
        end, { desc = '[D]iff against last commit' })
        -- Blame (under <leader>d with diffview)
        map('n', '<leader>db', gitsigns.toggle_current_line_blame, { desc = 'Toggle inline [B]lame' })
        map('n', '<leader>dB', gitsigns.blame_line, { desc = '[B]lame line popup' })
        -- Toggles
        map('n', '<leader>tD', gitsigns.preview_hunk_inline, { desc = 'Toggle [D]eleted' })
      end,
    },
  },
}
