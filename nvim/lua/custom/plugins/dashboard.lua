-- Dashboard: snacks.nvim startup screen

--- Set dashboard highlight groups by linking to standard Vim groups.
--- Called on load and on every ColorScheme change so highlights
--- stay in sync with dotfiles theme switching.
local function set_dashboard_highlights()
  local links = {
    SnacksDashboardHeader = 'Keyword',
    SnacksDashboardIcon = 'Function',
    SnacksDashboardKey = 'Number',
    SnacksDashboardDesc = 'Special',
    SnacksDashboardTitle = 'Title',
    SnacksDashboardFooter = 'Comment',
    SnacksDashboardSpecial = 'Special',
    SnacksDashboardFile = 'Special',
    SnacksDashboardDir = 'NonText',
    SnacksDashboardNormal = 'Normal',
    SnacksDashboardTerminal = 'Normal',
  }
  for group, target in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = target })
  end
end

return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      -- Only enable the dashboard module
      bigfile = { enabled = false },
      dashboard = {
        enabled = true,
        width = 130,
        preset = {
          header = table.concat({
            '███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗',
            '████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║',
            '██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║',
            '██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║',
            '██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║',
            '╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝',
          }, '\n'),
          -- stylua: ignore
          keys = {
            { icon = ' ', key = 'f', desc = 'Find File',    action = ":lua Snacks.dashboard.pick('files')" },
            { icon = ' ', key = 'n', desc = 'New File',     action = ':ene | startinsert' },
            { icon = ' ', key = 'g', desc = 'Find Text',    action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = ' ', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = ' ', key = 'c', desc = 'Config',       action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = '󰒲 ', key = 'L', desc = 'Lazy',        action = ':Lazy' },
            { icon = ' ', key = 'q', desc = 'Quit',         action = ':qa' },
          },
        },
        sections = {
          -- Left pane: header + keys + recent files
          {
            section = 'header',
            padding = 1,
          },
          {
            section = 'keys',
            gap = 1,
            padding = 1,
          },
          {
            icon = ' ',
            title = 'Recent Files',
            section = 'recent_files',
            cwd = true,
            indent = 2,
            padding = 1,
          },
          -- Right pane: projects + git log + git status
          {
            pane = 2,
            icon = ' ',
            title = 'Projects',
            section = 'projects',
            indent = 2,
            padding = 1,
          },
          {
            pane = 2,
            icon = ' ',
            title = 'Git Log',
            section = 'terminal',
            enabled = function()
              return Snacks.git.get_root() ~= nil
            end,
            cmd = 'git log --oneline --graph --decorate --all -n 10',
            height = 12,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          {
            pane = 2,
            icon = ' ',
            title = 'Git Status',
            section = 'terminal',
            enabled = function()
              return Snacks.git.get_root() ~= nil
            end,
            cmd = 'git --no-pager diff --stat -B -M -C',
            height = 8,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          { section = 'startup' },
        },
      },
      notifier = { enabled = false },
      quickfile = { enabled = false },
      statuscolumn = { enabled = false },
      words = { enabled = false },
    },
    config = function(_, opts)
      require('snacks').setup(opts)

      -- Apply highlights now and re-apply on every theme change
      set_dashboard_highlights()
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('SnacksDashboardTheme', { clear = true }),
        callback = set_dashboard_highlights,
      })
    end,
  },
}
