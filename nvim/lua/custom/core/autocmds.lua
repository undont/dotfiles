-- Core autocommands

local M = {}

function M.setup()
  -- Highlight on yank
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
      vim.hl.on_yank()
    end,
  })

  -- Auto-reload: Check for external changes on focus/buffer events
  local reload_group = vim.api.nvim_create_augroup('auto-reload', { clear = true })
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
    desc = 'Check for external file changes',
    group = reload_group,
    command = 'checktime',
  })

  -- Auto-save: Write buffer on change (with debounce via CursorHold)
  local autosave_group = vim.api.nvim_create_augroup('auto-save', { clear = true })
  vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged' }, {
    desc = 'Auto-save on text change',
    group = autosave_group,
    callback = function(ev)
      local buf = ev.buf
      -- Only save if: buffer is modifiable, has a file, is modified, and not a special buffer
      if vim.bo[buf].modifiable and vim.bo[buf].modified and vim.fn.bufname(buf) ~= '' and vim.bo[buf].buftype == '' then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd 'silent! write'
        end)
      end
    end,
  })
end

return M
