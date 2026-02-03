-- PR review plugins: diffview, octo, difi

return {
  -- Diffview: side-by-side diffs and file history
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles' },
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>do', '<cmd>DiffviewOpen<CR>', desc = '[D]iff [O]pen (vs index)' },
      { '<leader>dc', '<cmd>DiffviewClose<CR>', desc = '[D]iff [C]lose' },
      { '<leader>dh', '<cmd>DiffviewFileHistory %<CR>', desc = '[D]iff file [H]istory' },
      { '<leader>dp', '<cmd>DiffviewFileHistory --range=origin/HEAD...HEAD --right-only --no-merges<CR>', desc = '[D]iff [P]R review' },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = { layout = 'diff2_horizontal' },
        merge_tool = { layout = 'diff3_mixed' },
      },
    },
  },

  -- Octo: GitHub PR review from within Neovim
  {
    'pwntester/octo.nvim',
    cmd = 'Octo',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    keys = {
      { '<leader>pl', '<cmd>Octo pr list<CR>', desc = '[P]R [L]ist' },
      { '<leader>ps', '<cmd>Octo pr search<CR>', desc = '[P]R [S]earch' },
      {
        '<leader>po',
        function()
          vim.ui.input({ prompt = 'PR number: ' }, function(input)
            if input and input ~= '' then
              vim.cmd('Octo pr edit ' .. input)
            end
          end)
        end,
        desc = '[P]R [O]pen by number',
      },
      { '<leader>pr', '<cmd>Octo review start<CR>', desc = '[P]R [R]eview start' },
      { '<leader>pc', '<cmd>Octo pr comments<CR>', desc = '[P]R [C]omments' },
    },
    config = function()
      -- Register markdown/markdown_inline treesitter parsers for Octo buffers
      vim.treesitter.language.register('markdown', 'octo')

      require('octo').setup {
        use_local_fs = false,
        enable_builtin = true,
        default_remote = { 'upstream', 'origin' },
        picker = 'telescope',
      }
    end,
  },

  -- Difi: inline diff overlay
  {
    'oug-t/difi.nvim',
    cmd = 'Difi',
    keys = {
      { '<leader>df', '<cmd>Difi<CR>', desc = '[D]i[F]i toggle overlay' },
    },
  },
}
