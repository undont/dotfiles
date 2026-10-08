-- wiki-link resolver for markdown `gf`.
-- turns `[[name]]`, `[[name|alias]]`, or `[[name#anchor]]` into an absolute
-- path. used by after/ftplugin/markdown.lua via 'includeexpr'.

local M = {}

local function clean(name)
  return (name:gsub('[%[%]]', ''):gsub('|.*$', ''):gsub('#.*$', ''))
end

-- resolve a wiki-link target to an absolute path.
-- search order: sibling .md, then recursive walk from the nearest .git root.
-- falls back to the cleaned name so vim's own path/suffixesadd lookup can try.
function M.resolve(name)
  local cleaned = clean(name)
  if cleaned == '' then
    return name
  end

  local buf_dir = vim.fn.expand '%:p:h'

  local sibling = buf_dir .. '/' .. cleaned .. '.md'
  if vim.fn.filereadable(sibling) == 1 then
    return sibling
  end

  local root = vim.fs.root(buf_dir, { '.git' }) or buf_dir
  local matches = vim.fs.find(cleaned .. '.md', { path = root, type = 'file', limit = 1 })
  if matches[1] then
    return matches[1]
  end

  return cleaned
end

return M
