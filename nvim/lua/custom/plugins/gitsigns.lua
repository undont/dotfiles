-- gitsigns: gutter signs and hunk actions

return {
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function(_, opts)
      require('gitsigns').setup(opts)
    end,
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      -- above diagnostics, below the dotnet and neotest test signs
      sign_priority = 30,
      numhl = false,
      linehl = false,
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, mopts)
          mopts = mopts or {}
          mopts.buffer = bufnr
          vim.keymap.set(mode, l, r, mopts)
        end

        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            ---@diagnostic disable-next-line: missing-fields
            gitsigns.nav_hunk('next', { wrap = false, target = 'all' })
          end
        end, { desc = 'Jump to next git [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            ---@diagnostic disable-next-line: missing-fields
            gitsigns.nav_hunk('prev', { wrap = false, target = 'all' })
          end
        end, { desc = 'Jump to previous git [c]hange' })

        map('v', '<leader>Hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[S]tage hunk' })
        map('v', '<leader>Hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[R]eset hunk' })
        map('n', '<leader>Hs', gitsigns.stage_hunk, { desc = '[S]tage hunk' })
        map('n', '<leader>Hr', gitsigns.reset_hunk, { desc = '[R]eset hunk' })
        map('n', '<leader>HS', gitsigns.stage_buffer, { desc = '[S]tage buffer' })
        -- stage_hunk toggles: on a staged sign it unstages
        map('n', '<leader>Hu', gitsigns.stage_hunk, { desc = '[U]ndo stage hunk' })
        map('n', '<leader>HR', gitsigns.reset_buffer, { desc = '[R]eset buffer' })
        map('n', '<leader>Hp', gitsigns.preview_hunk, { desc = '[P]review hunk' })
        map('n', '<leader>Hi', gitsigns.preview_hunk_inline, { desc = '[I]nline hunk diff' })
        map('n', '<leader>Hd', gitsigns.diffthis, { desc = '[D]iff against index' })
        map('n', '<leader>HD', function()
          gitsigns.diffthis '@'
        end, { desc = '[D]iff against last commit' })
        map('n', '<leader>Hb', gitsigns.blame_line, { desc = '[B]lame line popup' })
        map('n', '<leader>HB', gitsigns.toggle_current_line_blame, { desc = 'Toggle inline [B]lame' })
      end,
    },
  },
}
