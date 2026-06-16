-- shared "are we inside a PR/diff review context?" predicates

local M = {}

--- true when a diffview view is open or any octo buffer is loaded. uses
--- pcall(require) so it works before the hot keymap path; walks all buffers for
--- an octo filetype. used by autocmds (real-dotnet gate) + the sonar/roslyn
--- suppression restores
function M.is_active()
  local ok, dv = pcall(require, 'diffview.lib')
  if ok and dv.get_current_view() then
    return true
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'octo' then
      return true
    end
  end
  return false
end

--- true when the current tabpage hosts a view that scopes its keymaps to the
--- tabpage (diffview, or octo's review). reads `package.loaded` so the check
--- never forces either plugin to load; this is a hot keymap path (zoom toggle)
function M.is_scoped_view()
  local dv = package.loaded['diffview.lib']
  if dv and dv.get_current_view() then
    return true
  end
  local octo = package.loaded['octo.reviews']
  return octo ~= nil and octo.get_current_review() ~= nil
end

--- delete every loaded octo buffer (the review-teardown sweep shared by
--- <leader>pq and edit_diff_file's octo branch)
function M.close_octo_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'octo' then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

return M
