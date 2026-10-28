-- highlight zig format specifiers (`{d}`, `{s:>10}`, `{any}`) inside format
-- strings. zls sends one `string` token for the literal and no token for a
-- specifier, and a treesitter query can't capture part of a string node, so
-- this module walks the zig tree and marks them itself

local M = {}

local ns = vim.api.nvim_create_namespace 'zig-format-specifiers'

-- above semantic tokens, so zls's string token can't cover a specifier
local PRIORITY = 126

-- shared with features.go-format-verbs, which sets the same default link
local HL_GROUP = '@string.special.format'

local function link_default()
  vim.api.nvim_set_hl(0, HL_GROUP, { link = '@string.escape', default = true })
end

-- a format string is the argument just before a trailing `.{ ... }` tuple,
-- which covers print, log, allocPrint, bufPrint and friends without a name list
local QUERY = [[
  (call_expression
    arguments: (arguments
      [
        (string)
        (multiline_string)
      ] @fmt
      .
      (anonymous_struct_initializer)
      .))
]]

local query

--- byte ranges of every `{...}` specifier in `s`, 0-based and end-exclusive.
--- `{{` and `}}` are literal braces and are skipped
---@param s string
---@return integer[][]
local function specifier_ranges(s)
  local out, i = {}, 1
  while true do
    local open = s:find('[{}]', i)
    if not open then
      return out
    end
    local brace = s:sub(open, open)
    if s:sub(open + 1, open + 1) == brace then
      i = open + 2
    elseif brace == '}' then
      i = open + 1
    else
      local close = s:find('[{}]', open + 1)
      if close and s:sub(close, close) == '}' then
        out[#out + 1] = { open - 1, close }
        i = close + 1
      else
        i = open + 1
      end
    end
  end
end

--- a multiline string spans rows, so each of its lines is scanned against its
--- own buffer row
---@param buf integer
---@param node TSNode
local function mark(buf, node)
  local srow, scol = node:start()
  local text = vim.treesitter.get_node_text(node, buf)
  for k, line in ipairs(vim.split(text, '\n', { plain = true })) do
    local base = k == 1 and scol or 0
    for _, range in ipairs(specifier_ranges(line)) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, srow + k - 1, base + range[1], {
        end_col = base + range[2],
        hl_group = HL_GROUP,
        priority = PRIORITY,
      })
    end
  end
end

-- the ceiling plugins/treesitter.lua puts on `vim.treesitter.start`. measured
-- from the buffer, not fs_stat, which misses unsaved edits and touches disk
local MAX_BYTES = 1024 * 1024

---@param buf integer
local function refresh(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= 'zig' then
    return
  end
  if vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) > MAX_BYTES then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'zig')
  if not ok or not parser then
    return
  end
  local tree = parser:parse()[1]
  if not tree then
    return
  end
  if not query then
    local parsed
    ok, parsed = pcall(vim.treesitter.query.parse, 'zig', QUERY)
    if not ok then
      return
    end
    query = parsed
  end

  for id, node in query:iter_captures(tree:root(), buf) do
    if query.captures[id] == 'fmt' then
      mark(buf, node)
    end
  end
end

local timers = {}

--- debounced, so redraws coalesce while typing
---@param buf integer
local function schedule(buf)
  local timer = timers[buf]
  if not timer then
    timer = vim.uv.new_timer()
    timers[buf] = timer
  end
  timer:stop()
  timer:start(
    120,
    0,
    vim.schedule_wrap(function()
      refresh(buf)
    end)
  )
end

---@param buf integer
local function release(buf)
  local timer = timers[buf]
  if timer then
    timer:stop()
    timer:close()
    timers[buf] = nil
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('zig-format-specifiers', { clear = true })

  link_default()

  vim.api.nvim_create_autocmd('ColorScheme', {
    desc = 'Restore the zig format specifier highlight link',
    group = group,
    callback = link_default,
  })

  vim.api.nvim_create_autocmd('FileType', {
    desc = 'Highlight zig format specifiers',
    group = group,
    pattern = 'zig',
    callback = function(ev)
      refresh(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'InsertLeave' }, {
    desc = 'Refresh zig format specifier highlights',
    group = group,
    pattern = '*.zig',
    callback = function(ev)
      schedule(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufUnload', 'BufDelete' }, {
    desc = 'Drop the zig format specifier debounce timer',
    group = group,
    pattern = '*.zig',
    callback = function(ev)
      release(ev.buf)
    end,
  })
end

return M
