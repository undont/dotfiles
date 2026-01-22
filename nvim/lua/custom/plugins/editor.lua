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
}
