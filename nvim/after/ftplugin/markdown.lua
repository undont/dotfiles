-- `gf` follows `[[wiki-style]]` links. 'isfname' excludes `[` and `]`, so
-- `gf` on `[[foo-bar]]` already yields `foo-bar`

vim.opt_local.suffixesadd:prepend '.md'
vim.opt_local.includeexpr = "v:lua.require'custom.wiki'.resolve(v:fname)"
