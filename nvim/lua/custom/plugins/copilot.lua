-- GitHub Copilot configuration (copilot.lua + blink-cmp-copilot)
-- Ghost text for inline suggestions, blink.cmp source for menu items.
-- Ghost text auto-hides when blink menu is open to avoid visual clutter.

return {
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      -- Use the standalone copilot-language-server binary instead of the
      -- bundled Node server. The Node path requires `node` (>= 22) on PATH at
      -- launch; on machines where nvim starts outside an fnm/nvm shell (GUI
      -- app, launcher, bare login shell) that silently yields zero completions.
      -- The binary server auto-downloads from GitHub releases and has no Node
      -- dependency. See lsp/binary.lua in copilot.lua.
      server = { type = 'binary' },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = false, -- handled by Tab in blink.cmp config
          dismiss = '<C-e>',
        },
      },
      panel = { enabled = false },
      filetypes = {
        markdown = true,
        yaml = true,
        help = false,
        gitcommit = false,
        gitrebase = false,
        TelescopePrompt = false,
        ['grug-far'] = false,
        ['grug-far-help'] = false,
        ['neo-tree'] = false,
        ['neo-tree-popup'] = false,
        DressingInput = false,
        codecompanion = false,
        ['copilot-chat'] = false,
        snacks_input = false,
        snacks_notif = false,
        octo = false,
        hgcommit = false,
        svn = false,
        cvs = false,
      },
      should_attach = function(bufnr, bufname)
        -- Preserve default checks: skip unlisted and special buffers (e.g. Telescope prompts)
        if not vim.bo[bufnr].buflisted or vim.bo[bufnr].buftype ~= '' then
          return false
        end
        local patterns = { '%.env', 'secret', 'credential', '%.key$', '%.pem$', '%.secrets%.zsh' }
        for _, pat in ipairs(patterns) do
          if bufname:match(pat) then
            return false
          end
        end
        return true
      end,
    },
    config = function(_, opts)
      require('copilot').setup(opts)

      -- Hide ghost text when blink menu opens, restore when it closes
      vim.api.nvim_create_autocmd('User', {
        pattern = 'BlinkCmpMenuOpen',
        callback = function()
          vim.b.copilot_suggestion_hidden = true
        end,
      })
      vim.api.nvim_create_autocmd('User', {
        pattern = 'BlinkCmpMenuClose',
        callback = function()
          vim.b.copilot_suggestion_hidden = false
        end,
      })
    end,
  },
}
