-- lazydev.nvim: supplies lua_ls with plugin type libraries on demand. each
-- `words` pattern loads that plugin's library when it appears in the buffer.
-- .luarc.json must not declare `workspace.library` (see .claude/rules/neovim.md)

-- a project whose .luarc.json declares its own library (rex/) isn't nvim lua,
-- and lazydev's `/lua` ignoreDir would hide its lua/ modules from lua_ls
---@param root_dir string
local function has_own_library(root_dir)
  local file = io.open(root_dir .. '/.luarc.json')
  if not file then
    return false
  end
  local ok, luarc = pcall(vim.json.decode, file:read '*a')
  file:close()
  if not ok or type(luarc) ~= 'table' then
    return false
  end
  return luarc['workspace.library'] ~= nil or vim.tbl_get(luarc, 'workspace', 'library') ~= nil
end

return {
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      enabled = function(root_dir)
        return vim.g.lazydev_enabled ~= false and not has_own_library(root_dir)
      end,
      library = {
        { path = 'snacks.nvim', words = { 'Snacks' } },
        { path = 'mini.nvim', words = { 'Mini' } },
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        -- `words` are lua patterns run through line:find with no plain flag,
        -- so an `it%s*%(` trigger would match inside `split(`/`edit(`.
        -- busted's library declares `it` alongside `describe`
        { path = '${3rd}/busted/library', words = { 'describe%s*%(' } },
        { path = '${3rd}/luassert/library', words = { 'assert%.' } },
        { path = '${3rd}/love2d/library', words = { 'love%.' } },
      },
    },
  },
}
