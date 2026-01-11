-- Editor plugins: treesitter, indent detection, etc.

return {
  -- Treesitter for syntax highlighting
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('nvim-treesitter.configs').setup({
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
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = { 'ruby' },
        },
        indent = { enable = true, disable = { 'ruby' } },
      })
    end,
  },

  -- Detect tabstop and shiftwidth automatically
  { 'NMAC427/guess-indent.nvim' },
}
