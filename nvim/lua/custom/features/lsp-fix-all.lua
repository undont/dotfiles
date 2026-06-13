-- fix-all-in-file (grf) and the diagnostic-refreshing code-action picker (gra).
-- extracted from plugins/lsp.lua. fix_all_in_file applies a quickfix action for
-- every diagnostic bottom-up so line shifts don't break later fixes;
-- code_action_with_refresh wraps the built-in picker to re-pull diagnostics
-- after the chosen action applies

local M = {}

--- collect, deduplicate, and sort diagnostics for fix-all-in-file.
--- returns items sorted bottom-up so line shifts don't affect earlier fixes.
local function collect_fixable_diagnostics(bufnr)
  local diagnostics = vim.diagnostic.get(bufnr)
  if #diagnostics == 0 then
    return {}
  end

  local seen = {}
  local items = {}
  for _, d in ipairs(diagnostics) do
    local key = d.lnum .. ':' .. d.col .. ':' .. (d.message or '')
    if not seen[key] then
      seen[key] = true
      local lsp_diag = d.user_data and d.user_data.lsp
        or {
          range = {
            start = { line = d.lnum, character = d.col },
            ['end'] = { line = d.end_lnum or d.lnum, character = d.end_col or d.col },
          },
          message = d.message,
          severity = d.severity,
          source = d.source,
          code = d.code,
        }
      table.insert(items, { lnum = d.lnum, col = d.col, lsp = lsp_diag })
    end
  end

  table.sort(items, function(a, b)
    if a.lnum == b.lnum then
      return a.col > b.col
    end
    return a.lnum > b.lnum
  end)

  return items
end

--- resolve a code action if needed, then apply it.
--- some servers (Roslyn) return lazy actions that need codeAction/resolve.
local function resolve_and_apply(bufnr, action, client, on_done)
  local function apply(a)
    if a.edit then
      vim.lsp.util.apply_workspace_edit(a.edit, 'utf-8')
      return true
    elseif a.command and client then
      client:exec_cmd(a.command)
      return true
    end
    return false
  end

  if action.edit or action.command then
    local applied = apply(action)
    on_done(applied)
  else
    vim.lsp.buf_request(bufnr, 'codeAction/resolve', action, function(err, resolved)
      local applied = not err and resolved and apply(resolved) or false
      on_done(applied)
    end)
  end
end

--- nudge attached LSPs to recompute diagnostics after code actions/fix-all.
--- some servers republish on didChange, others only on an explicit pull.
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

--- wrap the built-in code action picker so we can refresh diagnostics after
--- the chosen action is applied without reimplementing nvim's selector flow.
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

--- apply all quickfix code actions for every diagnostic in the current buffer.
--- processes bottom-up so line shifts from earlier fixes don't break later ones.
function M.fix_all_in_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local items = collect_fixable_diagnostics(bufnr)
  if #items == 0 then
    vim.notify('No diagnostics in file', vim.log.levels.INFO)
    return
  end

  local applied = 0
  local function apply_next(idx)
    if idx > #items then
      refresh_diagnostics_soon(bufnr)
      vim.notify(string.format('Applied %d fix%s', applied, applied == 1 and '' or 'es'), vim.log.levels.INFO)
      return
    end

    local item = items[idx]
    local range = item.lsp.range
      or {
        start = { line = item.lnum, character = item.col },
        ['end'] = { line = item.lnum, character = item.col },
      }
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      range = range,
      context = { diagnostics = { item.lsp } },
    }

    local handled = false
    vim.lsp.buf_request(bufnr, 'textDocument/codeAction', params, function(err, result, ctx)
      if handled then
        return
      end
      handled = true

      if err or not result or #result == 0 then
        vim.defer_fn(function()
          apply_next(idx + 1)
        end, 50)
        return
      end

      -- prefer quickfix kind, fall back to first action
      local action
      for _, a in ipairs(result) do
        if a.kind and a.kind:find '^quickfix' then
          action = a
          break
        end
      end
      action = action or result[1]

      local client = vim.lsp.get_client_by_id(ctx.client_id)
      resolve_and_apply(bufnr, action, client, function(was_applied)
        if was_applied then
          applied = applied + 1
        end
        vim.defer_fn(function()
          apply_next(idx + 1)
        end, 50)
      end)
    end)
  end

  apply_next(1)
end

return M
