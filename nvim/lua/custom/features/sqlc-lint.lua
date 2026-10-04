-- nvim-lint linter for `sqlc compile` in projects with a sqlc config. sqlc
-- reads the queries from disk, so it runs on enter and write, not as you type

local M = {}

local CONFIGS = { 'sqlc.yaml', 'sqlc.yml', 'sqlc.json' }

---@param bufnr integer
---@return string?
local function project_root(bufnr)
  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
  local config = vim.fs.find(CONFIGS, { upward = true, path = dir })[1]
  if not config then
    return nil
  end
  return vim.fs.dirname(config)
end

-- sqlc prints `path:line:col: message`, with paths relative to the config dir
---@param output string
---@param bufnr integer
---@param root string
---@return vim.Diagnostic[]
local function parse(output, bufnr, root)
  local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
  local diagnostics = {}
  for line in vim.gsplit(output, '\n', { trimempty = true }) do
    local path, lnum, col, message = line:match '^(.-):(%d+):(%d+): (.+)$'
    if path then
      local file = path:sub(1, 1) == '/' and path or vim.fs.joinpath(root, path)
      if vim.fs.normalize(file) == bufname then
        table.insert(diagnostics, {
          lnum = tonumber(lnum) - 1,
          col = tonumber(col) - 1,
          message = message,
          severity = vim.diagnostic.severity.ERROR,
          source = 'sqlc',
        })
      end
    end
  end
  return diagnostics
end

function M.setup()
  local lint = require 'lint'
  lint.linters.sqlc = {
    cmd = 'sqlc',
    args = { 'compile' },
    stdin = false,
    append_fname = false,
    stream = 'stderr',
    ignore_exitcode = true,
    parser = parse,
  }

  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, {
    group = vim.api.nvim_create_augroup('sqlc-lint', { clear = true }),
    pattern = '*.sql',
    callback = function(ev)
      local root = project_root(ev.buf)
      if root and vim.fn.executable 'sqlc' == 1 then
        lint.try_lint('sqlc', { cwd = root })
      end
    end,
  })
end

return M
