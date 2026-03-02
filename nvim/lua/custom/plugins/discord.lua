return {
  {
    'vyfor/cord.nvim',
    opts = {
      display = {
        theme = 'catppuccin',
      },
      buttons = {
        {
          label = function(opts)
            return opts.repo_url and 'View Repository' or 'GitHub'
          end,
          url = function(opts)
            return opts.repo_url or 'https://github.com/seanhalberthal'
          end,
        },
      },
    },
  },
}
