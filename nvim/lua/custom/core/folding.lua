-- Folding keymaps: default zr/zc/zm to their recursive/all-fold variants.

local M = {}

local function safe_fold_alias(target)
  return function()
    local ok, msg = pcall(function()
      vim.cmd('normal! ' .. target)
    end)
    if ok then
      return
    end
    if type(msg) == 'string' and msg:match 'E490: No fold found' then
      return
    end
    vim.api.nvim_echo({ { tostring(msg), 'ErrorMsg' } }, true, { err = true })
  end
end

function M.setup()
  vim.keymap.set('n', 'zr', safe_fold_alias 'zR', { desc = 'Open all folds', silent = true })
  vim.keymap.set('n', 'zc', safe_fold_alias 'zC', { desc = 'Close fold recursively', silent = true })
  vim.keymap.set('n', 'zm', safe_fold_alias 'zM', { desc = 'Close all folds', silent = true })
end

return M
