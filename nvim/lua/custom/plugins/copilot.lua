-- GitHub Copilot configuration

return {
  {
    'github/copilot.vim',
    config = function()
      -- Disable Copilot for sensitive files
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufNew' }, {
        pattern = {
          '.env*',
          '*.env',
          '*secret*',
          '*credential*',
          '*.key',
          '*.pem',
          '*.secrets.zsh',
        },
        callback = function()
          vim.b.copilot_enabled = false
        end,
      })

      -- Set distinct highlight for Copilot suggestions
      -- The highlight needs to be set AFTER copilot.vim's own ColorScheme autocmd
      local function set_copilot_hl()
        -- Get the Comment highlight as a base (designed to be subdued)
        local comment_hl = vim.api.nvim_get_hl(0, { name = 'Comment' })
        local fg = comment_hl.fg

        -- Fallback colors if Comment highlight isn't available
        if not fg then
          fg = 0x5c6370 -- grey
        end

        vim.api.nvim_set_hl(0, 'CopilotSuggestion', {
          fg = fg,
          ctermfg = 8,
          italic = true,
        })
      end

      -- Set on ColorScheme event (without pattern to catch all themes)
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('CopilotHighlights', { clear = true }),
        callback = function()
          -- Delay slightly to run after copilot's own autocmd
          vim.defer_fn(set_copilot_hl, 10)
        end,
      })

      -- Also set on VimEnter to catch initial load
      vim.api.nvim_create_autocmd('VimEnter', {
        group = 'CopilotHighlights',
        callback = function()
          vim.defer_fn(set_copilot_hl, 100)
        end,
      })

      -- Create a command to manually fix it if needed
      vim.api.nvim_create_user_command('CopilotHighlightFix', set_copilot_hl, {
        desc = 'Fix Copilot suggestion highlighting',
      })
    end,
  },
}
