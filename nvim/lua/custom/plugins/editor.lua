-- Editor plugins: treesitter, indent detection, etc.

return {
  -- Treesitter for syntax highlighting
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false, -- treesitter doesn't support lazy loading
    build = ':TSUpdate',
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('nvim-treesitter.configs').setup {
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
