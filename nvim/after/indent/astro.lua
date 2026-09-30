-- runs after the shipped indent/astro.vim, whose `0,` token in indentkeys
-- reindents the line when a comma is typed as its first non-blank.
-- :remove and `indentkeys-=` fail on the escaped comma, so the token is
-- stripped with a plain-string substitution

vim.bo.indentkeys = (vim.bo.indentkeys:gsub('0,', '', 1))
