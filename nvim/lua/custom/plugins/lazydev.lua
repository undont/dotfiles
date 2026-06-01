-- lazydev.nvim: feed lua_ls the type definitions for plugins we use, loaded
-- on demand. Without this, plugin globals like `Snacks`/`Mini*` are only listed
-- in .luarc.json's `diagnostics.globals` (which silences the undefined-global
-- warning but gives them no type), so `K` hover and completion show nothing.
-- Each `words` pattern triggers loading that plugin's library when the pattern
-- appears in the buffer, keeping the workspace index lean.

return {
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = 'snacks.nvim', words = { 'Snacks' } },
        { path = 'mini.nvim', words = { 'Mini' } },
        -- luvit types when `vim.uv` is used
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
}
