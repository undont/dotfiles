-- AI coding assistant: chat, inline editing, and agentic workflows
-- adapters: copilot (GitHub sub), anthropic (API key), opencode (ACP)
-- switch adapter per-strategy below, or pick at runtime via the action palette

return {
  {
    'olimorris/codecompanion.nvim',
    build = false,
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
            -- force the copilot.vim oauth token. apps.json can hold several
            -- `github.com:*` entries (gh CLI, Copilot CLI, VS Code), and the
            -- upstream adapter returns the first one `pairs()` yields, often a
            -- stale entry whose token exchange 401s, producing an empty bearer
            -- and a 400 "Authorization header is badly formatted" on every chat.
            -- pre-seeding `_oauth_token` short-circuits that pick (token.lua
            -- returns it directly), so duplicates never break the adapter
            pcall(function()
              local token = require 'codecompanion.adapters.http.copilot.token'
              local apps = vim.fn.expand '~/.config/github-copilot/apps.json'
              if vim.fn.filereadable(apps) == 0 then
                return
              end
              local data = vim.json.decode(table.concat(vim.fn.readfile(apps), ' '))
              for key, value in pairs(data) do
                -- `Iv1.*` is the copilot.vim / copilot.lua GitHub App
                if type(value) == 'table' and value.oauth_token and key:find 'Iv1%.' then
                  token._oauth_token = value.oauth_token
                  return
                end
              end
            end)
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
