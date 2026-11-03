-- reads a colourscheme's colours from themes/<theme>.theme in the dotfiles
-- repo, so each hex value is written once for every tool

local M = {}

-- the nvim config dir is a symlink to <repo>/nvim
local themes_dir = vim.fs.joinpath(vim.fs.dirname(vim.uv.fs_realpath(vim.fn.stdpath 'config')), 'themes')

---@param theme string file name in themes/, without .theme
---@param keys table<string, string> colour name -> .theme key
---@return table<string, string> colour name -> hex
function M.load(theme, keys)
  local path = vim.fs.joinpath(themes_dir, theme .. '.theme')
  local f = assert(io.open(path, 'r'))
  local values = {}
  for line in f:lines() do
    local key, hex = line:match '^([%u%d_]+)="(#%x%x%x%x%x%x)"'
    if key then
      values[key] = hex
    end
  end
  f:close()

  local colours = {}
  for name, key in pairs(keys) do
    if not values[key] then
      error(string.format('%s has no %s', path, key))
    end
    colours[name] = values[key]
  end
  return colours
end

return M
