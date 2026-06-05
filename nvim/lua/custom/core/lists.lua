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

-- Hidden-load all git-modified (unstaged) and untracked files so LSPs attach,
-- then debounce on DiagnosticChanged and dump the resulting diagnostics into
-- the quickfix list — without switching the current buffer. Falls through
-- after a hard timeout if nothing publishes.
--
-- The 5s debounce / 5min timeout is generous enough for sonarlint's java
-- analyzers (which auto-attach via the plugin's `ft` lazy-load when the
-- scan sets the hidden buffer's filetype — bufload alone doesn't reliably
-- fire detection, see scan_files).
--
-- Roslyn (and other LSPs that only push diagnostics for visible documents)
-- need an explicit pull via `textDocument/diagnostic`. Pulling before
-- Roslyn's workspace finishes initialising returns -30099, so we wrap its
-- `workspace/projectInitializationComplete` handler — an LSP protocol
-- contract — and pull from inside the wrap. Coupling is to the method name,
-- not to roslyn.nvim's `User RoslynInitialized` autocmd (private API).

local ROSLYN_FTS = { cs = true, razor = true, cshtml = true }

local function pull_diagnostics(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  if not next(vim.lsp.get_clients { bufnr = bufnr, method = 'textDocument/diagnostic' }) then
    return
  end
  pcall(vim.lsp.diagnostic._enable, bufnr)
  pcall(vim.lsp.diagnostic._refresh, bufnr)
end

-- Idempotently install a wrap around roslyn's
-- `workspace/projectInitializationComplete` handler. Installed eagerly via a
-- global LspAttach autocmd in setup() so the wrap is always in place before
-- the notification fires — this lets us trust `__git_modified_init_done` for
-- warm-start scans (where init already happened in a prior xm or earlier in
-- the session).
local function wrap_roslyn(client)
  if client.__git_modified_wrapped then
    return
  end
  client.handlers = client.handlers or {}
  local original = client.handlers['workspace/projectInitializationComplete']
  client.handlers['workspace/projectInitializationComplete'] = function(err, res, ctx)
    if original then
      pcall(original, err, res, ctx)
    end
    client.__git_modified_init_done = true
    local cbs = client.__git_modified_init_cbs or {}
    client.__git_modified_init_cbs = {}
    for _, cb in ipairs(cbs) do
      pcall(cb)
    end
  end
  client.__git_modified_wrapped = true
  client.__git_modified_init_cbs = {}
end

-- Run `on_ready` once Roslyn's workspace is initialised. Fires immediately
-- on warm starts where the wrap has already observed init; queues otherwise.
local function on_roslyn_ready(client, on_ready)
  wrap_roslyn(client)
  if client.__git_modified_init_done then
    pcall(on_ready)
  else
    table.insert(client.__git_modified_init_cbs, on_ready)
  end
end

-- Pull diagnostics, gating C#-family files behind Roslyn's project-init
-- notification. Non-C# buffers pull immediately. If Roslyn hasn't attached
-- yet, the LspAttach handler picks it up.
--
-- The validity guard matters: the LspAttach handler defers this by 500ms,
-- and the scan can finalise (deleting its created buffers) in that window —
-- e.g. via the 500ms settled debounce. vim.bo on a deleted buffer throws.
local function pull_gated(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if ROSLYN_FTS[vim.bo[bufnr].filetype] then
    local roslyn = vim.lsp.get_clients({ bufnr = bufnr, name = 'roslyn' })[1]
    if roslyn then
      on_roslyn_ready(roslyn, function()
        pull_diagnostics(bufnr)
      end)
    end
    return
  end
  pull_diagnostics(bufnr)
end

-- Diagnostic codes excluded from scan snapshots (not from in-editor
-- diagnostics). Roslyn's pull for hidden-loaded buffers reports false
-- positives for rules that need a full compilation/analyzer pass, while
-- the scan-time pull analyses with a reduced one — a long-standing roslyn
-- defect (dotnet/roslyn#47288, #75887):
--   IDE0079 ("Remove unnecessary suppression") — judging a suppression
--     needs the suppressed analyzer (e.g. Sonar's S-rules) to run.
--   IDE0005 ("Using directive is unnecessary") — needs full reference
--     resolution to know what each using actually binds.
-- Opening the file for real runs the full pass and these vanish, so
-- in-editor they self-correct; in a scan snapshot they'd sit in the
-- quickfix as phantom entries until each file is visited. The live
-- <leader>xx list applies the same filter to buffers hidden from every
-- window (diags_to_items), where that self-correction can never happen.
local SCAN_IGNORED_CODES = { IDE0079 = true, IDE0005 = true }

-- `code` can land as a string, a number, or only inside the raw LSP
-- diagnostic (`user_data.lsp.code`) depending on the producing path —
-- normalise before the lookup.
local function scan_ignored(d)
  local code = d.code
  if code == nil and d.user_data and d.user_data.lsp then
    code = d.user_data.lsp.code
  end
  return code ~= nil and SCAN_IGNORED_CODES[tostring(code)] == true
end

local function scan_diagnostics(bufnr)
  return vim.tbl_filter(function(d)
    return not scan_ignored(d)
  end, vim.diagnostic.get(bufnr))
end

--- Shared scan driver behind <leader>xm and <leader>xT: hidden-load the
--- given absolute paths so LSPs attach, pull/await diagnostics and dump
--- them into a titled quickfix via scan_runner.
--- @param paths string[] absolute paths
--- @param opts { qf_title: string, qf_label: string, augroup_name: string, empty_message: string }
local function scan_files(paths, opts)
  local scan_runner = require 'custom.core.scan_runner'
  if scan_runner.is_active() then
    vim.notify('A scan is already running', vim.log.levels.WARN)
    return
  end

  -- Skip paths that don't exist on disk: the sources include deleted files
  -- (`git ls-files -m` lists deleted-but-unstaged entries; ticket commits
  -- may touch since-deleted files), and creating buffers for missing files
  -- triggers easy-dotnet's BootstrapFile to walk a missing directory and
  -- crash with -32000.
  local bufnrs = {}
  local target = {}
  local created = {}
  for _, abs in ipairs(paths) do
    if vim.fn.filereadable(abs) == 1 then
      local existed = vim.fn.bufnr(abs) ~= -1
      local bufnr = vim.fn.bufadd(abs)
      pcall(vim.fn.bufload, bufnr)
      -- bufload doesn't reliably run filetype detection for hidden buffers
      -- (scanned buffers were observed with ft = ""). Without a filetype,
      -- sonarlint's FileType attach never fires (so scans silently miss
      -- sonar findings), pull_gated misses the ROSLYN_FTS init gate, and
      -- the qf [source] filetype fallback label is lost. Detect and set it
      -- explicitly, mirroring the sonar project scan in sonarlint.lua.
      if vim.bo[bufnr].filetype == '' then
        local ft = vim.filetype.match { buf = bufnr, filename = abs }
        if ft then
          vim.bo[bufnr].filetype = ft
        end
      end
      table.insert(bufnrs, bufnr)
      target[bufnr] = true
      if not existed then
        table.insert(created, bufnr)
      end
    end
  end
  if #bufnrs == 0 then
    vim.notify(opts.empty_message, vim.log.levels.INFO)
    return
  end

  -- Already-attached clients (e.g. a buffer the user had visited earlier).
  for _, bufnr in ipairs(bufnrs) do
    pull_gated(bufnr)
  end

  -- Late-attaching clients — sonarlint via filetype lazy-load, roslyn via
  -- file-association autostart. Roslyn pulls go through the init-gate; other
  -- clients get a small defer so dynamic capability registration can settle.
  local pull_group = vim.api.nvim_create_augroup(opts.augroup_name .. 'Pull', { clear = true })
  vim.api.nvim_create_autocmd('LspAttach', {
    group = pull_group,
    callback = function(args)
      if not target[args.buf] then
        return
      end
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == 'roslyn' then
        local b = args.buf
        on_roslyn_ready(client, function()
          pull_diagnostics(b)
        end)
      else
        vim.defer_fn(function()
          pull_gated(args.buf)
        end, 500)
      end
    end,
  })

  -- Fidget progress (same shape as the sonarlint scan): counts up as each
  -- watched buffer first reports a DiagnosticChanged, so a slow scan is
  -- visibly working rather than a black box. Falls back to a plain notify.
  local fidget_ok, fidget = pcall(require, 'fidget.progress')
  local progress = fidget_ok
      and fidget.handle.create {
        title = opts.qf_label,
        message = 'scanning ' .. #bufnrs .. ' file(s)',
        lsp_client = { name = opts.qf_label:lower() .. '-scan' },
      }
    or nil
  if not progress then
    vim.notify('Scanning ' .. #bufnrs .. ' file(s)…', vim.log.levels.INFO)
  end

  scan_runner.start {
    bufnrs = bufnrs,
    get_diagnostics = scan_diagnostics,
    debounce_ms = 5000,
    -- Once every watched buffer has reported, the long debounce is dead
    -- air — finalise after a short settle instead.
    settled_debounce_ms = 500,
    -- ...unless a sonarlint client is attached to a scanned buffer: a
    -- buffer's *first* report comes from its fastest LSP, while sonarlint's
    -- java analyzers publish seconds later — the 5s debounce exists for
    -- exactly that gap, so keep it. A cold sonarlint JVM isn't attached by
    -- settle time, but its results arrive long after the old 5s window too,
    -- so the fast path loses nothing there.
    settle_check = function()
      for _, client in ipairs(vim.lsp.get_clients { name = 'sonarlint.nvim' }) do
        for _, b in ipairs(bufnrs) do
          if (client.attached_buffers or {})[b] then
            return false
          end
        end
      end
      return true
    end,
    hard_timeout_ms = 5 * 60 * 1000,
    qf_title = opts.qf_title,
    qf_label = opts.qf_label,
    augroup_name = opts.augroup_name,
    progress = progress,
    on_report = progress and function(reported, total)
      progress:report { message = reported .. '/' .. total .. ' file(s) reported' }
    end or nil,
    on_finalise = function()
      pcall(vim.api.nvim_del_augroup_by_id, pull_group)
      for _, b in ipairs(created) do
        if vim.api.nvim_buf_is_valid(b) then
          pcall(vim.api.nvim_buf_delete, b, { force = true })
        end
      end
    end,
  }
end

-- Modified-file discovery shared with <leader>lm and <leader>sm
-- (core/ticket.lua), so scan and picker operate on the same set.
local function open_git_modified()
  local paths = require('custom.core.ticket').modified_files()
  if not paths then
    return
  end
  if #paths == 0 then
    vim.notify('No modified files', vim.log.levels.INFO)
    return
  end
  scan_files(paths, {
    qf_title = 'Modified: diagnostics',
    qf_label = 'Modified',
    augroup_name = 'GitModifiedScan',
    empty_message = 'No readable modified files',
  })
end

-- Ticket-scoped scan: same commit discovery as <leader>dT and <leader>lT
-- (shared via core/ticket.lua) — but instead of opening a diffview it scans
-- the union of files touched by exactly the matched commits and dumps their
-- diagnostics into the quickfix.
local function open_ticket_scan()
  if require('custom.core.scan_runner').is_active() then
    vim.notify('A scan is already running', vim.log.levels.WARN)
    return
  end

  local ticket = require 'custom.core.ticket'
  ticket.prompt_commits(function(ctx)
    local paths = ticket.commit_files(ctx)
    if not paths then
      return
    end

    vim.notify(#ctx.commits .. ' commit(s) matching "' .. ctx.input .. '", ' .. #paths .. ' file(s)', vim.log.levels.INFO)
    scan_files(paths, {
      qf_title = 'Ticket: diagnostics',
      qf_label = 'Ticket',
      augroup_name = 'GitTicketScan',
      empty_message = 'No readable files in matching commits',
    })
  end)
end

-- Diagnostics into native lists. Explicit titles let `build.lua`'s
-- `setup_auto_clear` predicate (`^(%w+):` against `AUTO_CLEAR_KINDS`)
-- match these lists and prune resolved entries on DiagnosticChanged.
-- We bypass `vim.diagnostic.setqflist` so we can route through
-- `scan_runner.diag_to_item`, which prefixes text with `[source]` (the
-- originating LSP). The same prefix is used by the auto-clear's
-- (lnum, text) match so pruning stays accurate.
local function diags_to_items(diagnostics)
  local scan_runner = require 'custom.core.scan_runner'
  local items = {}
  for _, d in ipairs(diagnostics) do
    -- Drop SCAN_IGNORED_CODES phantoms from buffers not shown in any
    -- window: hidden buffers only ever got the reduced-pass pull, and
    -- with no window they never get the full pass that self-corrects
    -- in-editor — they'd sit in the live list indefinitely. Displayed
    -- buffers keep theirs (the full pass has run; entries are real).
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

  vim.keymap.set('n', '<leader>xm', open_git_modified, { desc = 'Git [M]odified → diagnostics qf' })
  vim.keymap.set('n', '<leader>xT', open_ticket_scan, { desc = 'Git [T]icket commits → diagnostics qf' })

  vim.api.nvim_create_user_command('GitModified', open_git_modified, { desc = 'Open git-modified files and dump diagnostics to quickfix' })
  vim.api.nvim_create_user_command('TicketScan', open_ticket_scan, { desc = 'Scan files from ticket-matching commits and dump diagnostics to quickfix' })

  -- Wrap every roslyn client at attach so `workspace/projectInitializationComplete`
  -- is observed even on warm-start scans (the notification only fires once per
  -- client lifetime — by the time the user runs <leader>xm later, the wrap
  -- needs to already exist for `__git_modified_init_done` to be trustworthy).
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('GitModifiedRoslynWrap', { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == 'roslyn' then
        wrap_roslyn(client)
      end
    end,
  })
end

return M
