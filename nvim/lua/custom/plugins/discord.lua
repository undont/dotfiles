return {
  {
    'vyfor/cord.nvim',
    opts = {
      display = {
        theme = 'catppuccin',
      },
      idle = {
        enabled = true,
        timeout = 600000, -- 10 minutes
        show_status = false,
      },
      buttons = {
        {
          label = function(opts)
            return opts.repo_url and 'View Repository' or 'GitHub'
          end,
          url = function(opts)
            return opts.repo_url
          end,
        },
      },
    },
  },
}
