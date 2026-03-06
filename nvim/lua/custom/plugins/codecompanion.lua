-- AI coding assistant: chat, inline editing, and agentic workflows
-- Adapters: copilot (GitHub sub), anthropic (API key), opencode (ACP)
-- Switch adapter per-strategy below, or pick at runtime via the action palette.

return {
  {
    'olimorris/codecompanion.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    cmd = { 'CodeCompanion', 'CodeCompanionChat', 'CodeCompanionActions', 'CodeCompanionCmd' },
    keys = {
      { '<leader>ac', '<cmd>CodeCompanionChat toggle<CR>', mode = { 'n', 'v' }, desc = 'Chat toggle' },
      { '<leader>ai', '<cmd>CodeCompanion<CR>', mode = { 'n', 'v' }, desc = 'Inline assist' },
      { '<leader>aa', '<cmd>CodeCompanionActions<CR>', mode = { 'n', 'v' }, desc = 'Action palette' },
    },
    opts = {
      display = {
        chat = {
          window = {
            width = 0.40,
          },
        },
      },
      adapters = {
        http = {
          copilot = function()
            return require('codecompanion.adapters').extend('copilot', {})
          end,
          anthropic = function()
            return require('codecompanion.adapters').extend('anthropic', {
              env = { api_key = 'ANTHROPIC_API_KEY' },
            })
          end,
        },
        acp = {
          opencode = 'opencode',
        },
      },
      strategies = {
        chat = { adapter = 'copilot' },
        inline = { adapter = 'copilot' },
        cmd = { adapter = 'copilot' },
      },
    },
  },
}
