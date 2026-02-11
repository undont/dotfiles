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
        auto_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      }

      -- Register language aliases for markdown code fence highlighting
      vim.treesitter.language.register('c_sharp', { 'csharp', 'cs' })
    end,
  },

  -- Detect tabstop and shiftwidth automatically
  { 'NMAC427/guess-indent.nvim', event = 'BufReadPost', opts = {} },

  -- Cheatsheet for keybindings and commands
  {
    'sudormrfbin/cheatsheet.nvim',
    cmd = 'Cheatsheet',
    keys = {
      { '<leader>?', '<cmd>Cheatsheet<CR>', desc = 'Open cheatsheet' },
    },
    dependencies = {
      'nvim-telescope/telescope.nvim',
      'nvim-lua/popup.nvim',
      'nvim-lua/plenary.nvim',
    },
    opts = {
      bundled_cheatsheets = false,
      bundled_plugin_cheatsheets = false,
    },
  },
}
