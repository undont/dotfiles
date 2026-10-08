-- snacks.nvim dashboard

--- resolved foreground of a highlight group, following links
---@param group string
---@return integer?
local function fg_of(group)
  return vim.api.nvim_get_hl(0, { name = group, link = false }).fg
end

-- the dashboard hides the statusline by zeroing laststatus, a global option,
-- so the toggle follows focus: a one-off hide on open would apply to every
-- other window, and would not return when focus comes back (closing a
-- `:Differ` tabpage). the focus watcher lives and dies with the dashboard buffer
local saved_laststatus = vim.o.laststatus
local focus_group = 'SnacksDashboardStatuslineFocus'

local function hide_statusline()
  if vim.o.laststatus ~= 0 then
    saved_laststatus = vim.o.laststatus
    vim.o.laststatus = 0
  end
end

local function restore_statusline()
  if vim.o.laststatus == 0 then
    vim.o.laststatus = saved_laststatus
  end
end

-- floats are skipped so a picker opened over the dashboard doesn't flip it
local function sync_statusline()
  if vim.api.nvim_win_get_config(0).relative ~= '' then
    return
  end
  if vim.bo.filetype == 'snacks_dashboard' then
    hide_statusline()
  else
    restore_statusline()
  end
end

local function watch_focus()
  hide_statusline()
  vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
    group = vim.api.nvim_create_augroup(focus_group, { clear = true }),
    callback = sync_statusline,
  })
end

local function unwatch_focus()
  pcall(vim.api.nvim_del_augroup_by_name, focus_group)
  restore_statusline()
end

local function set_dashboard_highlights()
  local links = {
    SnacksDashboardHeader = 'Keyword',
    SnacksDashboardIcon = 'Function',
    SnacksDashboardKey = 'Number',
    SnacksDashboardTitle = 'Title',
    SnacksDashboardFooter = 'Comment',
    SnacksDashboardDir = 'NonText',
    SnacksDashboardNormal = 'Normal',
    SnacksDashboardTerminal = 'Normal',
  }
  for group, target in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = target })
  end

  -- colour only: a link would inherit Special's attributes (dracula italicises it)
  local special = fg_of 'Special' or fg_of 'Normal'
  for _, group in ipairs { 'SnacksDashboardDesc', 'SnacksDashboardFile', 'SnacksDashboardSpecial' } do
    vim.api.nvim_set_hl(0, group, { fg = special })
  end
end

-- every picker window and border links back to these two
local function set_picker_highlights()
  vim.api.nvim_set_hl(0, 'SnacksPicker', { link = 'Normal' })
  vim.api.nvim_set_hl(0, 'SnacksPickerBorder', { link = 'TelescopeBorder' })
end

return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = false },
      dashboard = {
        enabled = true,
        width = 70,
        preset = {
          header = table.concat({
            '            ▗     ',
            '▛▀▖▞▀▖▞▀▖▌ ▌▄ ▛▚▀▖',
            '▌ ▌▛▀ ▌ ▌▐▐ ▐ ▌▐ ▌',
            '▘ ▘▝▀▘▝▀  ▘ ▀▘▘▝ ▘',
          }, '\n'),
          -- stylua: ignore
          keys = {
            { icon = '', key = 'f', desc = 'Find File',    action = ":lua Snacks.dashboard.pick('files')" },
            { icon = '', key = 'n', desc = 'New File',     action = ':ene | startinsert' },
            { icon = '󰺯', key = 'G', desc = 'Find Text',    action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = '', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = '', key = 'p', desc = 'PRs',          action = ":Differ pr list" },
            { icon = '', key = 'c', desc = 'Config',       action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = '󰒲 ', key = 'L', desc = 'Lazy',        action = ':Lazy' },
            { icon = '󰩈', key = 'q', desc = 'Quit',         action = ':qa' },
          },
        },
        sections = {
          { section = 'header', padding = 2 },
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
          {
            title = 'Projects',
            section = 'projects',
            indent = 2,
            padding = 1,
          },
          { section = 'startup' },
        },
      },
      notifier = { enabled = false },
      -- Snacks.picker.* still works while disabled; enabling it would also
      -- replace vim.ui.select, which telescope-ui-select owns
      picker = {
        enabled = false,
        layout = { layout = { backdrop = false } },
      },
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

      set_dashboard_highlights()
      set_picker_highlights()
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('SnacksDashboardTheme', { clear = true }),
        callback = function()
          set_dashboard_highlights()
          set_picker_highlights()
        end,
      })

      local statusline_group = vim.api.nvim_create_augroup('SnacksDashboardStatusline', { clear = true })
      vim.api.nvim_create_autocmd('User', {
        pattern = 'SnacksDashboardOpened',
        group = statusline_group,
        callback = watch_focus,
      })
      vim.api.nvim_create_autocmd('User', {
        pattern = 'SnacksDashboardClosed',
        group = statusline_group,
        callback = unwatch_focus,
      })
    end,
  },
}
