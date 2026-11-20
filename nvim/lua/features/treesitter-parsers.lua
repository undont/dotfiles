-- nvim-treesitter parser maintenance. remove_shadowed() runs before install()

local M = {}

--- idempotent
function M.remove_shadowed()
  local parser_dir = vim.fn.stdpath 'data' .. '/site/parser'
  local plugin_dir = vim.fn.stdpath 'data' .. '/lazy/nvim-treesitter'

  -- nvim-treesitter copies of parsers bundled with nvim are removed, so nvim's
  -- own are used
  local nvim_bundled = { 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline' }
  for _, lang in ipairs(nvim_bundled) do
    local so = parser_dir .. '/' .. lang .. '.so'
    if vim.uv.fs_stat(so) then
      os.remove(so)
    end
  end

  -- the plugin dir is a legacy parser location (main installs to site).
  -- binaries there shadow the install dir and satisfy the missing-parser probe
  local legacy_dir = plugin_dir .. '/parser'
  local scan = vim.uv.fs_scandir(legacy_dir)
  if scan then
    while true do
      local name, typ = vim.uv.fs_scandir_next(scan)
      if not name then
        break
      end
      if typ == 'file' and name:match '%.so$' then
        os.remove(legacy_dir .. '/' .. name)
      end
    end
  end
end

--- point a parser at a source other than nvim-treesitter's default and keep the
--- compiled binary in step with it. the install probe in plugins/treesitter.lua
--- only reinstalls a parser it can't find, so a changed revision has to drop the
--- .so itself; dropping a pin restores the upstream parser the same way.
--- markers are written before the install runs, but a failed install leaves no
--- parser for the probe to find, so it retries on the next start
--- @param pins table<string, {url: string, revision: string}>
function M.sync_pins(pins)
  local parser_dir = vim.fn.stdpath 'data' .. '/site/parser'
  local query_dir = vim.fn.stdpath 'data' .. '/site/queries'
  local marker_dir = vim.fn.stdpath 'data' .. '/nvim-treesitter-pins'
  vim.fn.mkdir(marker_dir, 'p')

  local function purge(lang)
    os.remove(parser_dir .. '/' .. lang .. '.so')
    if vim.uv.fs_stat(query_dir .. '/' .. lang) then
      vim.fn.delete(query_dir .. '/' .. lang, 'rf')
    end
  end

  local function marker(lang)
    return marker_dir .. '/' .. lang
  end

  local function read_marker(lang)
    local f = io.open(marker(lang), 'r')
    if not f then
      return nil
    end
    local rev = f:read '*a' or ''
    f:close()
    return vim.trim(rev)
  end

  -- install() clears the parser table from package.loaded and re-requires it
  -- before resolving a source, which drops a plain mutation. package.preload is
  -- checked ahead of the path searchers, so handing the pinned table back from
  -- there survives every reload
  local parsers = require 'nvim-treesitter.parsers'
  for lang, pin in pairs(pins) do
    if parsers[lang] then
      parsers[lang].install_info = { url = pin.url, revision = pin.revision }
    end
  end
  package.preload['nvim-treesitter.parsers'] = function()
    return parsers
  end

  for lang, pin in pairs(pins) do
    if read_marker(lang) ~= pin.revision then
      purge(lang)
      local f = io.open(marker(lang), 'w')
      if f then
        f:write(pin.revision)
        f:close()
      end
    end
  end

  -- a marker with no matching pin is a parser that was pinned and isn't any
  -- more, so it still holds the pinned build; purge it back to upstream
  local scan = vim.uv.fs_scandir(marker_dir)
  while scan do
    local name = vim.uv.fs_scandir_next(scan)
    if not name then
      break
    end
    if not pins[name] then
      purge(name)
      os.remove(marker(name))
    end
  end
end

return M
