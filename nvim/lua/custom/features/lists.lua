-- Quickfix and location list keymaps: toggle, navigate, clear, and
-- route diagnostics into the native lists.

local M = {}

local function toggle_quickfix()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 and win.loclist == 0 then
      vim.cmd 'cclose'
      return
    end
  end
  vim.cmd 'botright copen'
end

local function toggle_loclist()
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.loclist == 1 then
      vim.cmd 'lclose'
      return
    end
  end
  local ok = pcall(vim.cmd.lopen)
  if not ok then
    vim.notify('No location list for current window', vim.log.levels.WARN)
  end
end

-- Override mini.bracketed's ]q/[q and ]l/[l with empty-list notifications.
-- mini.bracketed silently no-ops when the list is empty, which is confusing.
-- :cnext/:cprev echo "(N of M): ..." which ui2 surfaces as a notification.
-- Silence via the :silent! modifier while keeping mini.bracketed's wrap-around.
--
-- mini.bracketed advances from the qf list's "current entry" idx, which only
-- updates via :cc/:cnext/<CR>-in-qf. If the user lands on an entry's location
-- via any other path (LSP jump, search, picker, manual nav), the idx goes
-- stale and ]q/[q skip away from where the cursor actually is. Sync the idx
-- to the entry matching the cursor's current file:line first — or, if we're
-- inside the qf window, to the cursor row itself.
--
-- When multiple entries share the cursor's bufnr+lnum (e.g. several
-- diagnostics on one line), keep the existing idx if it already points at
-- one of them. Snapping to the first match every press would oscillate
-- between the first and second entry forever.
local function sync_list_idx_to_cursor(list, set_idx)
  if vim.bo.buftype == 'quickfix' then
    set_idx(vim.api.nvim_win_get_cursor(0)[1])
    return
  end
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]

  local cur = list.idx and list.items[list.idx]
  if cur and cur.bufnr == cur_buf and cur.lnum == cur_line then
    return
  end

  for i, entry in ipairs(list.items) do
    if entry.bufnr == cur_buf and entry.lnum == cur_line then
      set_idx(i)
      return
    end
  end
end

-- noice's LSP/docs popups can temporarily take focus, which makes list
-- navigation run against the popup buffer instead of the underlying editing
-- window. Resolve back to the last real window first.
local function resolve_list_nav_win()
  local current = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_win_get_buf(current)
  if vim.bo[cur_buf].filetype ~= 'noice' then
    return current
  end

  local function is_source_win(win)
    if not win or win == 0 or win == current or not vim.api.nvim_win_is_valid(win) then
      return false
    end
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.bo[buf].filetype ~= 'noice'
  end

  local prev = vim.fn.win_getid(vim.fn.winnr '#')
  if is_source_win(prev) then
    return prev
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_source_win(win) then
      return win
    end
  end
end

local function with_list_nav_win(fn)
  local win = resolve_list_nav_win()
  if not win then
    vim.notify('No source window for list navigation', vim.log.levels.WARN)
    return
  end
  if win == vim.api.nvim_get_current_win() then
    fn()
    return
  end
  vim.api.nvim_set_current_win(win)
  fn()
end

local function bracketed_qf(direction)
  return function()
    with_list_nav_win(function()
      local list = vim.fn.getqflist { items = 0, idx = 0 }
      if #list.items == 0 then
        vim.notify('Quickfix list is empty', vim.log.levels.WARN)
        return
      end
      sync_list_idx_to_cursor(list, function(idx)
        vim.fn.setqflist({}, 'a', { idx = idx })
      end)
      vim.cmd(string.format([[silent! lua require('mini.bracketed').quickfix(%q)]], direction))
    end)
  end
end

local function bracketed_loc(direction)
  return function()
    with_list_nav_win(function()
      local list = vim.fn.getloclist(0, { items = 0, idx = 0 })
      if #list.items == 0 then
        vim.notify('Location list is empty', vim.log.levels.WARN)
        return
      end
      sync_list_idx_to_cursor(list, function(idx)
        vim.fn.setloclist(0, {}, 'a', { idx = idx })
      end)
      vim.cmd(string.format([[silent! lua require('mini.bracketed').location(%q)]], direction))
    end)
  end
end

