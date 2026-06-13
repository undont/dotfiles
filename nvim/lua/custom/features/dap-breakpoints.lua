-- Editable breakpoint-list float (<leader>bl). Extracted from the dap spec
-- (formerly kickstart/plugins/debug.lua). open() pops a scratch float listing
-- every breakpoint; deleting lines removes those breakpoints on close, <CR>
-- jumps to the one under the cursor.

local M = {}

function M.open()
  local bp_mod = require 'dap.breakpoints'
  local bps = bp_mod.get()
  local lines = {}
  local entries = {}
  for bufnr, buf_bps in pairs(bps) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':~:.')
    for _, bp in ipairs(buf_bps) do
      local suffix = bp.condition and ('  [if: ' .. bp.condition .. ']') or bp.logMessage and ('  [log: ' .. bp.logMessage .. ']') or ''
      table.insert(lines, string.format('%s:%d%s', name, bp.line, suffix))
      table.insert(entries, { bufnr = bufnr, line = bp.line })
    end
  end
  if #lines == 0 then
    vim.notify('No breakpoints set', vim.log.levels.INFO)
    return
  end

  -- Editable scratch buffer — delete lines to remove breakpoints
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'dap-breakpoints'

  local max_line = 0
  for _, l in ipairs(lines) do
    max_line = math.max(max_line, #l)
  end
  local width = math.min(math.max(max_line + 4, 60), math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.4))
  vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Breakpoints ',
    title_pos = 'center',
  })

  local function sync_and_close()
    local remaining = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local keep = {}
    for _, line in ipairs(remaining) do
      keep[line] = true
    end
    local removed = 0
    for i, original_line in ipairs(lines) do
      if not keep[original_line] then
        local entry = entries[i]
        bp_mod.remove(entry.bufnr, entry.line)
        removed = removed + 1
      end
    end
    vim.bo[buf].modified = false
    vim.api.nvim_win_close(0, true)
    if removed > 0 then
      vim.notify(string.format('Removed %d breakpoint%s', removed, removed == 1 and '' or 's'), vim.log.levels.INFO)
    end
  end

  vim.keymap.set('n', 'q', sync_and_close, { buffer = buf })
  vim.keymap.set('n', '<Esc>', sync_and_close, { buffer = buf })
  vim.keymap.set('n', '<CR>', function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local entry = entries[row]
    if entry then
      vim.bo[buf].modified = false
      vim.api.nvim_win_close(0, true)
      vim.api.nvim_set_current_buf(entry.bufnr)
      vim.api.nvim_win_set_cursor(0, { entry.line, 0 })
    end
  end, { buffer = buf })
end

return M
