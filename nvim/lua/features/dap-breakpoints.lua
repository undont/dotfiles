-- editable breakpoint-list float (<leader>bl): lines deleted from it remove
-- those breakpoints when the window closes, <CR> jumps to the one under the cursor

local M = {}

---@return string[] lines, {bufnr: integer, line: integer}[] entries
local function collect()
  local lines, entries = {}, {}
  for bufnr, buf_bps in pairs(require('dap.breakpoints').get()) do
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':~:.')
    for _, bp in ipairs(buf_bps) do
      local suffix = ''
      if bp.condition then
        suffix = '  [if: ' .. bp.condition .. ']'
      elseif bp.logMessage then
        suffix = '  [log: ' .. bp.logMessage .. ']'
      end
      table.insert(lines, string.format('%s:%d%s', name, bp.line, suffix))
      table.insert(entries, { bufnr = bufnr, line = bp.line })
    end
  end
  return lines, entries
end

---@param lines string[]
---@return integer buf, integer win
local function open_float(lines)
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
  local win = vim.api.nvim_open_win(buf, true, {
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
  return buf, win
end

--- removing from dap.breakpoints only updates the signs; running sessions
--- keep a breakpoint until its buffer's list is sent again
---@param bufnrs table<integer, true>
local function send_to_sessions(bufnrs)
  local changed = {}
  for bufnr in pairs(bufnrs) do
    changed[bufnr] = require('dap.breakpoints').get(bufnr)[bufnr] or {}
  end
  for _, session in pairs(require('dap').sessions()) do
    session:set_breakpoints(changed)
  end
end

---@param buf integer
---@param lines string[]
---@param entries {bufnr: integer, line: integer}[]
local function remove_deleted(buf, lines, entries)
  local keep = {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    keep[line] = true
  end
  local removed, touched = 0, {}
  for i, original_line in ipairs(lines) do
    if not keep[original_line] then
      local entry = entries[i]
      require('dap.breakpoints').remove(entry.bufnr, entry.line)
      touched[entry.bufnr] = true
      removed = removed + 1
    end
  end
  if removed == 0 then
    return
  end
  send_to_sessions(touched)
  vim.notify(string.format('Removed %d breakpoint%s', removed, removed == 1 and '' or 's'), vim.log.levels.INFO)
end

function M.open()
  local lines, entries = collect()
  if #lines == 0 then
    vim.notify('No breakpoints set', vim.log.levels.INFO)
    return
  end

  local buf, win = open_float(lines)
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function()
      remove_deleted(buf, lines, entries)
    end,
  })

  local function close()
    vim.api.nvim_win_close(win, true)
  end
  vim.keymap.set('n', 'q', close, { buffer = buf })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf })
  vim.keymap.set('n', '<CR>', function()
    -- matched by text: rows shift once lines above are deleted
    local current = vim.api.nvim_get_current_line()
    local entry
    for i, line in ipairs(lines) do
      if line == current then
        entry = entries[i]
      end
    end
    if not entry then
      return
    end
    close()
    vim.api.nvim_set_current_buf(entry.bufnr)
    vim.api.nvim_win_set_cursor(0, { entry.line, 0 })
  end, { buffer = buf })
end

return M
