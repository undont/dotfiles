-- Grug-far: project-wide search and replace

return {
  {
    'MagicDuck/grug-far.nvim',
    cmd = 'GrugFar',
    keys = {
      {
        '<leader>sR',
        function()
          require('grug-far').open()
        end,
        desc = 'Search & [R]eplace',
      },
      {
        '<leader>sR',
        mode = 'v',
        function()
          require('grug-far').open { prefills = { search = vim.fn.expand '<cword>' } }
        end,
        desc = 'Search & [R]eplace (word)',
      },
    },
    opts = {},
  },
}
