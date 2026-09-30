-- lazydev.nvim: supplies lua_ls with plugin type libraries on demand. each
-- `words` pattern loads that plugin's library when it appears in the buffer.
-- .luarc.json must not declare `workspace.library` (see .claude/rules/neovim.md)

return {
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = 'snacks.nvim', words = { 'Snacks' } },
        { path = 'mini.nvim', words = { 'Mini' } },
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        -- `words` are lua patterns run through line:find with no plain flag,
        -- so an `it%s*%(` trigger would match inside `split(`/`edit(`.
        -- busted's library declares `it` alongside `describe`
        { path = '${3rd}/busted/library', words = { 'describe%s*%(' } },
        { path = '${3rd}/luassert/library', words = { 'assert%.' } },
      },
    },
  },
}
