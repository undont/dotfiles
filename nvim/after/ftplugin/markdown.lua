-- Let `gf` follow `[[wiki-style]]` links in markdown.
-- Default 'isfname' excludes `[` and `]`, so `gf` on `[[foo-bar]]` already
-- yields `foo-bar`; the resolver below adds `.md`, strips `|alias` and
-- `#anchor`, and walks the project for a match.

vim.opt_local.suffixesadd:prepend '.md'
vim.opt_local.includeexpr = "v:lua.require'custom.wiki'.resolve(v:fname)"
