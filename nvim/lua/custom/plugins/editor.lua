-- Editor plugins: treesitter, indent detection, etc.

return {
  -- Treesitter for syntax highlighting
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false, -- treesitter doesn't support lazy loading
    build = ':TSUpdate',
    config = function()
      -- Install parsers (new API doesn't use .configs module)
      local ok, ts = pcall(require, 'nvim-treesitter')
      if ok and ts.setup then
        ts.setup {
          ensure_installed = {
            'bash',
            'c',
            'c_sharp',
            'css',
            'diff',
            'go',
            'html',
            'javascript',
            'jsdoc',
            'json',
            'lua',
            'luadoc',
            'markdown',
            'markdown_inline',
            'python',
            'query',
            'tsx',
            'typescript',
            'vim',
            'vimdoc',
            'yaml',
          },
          auto_install = true,
          highlight = { enable = true },
          indent = { enable = true },
        }
      else
        -- Fallback: just enable built-in treesitter highlighting
        vim.treesitter.start()
      end
    end,
  },

  -- Detect tabstop and shiftwidth automatically
  { 'NMAC427/guess-indent.nvim' },

  -- Cheatsheet for keybindings and commands
  {
    'sudormrfbin/cheatsheet.nvim',
    dependencies = {
      'nvim-telescope/telescope.nvim',
      'nvim-lua/popup.nvim',
      'nvim-lua/plenary.nvim',
    },
    config = function()
      require('cheatsheet').setup {
        bundled_cheatsheets = false, -- Disable bundled cheatsheets
        bundled_plugin_cheatsheets = false, -- Disable plugin cheatsheets
        -- Uses custom cheatsheet.txt in nvim config root
      }

      -- Add keymap to open cheatsheet
      vim.keymap.set('n', '<leader>?', '<cmd>Cheatsheet<CR>', { desc = 'Open cheatsheet' })
    end,
  },
}