-- Diagnostics into native lists. Explicit titles let `build.lua`'s
-- `setup_auto_clear` predicate (`^(%w+):` against `AUTO_CLEAR_KINDS`)
-- match these lists and prune resolved entries on DiagnosticChanged.
-- We bypass `vim.diagnostic.setqflist` so we can route through
-- `scan_runner.diag_to_item`, which prefixes text with `[source]` (the
-- originating LSP). The same prefix is used by the auto-clear's
-- (lnum, text) match so pruning stays accurate.
local function diags_to_items(diagnostics)
  local scan_runner = require 'custom.features.scan-runner'
  local scan_ignored = require('custom.features.diag-scan').scan_ignored
  local items = {}
  for _, d in ipairs(diagnostics) do
    -- Drop scan-ignored phantoms from buffers not shown in any window:
    -- hidden buffers only ever got the reduced-pass pull, and with no
    -- window they never get the full pass that self-corrects in-editor —
    -- they'd sit in the live list indefinitely. Displayed buffers keep
    -- theirs (the full pass has run; entries are real). The predicate is
    -- shared with diag-scan's batch snapshot.
    if d.bufnr and d.lnum then
      local hidden_phantom = scan_ignored(d) and #vim.fn.win_findbuf(d.bufnr) == 0
      if not hidden_phantom then
        table.insert(items, scan_runner.diag_to_item(d))
      end
    end
  end
  table.sort(items, function(a, b)
    if a.bufnr ~= b.bufnr then
      return (a.bufnr or 0) < (b.bufnr or 0)
    end
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return (a.col or 0) < (b.col or 0)
  end)
  return items
end

local DIAG_QF_TITLE = 'Diagnostics: all'

