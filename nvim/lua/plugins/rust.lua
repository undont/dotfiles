-- rustaceanvim: runs rust-analyzer itself (excluded from mason-lspconfig's
-- automatic_enable in lsp.lua) and adds :RustLsp debuggables/testables

return {
  'mrcjkb/rustaceanvim',
  version = '^9',
  -- the plugin loads itself on rust filetypes
  lazy = false,
}
