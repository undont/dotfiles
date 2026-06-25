-- runs after the shipped indent/astro.vim (an unmaintained vim-astro from 2022),
-- which puts a `0,` token in indentkeys: typing a comma as the first non-blank
-- on a line reindents the whole line. strip just that token; braces, brackets
-- and tags still trigger as normal.
--
-- :remove and `indentkeys-=` both fail here, the escaped comma corrupts how the
-- comma-separated list is split, so a plain-string substitution is the reliable
-- route. `0,` is the only zero-then-comma run in the list and is leftmost, so a
-- single replacement is safe.

vim.bo.indentkeys = (vim.bo.indentkeys:gsub('0,', '', 1))
