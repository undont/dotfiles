-- fidget: LSP progress spinner and vim.notify backend

return {
  {
    'j-hui/fidget.nvim',
    event = 'VeryLazy',
    opts = {
      progress = {
        -- sonarlint.nvim emits LSP progress on every BufEnter for a supported
        -- filetype. the `<leader>lm` / `<leader>lS` scans report under a
        -- separate `sonar-scan` client name (features/sonar-scan.lua)
        ignore = {
          function(msg)
            return msg.lsp_client ~= nil and msg.lsp_client.name == 'sonarlint.nvim'
          end,
        },
        display = {
          done_ttl = 2,
          progress_icon = { 'dots' },
          overrides = {
            build = {
              name = false,
            },
          },
        },
      },
      notification = {
        override_vim_notify = true,
        window = {
          winblend = 0,
          align = 'bottom',
        },
      },
    },
    config = function(_, opts)
      opts.notification = opts.notification or {}
      opts.notification.configs = {
        default = vim.tbl_extend('force', require('fidget.notification').default_config, {
          name = false,
          icon = false,
        }),
      }
      require('fidget').setup(opts)

      -- after fidget setup: override_vim_notify replaces earlier wraps
      require('features.notify-filter').install()

      vim.keymap.set('n', '<leader>Nn', '<cmd>Fidget history<cr>', { desc = 'Notification history' })
    end,
  },
}
