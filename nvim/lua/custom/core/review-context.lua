-- shared "are we inside a PR/diff review context?" predicates

local M = {}

--- true when any octo buffer is loaded. walks all buffers for an octo
--- filetype. used by autocmds (real-dotnet gate) + the sonar/roslyn
--- suppression restores
function M.is_active()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'octo' then
      return true
    end
  end
  return false
end

--- true when the current tabpage hosts a view that scopes its keymaps to the
--- tabpage (octo's review). reads `package.loaded` so the check never forces
--- the plugin to load; this is a hot keymap path (zoom toggle)
function M.is_scoped_view()
  local octo = package.loaded['octo.reviews']
  return octo ~= nil and octo.get_current_review() ~= nil
end

--- delete every loaded octo buffer (the review-teardown sweep used by <leader>pq)
function M.close_octo_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'octo' then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

return M
