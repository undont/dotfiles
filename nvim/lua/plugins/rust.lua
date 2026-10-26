-- rustaceanvim: runs rust-analyzer itself (excluded from mason-lspconfig's
-- automatic_enable in lsp.lua) and adds :RustLsp debuggables/testables

--- neotest discovers a rust file through rust-analyzer's runnables, which come
--- back empty until the workspace has loaded, and keeps that empty tree until
--- the file is written. once the server reports itself ready, neotest's own
--- write handler re-runs discovery for every buffer it has open
local function rediscover_tests(_, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  if not client or vim.fn.exists '#neotest.Client#BufWritePost' == 0 then
    return
  end
  for bufnr in pairs(client.attached_buffers) do
    vim.api.nvim_exec_autocmds('BufWritePost', { group = 'neotest.Client', buffer = bufnr })
  end
end

return {
  'mrcjkb/rustaceanvim',
  version = '^9',
  -- the plugin loads itself on rust filetypes
  lazy = false,
  init = function()
    vim.g.rustaceanvim = function()
      return { tools = { on_initialized = rediscover_tests } }
    end
  end,
}
