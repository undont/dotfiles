-- applies the nvim colourscheme named in
-- ${XDG_CONFIG_HOME:-~/.config}/dotfiles/current-theme, reloading when
-- `dotfiles theme switch` rewrites that file

local M = {}

local xdg_config = os.getenv 'XDG_CONFIG_HOME' or vim.fn.expand '~/.config'
local config_dir = xdg_config .. '/dotfiles'
local theme_file = config_dir .. '/current-theme'

-- dotfiles theme name -> nvim colourscheme
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

local default_scheme = 'dracula'

--- reads config then local: ghostty takes the last value
---@return boolean
local function ghostty_transparent()
  local opacity = 1
  local ghostty_dir = (os.getenv 'XDG_CONFIG_HOME' or vim.fn.expand '~/.config') .. '/ghostty'
  for _, path in ipairs { ghostty_dir .. '/config', ghostty_dir .. '/local' } do
    local f = io.open(path, 'r')
    if f then
      for line in f:lines() do
        local val = line:match '^%s*background%-opacity%s*=%s*([%d%.]+)'
        if val then
          opacity = tonumber(val)
        end
      end
      f:close()
    end
  end
  return opacity < 1
end

local function apply_transparency()
  local groups = {
    'Normal',
    'NormalNC',
    'SignColumn',
    'EndOfBuffer',
    'StatusLine',
    'StatusLineNC',
    'TabLine',
    'TabLineFill',
    'MiniStatuslineDevinfo',
    'MiniStatuslineFilename',
    'MiniStatuslineFileinfo',
    'MiniStatuslineInactive',
    'NeoTreeNormal',
    'NeoTreeNormalNC',
  }
  for _, group in ipairs(groups) do
    local existing = vim.api.nvim_get_hl(0, { name = group })
    existing.bg = nil
    vim.api.nvim_set_hl(0, group, existing)
  end
end

local current_theme = nil

local watcher = nil

---@return string|nil
local function read_theme_file()
  local f = io.open(theme_file, 'r')
  if not f then
    return nil
  end
  local theme = f:read '*l'
  f:close()
  return theme and theme:match '^%s*(.-)%s*$' -- trim whitespace
end

---@param scheme string a file in nvim/colors/ or nvim/colors/generated/
---@return boolean success
local function apply_colourscheme(scheme)
  local ok = pcall(vim.cmd.colorscheme, scheme)
  if ok then
    return true
  end

  -- the name is interpolated into a path below
  if not scheme:match '^[a-z0-9%-]+$' then
    vim.notify(string.format('Invalid colourscheme name: "%s"', scheme), vim.log.levels.WARN)
    return false
  end

  local generated = vim.fn.stdpath 'config' .. '/colors/generated/' .. scheme .. '.lua'
  if vim.fn.filereadable(generated) == 1 then
    local load_ok, load_err = pcall(dofile, generated)
    if load_ok then
      -- dofile() does not fire ColorScheme, unlike :colorscheme
      vim.api.nvim_exec_autocmds('ColorScheme', { pattern = scheme })
      return true
    end
    vim.notify(string.format('Failed to load generated colourscheme "%s": %s', scheme, load_err), vim.log.levels.WARN)
    return false
  end

  vim.notify(string.format('Colourscheme "%s" not found', scheme), vim.log.levels.WARN)
  return false
end

---@param force boolean|nil reload even if the theme name is unchanged
function M.reload(force)
  local theme = read_theme_file()

  if not force and theme == current_theme then
    return
  end

  -- generated themes are not in theme_map and use their own name
  local scheme = theme_map[theme] or theme or default_scheme

  local previous = current_theme

  if apply_colourscheme(scheme) then
    current_theme = theme
    if ghostty_transparent() then
      apply_transparency()
    end
    -- stay silent on the startup apply
    if force or previous ~= nil then
      vim.notify(string.format('Theme: %s', theme or 'default'), vim.log.levels.INFO)
    end
  end
end

---@return string
function M.current()
  return current_theme or read_theme_file() or 'dracula'
end

local function start_watcher()
  if vim.fn.isdirectory(config_dir) == 0 then
    return
  end

  watcher = vim.uv.new_fs_event()
  if not watcher then
    vim.notify('Failed to create theme file watcher', vim.log.levels.WARN)
    return
  end

  local ok = pcall(function()
    watcher:start(
      theme_file,
      {},
      vim.schedule_wrap(function(watch_err, _, _)
        if watch_err then
          return
        end
        -- deferred so the write has finished. forced: a regenerated scheme
        -- keeps its name, which the unchanged-name guard would skip
        vim.defer_fn(function()
          M.reload(true)
        end, 50)
      end)
    )
  end)

  if not ok then
    -- the file does not exist yet
    watcher:start(
      config_dir,
      {},
      vim.schedule_wrap(function(watch_err, filename, _)
        if watch_err then
          return
        end
        if filename == 'current-theme' then
          vim.defer_fn(function()
            M.reload(true)
          end, 50)
        end
      end)
    )
  end
end

local function stop_watcher()
  if watcher then
    watcher:stop()
    watcher = nil
  end
end

function M.setup()
  M.reload()

  start_watcher()

  -- covers a missed watcher event
  vim.api.nvim_create_autocmd('FocusGained', {
    group = vim.api.nvim_create_augroup('DotfilesTheme', { clear = true }),
    callback = function()
      M.reload()
    end,
  })

  vim.api.nvim_create_user_command('ThemeReload', function()
    M.reload(true)
  end, { desc = 'Reload theme from dotfiles config' })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = 'DotfilesTheme',
    callback = stop_watcher,
  })
end

return M
