-- restart and rename commands for the lsp spec's keymaps and handlers

local M = {}

function M.restart(bufnr)
  -- roslyn's on_exit nils vim.g.roslyn_nvim_selected_solution, so the
  -- restarted client comes back without a solution target. LspDetach
  -- fires after on_exit and before the new client's on_init, so the solution
  -- is restored there
  local saved = vim.g.roslyn_nvim_selected_solution
  if saved and #vim.lsp.get_clients { bufnr = bufnr, name = 'roslyn' } > 0 then
    local id
    id = vim.api.nvim_create_autocmd('LspDetach', {
      callback = function(ev)
        local detached = vim.lsp.get_client_by_id(ev.data.client_id)
        if detached and detached.name == 'roslyn' then
          vim.g.roslyn_nvim_selected_solution = saved
          vim.api.nvim_del_autocmd(id)
        end
      end,
    })
  end

  vim.cmd 'lsp restart'
end

--- rename handler that writes the files it touched. the default handler
--- leaves files that weren't open as unsaved background buffers, which never
--- fire the autosave
function M.rename_and_save(_, result, ctx)
  if not result then
    vim.notify("Language server couldn't provide rename result", vim.log.levels.INFO)
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)

  -- documentChanges is an array of edits; changes is a map keyed by URI
  local uris = {}
  if result.documentChanges then
    for _, change in ipairs(result.documentChanges) do
      -- skip create/rename/delete resource ops, which have no textDocument
      if change.textDocument and change.textDocument.uri then
        uris[change.textDocument.uri] = true
      end
    end
  elseif result.changes then
    for uri in pairs(result.changes) do
      uris[uri] = true
    end
  end

  for uri in pairs(uris) do
    local buf = vim.uri_to_bufnr(uri)
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified and vim.bo[buf].modifiable and vim.bo[buf].buftype == '' then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd 'silent! write'
      end)
    end
  end
end

return M
