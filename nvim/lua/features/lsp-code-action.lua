-- code-action picker (gra) that refreshes diagnostics after the chosen action

local M = {}

--- some servers republish on didChange, others only on an explicit pull
---@param bufnr integer
local function refresh_diagnostics_soon(bufnr)
  local delays = { 100, 300, 800, 1500 }

  for _, delay in ipairs(delays) do
    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
        return
      end

      if next(vim.lsp.get_clients { bufnr = bufnr, method = 'textDocument/diagnostic' }) then
        pcall(vim.lsp.diagnostic._enable, bufnr)
        pcall(vim.lsp.diagnostic._refresh, bufnr)
      end
    end, delay)
  end
end

--- the built-in picker, with a diagnostics refresh after the chosen action
--- applies
function M.code_action_with_refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  local orig_select = vim.ui.select
  local restored = false
  local wrapped_select

  local function restore()
    if restored or vim.ui.select ~= wrapped_select then
      return
    end
    vim.ui.select = orig_select
    restored = true
  end

  wrapped_select = function(items, opts, on_choice)
    return orig_select(items, opts, function(choice, ...)
      if on_choice then
        on_choice(choice, ...)
      end
      refresh_diagnostics_soon(bufnr)
      restore()
    end)
  end

  vim.ui.select = wrapped_select
  vim.lsp.buf.code_action()

  -- restore even if the action list was empty or an action applied directly
  vim.defer_fn(function()
    refresh_diagnostics_soon(bufnr)
    restore()
  end, 1500)
end

return M
