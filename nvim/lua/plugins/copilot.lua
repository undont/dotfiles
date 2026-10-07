-- copilot.lua + blink-cmp-copilot: ghost text for inline suggestions, a
-- blink.cmp source for menu items

return {
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      -- the bundled node server needs `node` on PATH at launch, which is
      -- absent when nvim starts outside an fnm/nvm shell. the binary server
      -- has no node dependency (lsp/binary.lua in copilot.lua)
      server = { type = 'binary' },
      -- full-document didChange: nvim's incremental sync (vim/lsp/sync.lua)
      -- asserts on a stale line snapshot after a changetracking desync, and
      -- full sync never runs compute_diff (neovim/neovim#33224).
      -- exit_timeout defaults to false, where nvim does not wait for shutdown
      -- and a slow server is orphaned; a number waits, then force-stops. it
      -- applies to runtime restarts: on quit the ExitPre hook in
      -- plugins/lsp.lua stops every client first
      server_opts_overrides = {
        flags = { allow_incremental_sync = false },
        exit_timeout = 200,
      },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = false, -- <Tab> in the blink.cmp config accepts
          accept_word = '<M-Tab>',
          dismiss = '<C-e>',
        },
      },
      panel = { enabled = false },
      filetypes = {
        markdown = false,
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
        hgcommit = false,
        svn = false,
        cvs = false,
      },
      should_attach = function(bufnr, bufname)
        -- the plugin's default checks: unlisted and special buffers
        if not vim.bo[bufnr].buflisted or vim.bo[bufnr].buftype ~= '' then
          return false
        end
        -- ssh keys and config have no distinguishing filetype
        local ssh_dir = vim.fn.resolve(vim.fn.expand '~/.ssh') .. '/'
        if bufname:sub(1, #ssh_dir) == ssh_dir then
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

      -- ghost text hides while the blink menu is open. the flag only gates the
      -- next render, so an extmark already drawn is dismissed explicitly
      vim.api.nvim_create_autocmd('User', {
        pattern = 'BlinkCmpMenuOpen',
        callback = function()
          vim.b.copilot_suggestion_hidden = true
          require('copilot.suggestion').clear_preview()
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
