-- Lightweight tag-pair auto-rename. Watches the buffer for edits to a
-- tag name and updates the matching opening or closing tag to match.
--
-- Operates by regex over the buffer text (no treesitter), so it works the
-- same in markdown's html injection as it does in jsx/html — no parser
-- timing issues, no injection-range fragility. Multi-line tag bodies are
-- supported, so JSX's `<div\n  className="x"\n>` pairs with `</div>`.
--
-- No keymap interception. Snapshots the cursor's tag on `ModeChanged`
-- (catches `c{motion}`/`d{motion}`/`R`/`s` the moment the operator is
-- pressed, before any text is touched), `CursorMoved`/`CursorMovedI` (for
-- `r{char}` and post-edit cursor jiggle), and `BufEnter`/`FileType` (for
-- buffers entered with the cursor already on a tag). Propagation runs
-- from `TextChanged`/`TextChangedI`, so `cfn`, `c$`, `cit`, `r{char}`,
-- `R`, dot-repeat, macros, and multi-cursor edits all flow through.

local M = {}

local pending = nil
local applying = false

local NAME_PAT = '[%w_:.%-]+'

-- Scan the buffer for `<...>` tags. Returns a list in document order;
-- each entry is { row, col, end_row, end_col, name, is_close,
-- is_self_closing }. row/col are the 0-indexed position of `<`;
-- end_row/end_col are 0-indexed one-past-`>`. A tag may span multiple
-- lines (row != end_row) when its body crosses newlines.
-- Limitation: tag bodies containing `>` (e.g. `<x attr="a>b">` or JSX
-- generics like `<Foo<string>>`) are not detected — fine for our editing
-- usage.
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

-- Find the structural partner of `tag` by walking the buffer's tag list
-- forward (for opens) or backward (for closes), depth-counting same-name
-- tags. Anchors to the source by (row, col) — *not* by name — so it still
-- works while the user is mid-edit and the source's actual buffer name
-- no longer matches what we're looking for the partner under.
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

-- Take or refresh `pending` if the cursor is on a tag. Doesn't clear when
-- find_tag_at fails: an in-flight `ciw`/`cit` deletion can briefly leave
-- the cursor in `<>` (no name → no tag) before the user starts typing the
-- replacement, and clearing here would lose the snapshot we need.
--
-- The "same tag we already snapshotted? bail" check is load-bearing:
-- partner_name advances after each successful sync to track the partner's
-- current name, and a re-snapshot mid-edit would reset it back to the
-- (now-stale) cursor-side name and break the next find_partner.
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

  -- Re-read at the original `<` position. The user may have edited the
  -- tag name; the `<` itself shouldn't have moved.
  local current = find_tag_at(p.tag.row, p.tag.col)
  if not current or current.is_close ~= p.tag.is_close then
    return
  end
  if current.name == p.partner_name then
    return
  end

  -- Re-locate the partner each time. Same-line partner positions shift
  -- whenever the rename changes name length, so we walk from scratch
  -- using the partner's *current* name.
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

function M.setup(opts)
  opts = opts or {}
  local filetypes = opts.filetypes
    or {
      'markdown',
      'html',
      'xml',
      'svg',
      'vue',
      'svelte',
      'astro',
      'jsx',
      'tsx',
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

      -- vim.schedule defers the buffer write out of the autocmd so we
      -- don't fight the editor's mid-event state.
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

      -- Final sync on insert exit catches anything TextChangedI may have
      -- missed (e.g. cursor moved past `>` on the last keystroke).
      vim.api.nvim_create_autocmd('InsertLeave', {
        group = group,
        buffer = args.buf,
        callback = sync,
      })

      -- Initial snapshot for the buffer that triggered this FileType: on
      -- first load BufEnter may have already fired before the autocmd
      -- above existed, so a cold-open `<cursor on tag> + r{char}` would
      -- otherwise miss its snapshot.
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(args.buf) and vim.api.nvim_get_current_buf() == args.buf then
          refresh_snapshot()
        end
      end)
    end,
  })
end

return M
