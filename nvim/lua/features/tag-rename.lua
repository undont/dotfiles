-- tag-pair auto-rename: an edit to a tag name updates its opening or closing
-- partner. regex over the buffer text, no treesitter, so markdown's html
-- injection works like jsx/html; tags may span lines.
-- no keymap interception: the cursor's tag is snapshotted on ModeChanged
-- (before an operator touches text), CursorMoved(I) and BufEnter/FileType, and
-- propagation runs from TextChanged(I), which covers operators, `r`, `R`,
-- dot-repeat and macros

local M = {}

local pending = nil
local applying = false

local NAME_PAT = '[%w_:.%-]+'

-- every `<...>` tag in document order, as { row, col, end_row, end_col, name,
-- is_close, is_self_closing }. row/col are the 0-indexed position of `<`;
-- end_row/end_col are one past `>`. tag bodies containing `>` (`<x a="a>b">`,
-- JSX generics like `<Foo<string>>`) are not detected
local function scan_buffer()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, '\n')
  local line_starts = { 0 }
  for i = 1, #lines - 1 do
    line_starts[i + 1] = line_starts[i] + #lines[i] + 1
  end

  local tags = {}
  local idx = 1
  for s, body, e in text:gmatch '()<([^<>]-)>()' do
    local so = s - 1
    local eo = e - 1

    while idx < #line_starts and line_starts[idx + 1] <= so do
      idx = idx + 1
    end
    local row, col = idx - 1, so - line_starts[idx]

    while idx < #line_starts and line_starts[idx + 1] <= eo do
      idx = idx + 1
    end
    local end_row, end_col = idx - 1, eo - line_starts[idx]

    local is_close = body:sub(1, 1) == '/'
    local is_self_closing = (not is_close) and body:sub(-1) == '/'
    local name = body:match('^/?(' .. NAME_PAT .. ')')
    if name then
      tags[#tags + 1] = {
        row = row,
        col = col,
        end_row = end_row,
        end_col = end_col,
        name = name,
        is_close = is_close,
        is_self_closing = is_self_closing,
      }
    end
  end

  return tags
end

local function pos_in_span(row, col, sr, sc, er, ec)
  if row < sr or row > er then
    return false
  end
  if row == sr and col < sc then
    return false
  end
  if row == er and col >= ec then
    return false
  end
  return true
end

local function find_tag_at(row, col)
  for _, t in ipairs(scan_buffer()) do
    if pos_in_span(row, col, t.row, t.col, t.end_row, t.end_col) then
      return t
    end
  end
end

-- depth-counts same-name tags forward (opens) or backward (closes). the source
-- is anchored by (row, col), not by name: mid-edit, the source's name in the
-- buffer differs from the name the partner is looked up under
local function find_partner(tag)
  if tag.is_self_closing then
    return
  end

  local all_tags = scan_buffer()

  local source_idx
  for i, t in ipairs(all_tags) do
    if t.row == tag.row and t.col == tag.col then
      source_idx = i
      break
    end
  end
  if not source_idx then
    return
  end

  local depth = 1
  if tag.is_close then
    for i = source_idx - 1, 1, -1 do
      local t = all_tags[i]
      if t.name == tag.name and not t.is_self_closing then
        depth = depth + (t.is_close == tag.is_close and 1 or -1)
        if depth == 0 then
          return t
        end
      end
    end
  else
    for i = source_idx + 1, #all_tags do
      local t = all_tags[i]
      if t.name == tag.name and not t.is_self_closing then
        depth = depth + (t.is_close == tag.is_close and 1 or -1)
        if depth == 0 then
          return t
        end
      end
    end
  end
end

-- takes or refreshes `pending` when the cursor is on a tag. a failed
-- find_tag_at doesn't clear it: a `ciw`/`cit` deletion leaves the cursor in
-- `<>` (no name, so no tag) before the replacement is typed.
-- a tag already snapshotted is skipped: partner_name advances after each sync,
-- and a re-snapshot mid-edit would reset it to the cursor-side name
local function refresh_snapshot()
  if applying then
    return
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local tag = find_tag_at(row - 1, col)
  if not tag then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  if pending and pending.buf == buf and pending.tag.row == tag.row and pending.tag.col == tag.col then
    return
  end
  local partner = find_partner(tag)
  if not partner then
    pending = nil
    return
  end
  pending = {
    tag = tag,
    partner_name = tag.name,
    buf = buf,
  }
end

local function sync()
  if not pending or applying then
    return
  end
  local p = pending
  if p.buf ~= vim.api.nvim_get_current_buf() then
    pending = nil
    return
  end

  -- the name may have been edited; the `<` position is unchanged
  local current = find_tag_at(p.tag.row, p.tag.col)
  if not current or current.is_close ~= p.tag.is_close then
    return
  end
  if current.name == p.partner_name then
    return
  end

  -- same-line partner positions shift when the rename changes the name
  -- length, so the partner is located again by its current name
  local partner = find_partner {
    name = p.partner_name,
    is_close = p.tag.is_close,
    is_self_closing = false,
    row = p.tag.row,
    col = p.tag.col,
  }
  if not partner then
    return
  end

  local prefix_len = partner.is_close and 2 or 1
  local name_start = partner.col + prefix_len
  local name_end = name_start + #p.partner_name

  applying = true
  pcall(vim.cmd, 'silent! undojoin')
  pcall(vim.api.nvim_buf_set_text, 0, partner.row, name_start, partner.row, name_end, { current.name })
  applying = false

  p.partner_name = current.name
end

function M.setup()
  local filetypes = {
    'markdown',
    'html',
    'xml',
    'svg',
    'vue',
    'svelte',
    'astro',
    'javascriptreact',
    'typescriptreact',
    'php',
  }

  local group = vim.api.nvim_create_augroup('custom-tag-rename', { clear = true })

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = filetypes,
    callback = function(args)
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertEnter', 'BufEnter', 'ModeChanged' }, {
        group = group,
        buffer = args.buf,
        callback = refresh_snapshot,
      })

      -- vim.schedule moves the buffer write out of the autocmd
      vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
        group = group,
        buffer = args.buf,
        callback = function()
          if applying then
            return
          end
          vim.schedule(sync)
        end,
      })

      -- covers what TextChangedI missed (e.g. cursor moved past `>` on the
      -- last keystroke)
      vim.api.nvim_create_autocmd('InsertLeave', {
        group = group,
        buffer = args.buf,
        callback = sync,
      })

      -- BufEnter may have fired before the autocmd above existed, so the
      -- buffer that triggered this FileType is snapshotted here
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(args.buf) and vim.api.nvim_get_current_buf() == args.buf then
          refresh_snapshot()
        end
      end)
    end,
  })
end

return M