-- Live sync for the <leader>xx list: while the *current* qf list's title is
-- DIAG_QF_TITLE, a debounced DiagnosticChanged rebuild keeps it current in
-- both directions — fixed entries drop out (auto-clear already did that) and
-- new diagnostics flow in, so re-pressing <leader>xx after each round of
-- fixes is no longer needed. Any list push with a different title (:Cfilter,
-- a build, a scan) pauses the sync; <leader>x[ back to the live list resumes.
local function rebuild_live_qf()
  local qf = vim.fn.getqflist { title = 0, idx = 0, items = 0 }
  if qf.title ~= DIAG_QF_TITLE then
    return
  end
  local items = diags_to_items(vim.diagnostic.get(nil))

  if #items == 0 then
    if #qf.items == 0 then
      return
    end
    vim.fn.setqflist({}, 'r', { title = DIAG_QF_TITLE, items = {} })
    -- Close + notify only if build.lua's auto-clear prune hasn't already
    -- (it fires undebounced on the same DiagnosticChanged and closes the
    -- window itself when its prune empties the list).
    for _, win in ipairs(vim.fn.getwininfo()) do
      if win.quickfix == 1 and win.loclist == 0 then
        vim.api.nvim_win_close(win.winid, true)
        vim.notify('Diagnostics: clean', vim.log.levels.INFO)
        break
      end
    end
    return
  end

  -- Preserve the current entry across the rebuild (same idea as build.lua's
  -- prune-idx logic): if the entry the user is pointed at survives, it stays
  -- current; if it was the one just resolved, snap to the nearest surviving
  -- predecessor so the next ]q advances forward rather than jumping to
  -- entry 1 (setqflist's default after replace). Items are sorted by
  -- (bufnr, lnum, col) on both sides, so "predecessor" is positional.
  local new_idx
  local cur = qf.idx and qf.idx > 0 and qf.items[qf.idx] or nil
  if cur then
    for i, item in ipairs(items) do
      if item.bufnr == cur.bufnr and item.lnum == cur.lnum and item.text == cur.text then
        new_idx = i
        break
      end
    end
    if not new_idx then
      for i, item in ipairs(items) do
        local before = (item.bufnr or 0) < (cur.bufnr or 0)
          or (item.bufnr == cur.bufnr and (item.lnum < cur.lnum or (item.lnum == cur.lnum and (item.col or 0) <= (cur.col or 0))))
        if before then
          new_idx = i
        else
          break
        end
      end
    end
  end
  vim.fn.setqflist({}, 'r', { title = DIAG_QF_TITLE, items = items, idx = new_idx })
end

local live_timer

local function schedule_live_rebuild()
  if not live_timer then
    live_timer = assert(vim.uv.new_timer())
  end
  live_timer:stop()
  live_timer:start(300, 0, vim.schedule_wrap(rebuild_live_qf))
end

function M.setup()
  -- Built-in filter plugin: :Cfilter /pat/ keeps matching qf entries,
  -- :Cfilter! /pat/ drops them. Same for :Lfilter on loclists.
  vim.cmd 'packadd cfilter'

  -- Dashboard escape is handled globally in autocmds.lua (FileType qf autocmd)
  vim.keymap.set('n', '<leader>xq', toggle_quickfix, { desc = '[Q]uickfix list toggle' })
  vim.keymap.set('n', '<leader>xl', toggle_loclist, { desc = '[L]ocation list toggle' })

  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = vim.api.nvim_create_augroup('DiagnosticsLiveQf', { clear = true }),
    callback = schedule_live_rebuild,
  })

  -- <leader>xx toggles a *live* list: if the qf window is already showing
  -- the live diagnostics list, close it; otherwise (re)build and open. While
  -- the list is current, the DiagnosticChanged sync above keeps it fresh —
  -- including diagnostics republished after `checktime` reloads buffers an
  -- external writer (Claude Code, another nvim instance, a script) changed,
  -- which previously needed a second press.
  vim.keymap.set('n', '<leader>xx', function()
    local qf = vim.fn.getqflist { title = 0 }
    if qf.title == DIAG_QF_TITLE then
      for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 and win.loclist == 0 then
          vim.cmd 'cclose'
          return
        end
      end
    end
    pcall(vim.cmd, 'checktime')
    local items = diags_to_items(vim.diagnostic.get(nil))
    -- Replace in place when the live list is already current, so repeated
    -- presses don't push duplicate lists onto the qf stack.
    local action = qf.title == DIAG_QF_TITLE and 'r' or ' '
    vim.fn.setqflist({}, action, { title = DIAG_QF_TITLE, items = items })
    if #items == 0 then
      vim.notify('Diagnostics: clean', vim.log.levels.INFO)
    end
    vim.cmd 'botright cwindow'
  end, { desc = 'All [D]iagnostics to quickfix (live)' })
  vim.keymap.set('n', '<leader>xX', function()
    local items = diags_to_items(vim.diagnostic.get(0))
    vim.fn.setloclist(0, {}, ' ', { title = 'Diagnostics: buffer', items = items })
    if #items == 0 then
      vim.notify('Buffer diagnostics: clean', vim.log.levels.INFO)
    end
    vim.cmd 'lwindow'
  end, { desc = 'Buffer diagnostics to loclist' })

  -- Grep the yank register (0 = last yank, untouched by deletes) as a literal
  -- string into the quickfix list. -F keeps regex metacharacters in the yanked
  -- text literal; grep! fills the list without jumping. Flows through grepprg
  -- (rg --vimgrep --smart-case), so ]q/[q navigate the result.
  vim.keymap.set('n', '<leader>x/', function()
    local pat = vim.fn.getreg '0'
    -- rg matches per-line, so collapse a multiline yank to its first line
    pat = pat:gsub('\n.*', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if pat == '' then
      vim.notify('Yank register empty', vim.log.levels.WARN)
      return
    end
    -- shellescape for the shell; escape %/# so vim's cmdline doesn't expand them
    local arg = vim.fn.shellescape(pat):gsub('[%%#]', '\\%0')
    vim.cmd('silent grep! -F ' .. arg)
    vim.cmd 'botright copen'
  end, { desc = 'Grep [/] yanked text → quickfix' })

  vim.keymap.set('n', ']q', bracketed_qf 'forward', { desc = 'Next quickfix entry' })
  vim.keymap.set('n', '[q', bracketed_qf 'backward', { desc = 'Previous quickfix entry' })
  vim.keymap.set('n', ']l', bracketed_loc 'forward', { desc = 'Next location entry' })
  vim.keymap.set('n', '[l', bracketed_loc 'backward', { desc = 'Previous location entry' })

  -- Shadow mini.bracketed (]b/[b ]f/[f ]d/[d ...) inside qf/loclist buffers —
  -- those target the underlying editing window but fire against the list
  -- buffer when it's focused, which is confusing. ]q/[q and ]l/[l stay live.
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('QfDisableBracketed', { clear = true }),
    pattern = 'qf',
    callback = function(ev)
      for _, s in ipairs { 'b', 'd', 'f', 'i', 'j', 'o', 'u', 'w', 'x', 'y' } do
        vim.keymap.set('n', ']' .. s, '<Nop>', { buffer = ev.buf, silent = true })
        vim.keymap.set('n', '[' .. s, '<Nop>', { buffer = ev.buf, silent = true })
      end
    end,
  })

  -- Walk the qf stack — each :Cfilter pushes a new list, so <leader>x[ undoes
  -- the last filter (or any other push). Counts honoured: 3<leader>x[ → :3colder.
  local function qf_history(cmd, edge_msg)
    return function()
      local ok = pcall(vim.cmd, vim.v.count1 .. cmd)
      if not ok then
        vim.notify(edge_msg, vim.log.levels.WARN)
      end
    end
  end
  vim.keymap.set('n', '<leader>x[', qf_history('colder', 'At oldest quickfix list'), { desc = 'Quickfix stack older (undo Cfilter)' })
  vim.keymap.set('n', '<leader>x]', qf_history('cnewer', 'At newest quickfix list'), { desc = 'Quickfix stack newer' })

  vim.keymap.set('n', '<leader>xcq', function()
    vim.fn.setqflist({}, 'r')
    vim.cmd 'cclose'
  end, { desc = '[C]lear [Q]uickfix list' })

  vim.keymap.set('n', '<leader>xcl', function()
    vim.fn.setloclist(0, {}, 'r')
    vim.cmd 'lclose'
  end, { desc = '[C]lear [L]ocation list' })

  vim.keymap.set('n', '<leader>xcc', function()
    vim.fn.setqflist({}, 'r')
    vim.fn.setloclist(0, {}, 'r')
    vim.cmd 'cclose'
    vim.cmd 'lclose'
  end, { desc = '[C]lear both quickfix and location lists' })

  -- <leader>xm / xt / xT (git-scoped diagnostics scans) live in
  -- features/diag-scan.lua, wired separately from core/keymaps.lua.
end

return M
