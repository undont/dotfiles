-- Diffview open + "edit the file under the diff". extracted from
-- plugins/pr-review.lua. diffview_open drives the <leader>d* keymaps;
-- edit_diff_file (<leader>de) closes the current diff/review context and opens
-- the viewed file for normal editing

local review_context = require 'custom.core.review-context'

local M = {}

--- re-attach treesitter highlighting on the current buffer ONLY if it's
--- not already active. after `<leader>de` switches from a diff context to
--- a normal edit buffer, some :edit paths leave treesitter unattached.
--- calling vim.treesitter.start unconditionally would replace an active
--- highlighter and force a full re-parse (slow on large files, visible
--- as flicker), so we skip when one is already attached
local function refresh_treesitter_highlight()
  if vim.bo.filetype == '' then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.treesitter.highlighter.active[bufnr] then
    return
  end
  pcall(vim.treesitter.start, 0)
end

--- run a diffview command, closing any existing diffview first
function M.diffview_open(cmd)
  local lib = require 'diffview.lib'
  local view = lib.get_current_view()
  if view then
    view:close()
    lib.dispose_view(view)
  end
  vim.cmd(cmd)
end

--- close the current diff context and open the viewed file for editing.
--- works for both diffview and octo review contexts
function M.edit_diff_file()
  -- try diffview first
  local dv_ok, dv_lib = pcall(require, 'diffview.lib')
  if dv_ok then
    local view = dv_lib.get_current_view()
    if view then
      local file = view:infer_cur_file()
      if not file or not file.absolute_path then
        vim.notify('No file under cursor', vim.log.levels.WARN)
        return
      end

      -- guard: file may have been deleted in this diff
      if vim.fn.filereadable(file.absolute_path) ~= 1 then
        vim.notify('File does not exist on disk: ' .. file.path, vim.log.levels.WARN)
        return
      end

      -- capture cursor position before closing. try the right-side (new)
      -- diff pane first, fall back to current window
      local cursor
      if view.cur_layout then
        local win = view.cur_layout:get_main_win()
        if win and win.id and vim.api.nvim_win_is_valid(win.id) then
          cursor = vim.api.nvim_win_get_cursor(win.id)
        end
      end
      if not cursor then
        cursor = vim.api.nvim_win_get_cursor(0)
      end

      local path = file.absolute_path

      -- close the tabpage directly for instant visual feedback
      local tabpage = view.tabpage
      if tabpage and vim.api.nvim_tabpage_is_valid(tabpage) then
        if #vim.api.nvim_list_tabpages() == 1 then
          vim.cmd 'tabnew'
        end
        vim.cmd('tabclose ' .. vim.api.nvim_tabpage_get_number(tabpage))
      end

      vim.cmd('edit ' .. vim.fn.fnameescape(path))
      if cursor then
        pcall(vim.api.nvim_win_set_cursor, 0, cursor)
      end

      vim.schedule(refresh_treesitter_highlight)

      -- defer heavy cleanup (file:destroy() per diff buffer) so the
      -- editor stays responsive. event suppression keeps it fast
      vim.schedule(function()
        local ei = vim.o.eventignore
        vim.o.eventignore = 'all'
        view:close()
        dv_lib.dispose_view(view)
        vim.o.eventignore = ei
      end)

      return
    end
  end

  -- try octo review
  local octo_ok, reviews = pcall(require, 'octo.reviews')
  if octo_ok then
    local review = reviews.get_current_review()
    if review and review.layout then
      local layout = review.layout
      local file = layout:get_current_file()
      if not file then
        vim.notify('No file in review', vim.log.levels.WARN)
        return
      end

      local path = file.path

      -- guard: file may not exist if the PR branch isn't checked out
      if vim.fn.filereadable(path) ~= 1 then
        vim.notify('File not on disk (PR branch not checked out?): ' .. path, vim.log.levels.WARN)
        return
      end

      -- warn if on a different branch: file exists but may be a different version
      local octo_utils = require 'octo.utils'
      if file.pull_request and not octo_utils.in_pr_branch(file.pull_request) then
        local choice = vim.fn.confirm('Not on the PR branch — file may differ from the review. Edit anyway?', '&Yes\n&No', 2)
        if choice ~= 1 then
          return
        end
      end

      -- read cursor from the right (new) side; if the user is on the left
      -- (old) side the line numbers won't match the current file
      local right_win = layout.right_winid
      local cursor
      if right_win and vim.api.nvim_win_is_valid(right_win) then
        cursor = vim.api.nvim_win_get_cursor(right_win)
      end

      -- close review layout and remaining octo buffers
      layout:close()
      review_context.close_octo_buffers()

      vim.schedule(function()
        vim.cmd('edit ' .. vim.fn.fnameescape(path))
        pcall(vim.api.nvim_win_set_cursor, 0, cursor)
        vim.cmd 'doautocmd BufEnter'
        refresh_treesitter_highlight()
      end)
      return
    end
  end

  vim.notify('No diff context found', vim.log.levels.WARN)
end

return M
