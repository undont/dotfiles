-- Claude Diff Plugin - Interactive diff visualisation for Claude Code edits
return {
  {
    'bssmnt/nvim-claude-code-plugin',
    -- Local development path (dynamic)
    dir = vim.fn.expand('~/playground/nvim-claude-code-plugin'),
    -- When published, use: name = 'bssmnt/nvim-claude-code-plugin'
    enabled = false,  -- DISABLED for now
    lazy = false,  -- Load immediately (needs to listen for RPC)
    config = function()
      require('claude-diff').setup({
        -- Automatically show diff UI when changes are detected
        auto_show = true,

        -- Force review before allowing new edits
        force_review = true,

        -- Keymaps for plugin actions
        keymaps = {
          accept_all = '<leader>ca',
          reject_all = '<leader>cr',
          accept_hunk = '<leader>ch',
          reject_hunk = '<leader>cd',
          next_hunk = ']c',
          prev_hunk = '[c',
          toggle_ui = '<leader>cv',
        },

        -- UI configuration
        ui = {
          width = 0.8,
          height = 0.8,
          border = 'rounded',
        },
      })
    end,
    keys = {
      { '<leader>cv', desc = 'Toggle Claude diff view' },
      { '<leader>ca', desc = 'Accept all Claude changes' },
      { '<leader>cr', desc = 'Reject all Claude changes' },
    },
  },
}
