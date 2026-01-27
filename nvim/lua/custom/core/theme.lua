--[[
  Theme Integration Module

  Reads the current theme from ${XDG_CONFIG_HOME:-~/.config}/dotfiles/current-theme
  and applies the corresponding Neovim colourscheme.

  Uses vim.uv file watcher for live reload when theme changes.
--]]

local M = {}

-- Configuration
-- Respect XDG_CONFIG_HOME to match shell tooling
local xdg_config = os.getenv 'XDG_CONFIG_HOME' or vim.fn.expand '~/.config'
local config_dir = xdg_config .. '/dotfiles'
local theme_file = config_dir .. '/current-theme'

-- Map dotfiles theme names to nvim colourschemes
local theme_map = {
  ['dracula'] = 'dracula',
  ['catppuccin-mocha'] = 'catppuccin-mocha',
  ['tokyo-night'] = 'tokyonight-night',
  ['nord'] = 'nord',
  ['gruvbox-dark'] = 'gruvbox-dark',
  ['solarized-dark'] = 'solarized-dark',
  ['one-dark'] = 'onedark',
  ['monokai'] = 'monokai',
  ['ayu-dark'] = 'ayu-dark',
  ['everforest'] = 'everforest',
  ['kanagawa'] = 'kanagawa',
  ['rose-pine'] = 'rose-pine',
  ['nightfox'] = 'nightfox',
  ['synthwave'] = 'synthwave',
}

-- Default fallback
local default_scheme = 'dracula'

-- Track current theme to avoid unnecessary reloads
local current_theme = nil

-- File watcher handle
local watcher = nil

--- Read the current theme from the dotfiles config
---@return string|nil theme name or nil if file doesn't exist
local function read_theme_file()
  local f = io.open(theme_file, 'r')
  if not f then
    return nil
  end
  local theme = f:read '*l'
  f:close()
  return theme and theme:match '^%s*(.-)%s*$' -- trim whitespace
end

--- Apply a colourscheme safely
---@param scheme string colourscheme name
---@return boolean success
local function apply_colourscheme(scheme)
  -- Ensure lazy-loaded plugins are loaded before applying
  local lazy_schemes = {
    ['tokyonight-night'] = 'tokyonight.nvim',
    ['nord'] = 'nord.nvim',
    ['gruvbox'] = 'gruvbox.nvim',
    ['onedark'] = 'onedark.nvim',
    ['ayu-dark'] = 'neovim-ayu',
    ['everforest'] = 'everforest-nvim',
    ['kanagawa'] = 'kanagawa.nvim',
    ['rose-pine'] = 'rose-pine',
    ['nightfox'] = 'nightfox.nvim',
    -- Custom colourschemes in colors/ directory (no plugins needed):
    -- gruvbox-dark, monokai, solarized-dark, synthwave
  }

  local plugin_name = lazy_schemes[scheme]
  if plugin_name then
    local ok_load = pcall(require('lazy.core.loader').load, { plugin_name }, { colorscheme = scheme })
    if not ok_load then
      vim.notify(string.format('Failed to load plugin for "%s"', scheme), vim.log.levels.WARN)
      return false
    end
  end

  local ok, err = pcall(vim.cmd.colorscheme, scheme)
  if not ok then
    vim.notify(string.format('Failed to load colourscheme "%s": %s', scheme, err), vim.log.levels.WARN)
    return false
  end
  return true
end

--- Reload theme from config file
---@param force boolean|nil force reload even if theme unchanged
function M.reload(force)
  local theme = read_theme_file()

  -- Skip if theme hasn't changed (unless forced)
  if not force and theme == current_theme then
    return
  end

  local scheme = theme_map[theme] or default_scheme

  if apply_colourscheme(scheme) then
    current_theme = theme
    -- Subtle notification (only on manual reload or actual change)
    if force or current_theme ~= nil then
      vim.notify(string.format('Theme: %s', theme or 'default'), vim.log.levels.INFO)
    end
  end
end

--- Get current theme name
---@return string theme name
function M.current()
  return current_theme or read_theme_file() or 'dracula'
end

--- Start file watcher for live reload
local function start_watcher()
  -- Ensure config directory exists
  if vim.fn.isdirectory(config_dir) == 0 then
    return
  end

  -- Create file watcher
  watcher = vim.uv.new_fs_event()
  if not watcher then
    vim.notify('Failed to create theme file watcher', vim.log.levels.WARN)
    return
  end

  -- Watch the theme file
  local ok = pcall(function()
    watcher:start(
      theme_file,
      {},
      vim.schedule_wrap(function(watch_err, _, _)
        if watch_err then
          return
        end
        -- Small delay to ensure file write is complete
        vim.defer_fn(function()
          M.reload()
        end, 50)
      end)
    )
  end)

  if not ok then
    -- File might not exist yet, watch directory instead
    watcher:start(
      config_dir,
      {},
      vim.schedule_wrap(function(watch_err, filename, _)
        if watch_err then
          return
        end
        if filename == 'current-theme' then
          vim.defer_fn(function()
            M.reload()
          end, 50)
        end
      end)
    )
  end
end

--- Stop file watcher
local function stop_watcher()
  if watcher then
    watcher:stop()
    watcher = nil
  end
end

--- Setup theme integration
---@param opts table|nil options (currently unused, for future expansion)
function M.setup(opts)
  opts = opts or {}

  -- Apply theme on startup
  M.reload()

  -- Start file watcher for live reload
  start_watcher()

  -- Also reload on FocusGained as backup
  vim.api.nvim_create_autocmd('FocusGained', {
    group = vim.api.nvim_create_augroup('DotfilesTheme', { clear = true }),
    callback = function()
      M.reload()
    end,
  })

  -- Create user command for manual reload
  vim.api.nvim_create_user_command('ThemeReload', function()
    M.reload(true)
  end, { desc = 'Reload theme from dotfiles config' })

  -- Clean up watcher on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = 'DotfilesTheme',
    callback = stop_watcher,
  })
end

return M
