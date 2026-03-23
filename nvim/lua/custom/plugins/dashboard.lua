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
        width = 70,
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
            { icon = '', key = 'f', desc = 'Find File',    action = ":lua Snacks.dashboard.pick('files')" },
            { icon = '', key = 'n', desc = 'New File',     action = ':ene | startinsert' },
            { icon = '󰺯', key = 'g', desc = 'Find Text',    action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = '', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = '', key = 'p', desc = 'PRs',          action = ":Octo pr list" },
            { icon = '', key = 'c', desc = 'Config',       action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = '󰒲 ', key = 'L', desc = 'Lazy',        action = ':Lazy' },
            { icon = '󰩈', key = 'q', desc = 'Quit',         action = ':qa' },
          },
        },
        sections = {
          -- Header centred across both panes when space allows.
          -- Prepends (width + pane_gap) spaces so the renderer's
          -- wide-line adjustment places the text at the dashboard centre.
          function(self)
            local max_panes = math.max(1, math.floor((self._size.width + self.opts.pane_gap) / (self.opts.width + self.opts.pane_gap)))
            if max_panes < 2 then
              return { header = self.opts.preset.header, padding = 4 }
            end
            local pad = string.rep(' ', self.opts.width + self.opts.pane_gap)
            local centred = self.opts.preset.header:gsub('([^\n]+)', pad .. '%1')
            return { header = centred, padding = 4 }
          end,
          -- Left pane: keys + recent files
          {
            section = 'keys',
            gap = 1,
            padding = 1,
          },
          {
            title = 'Recent Files',
            section = 'recent_files',
            cwd = true,
            indent = 2,
            padding = 1,
          },
          -- Pane 2 spacer — clears the 6 header text rows so the wide
          -- header lines don't push right-pane content out of alignment.
          function(self)
            local max_panes = math.max(1, math.floor((self._size.width + self.opts.pane_gap) / (self.opts.width + self.opts.pane_gap)))
            if max_panes < 2 then
              return {}
            end
            return { pane = 2, text = '', padding = { 0, 9 } }
          end,
          -- Right pane: projects + git log + git status
          {
            pane = 2,
            title = 'Projects',
            section = 'projects',
            indent = 2,
            padding = 1,
          },
          {
            pane = 2,
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
      styles = {
        dashboard = {
          row = 0,
          height = function()
            return vim.o.lines - vim.o.cmdheight - (vim.o.laststatus >= 2 and 1 or 0)
          end,
        },
      },
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
