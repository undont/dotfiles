-- shared constants and diagnostic helpers for the sonarlint feature modules
-- (sonar-scan, sonar-rules, sonar-actions, sonar-rule-popup). extracted from
-- plugins/sonarlint.lua so the four concern modules and the spec all read the
-- client name, filetype list and sonar-diagnostic accessors from one place

local M = {}

M.SONARLINT_CLIENT_NAME = 'sonarlint.nvim'

M.FILETYPES = {
  'cs',
  'dockerfile',
  'python',
  'cpp',
  'c',
  'javascript',
  'javascriptreact',
  'typescript',
  'typescriptreact',
  'go',
  'php',
  'html',
  'css',
  'scss',
  'terraform',
  'hcl',
  'yaml',
  'xml',
}

--- the rule key for a diagnostic (e.g. "go:S3776"), or nil. mirrors how the
--- override filter reads `d.code`, with a fallback to the raw LSP payload
function M.diagnostic_code(d)
  local code = d.code
  if code == nil and d.user_data and d.user_data.lsp then
    code = d.user_data.lsp.code
  end
  return code ~= nil and tostring(code) or nil
end

function M.sonarlint_diagnostics(bufnr)
  local clients = vim.lsp.get_clients { name = M.SONARLINT_CLIENT_NAME }
  if #clients == 0 then
    return {}
  end
  -- prefer namespace filter when available; fall back to source matching
  local ok, ns = pcall(vim.lsp.diagnostic.get_namespace, clients[1].id)
  if ok and ns then
    return vim.diagnostic.get(bufnr, { namespace = ns })
  end
  return vim.tbl_filter(function(d)
    return d.source and d.source:lower():match 'sonar'
  end, vim.diagnostic.get(bufnr))
end

return M
