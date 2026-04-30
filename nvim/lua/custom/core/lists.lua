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
local function sync_qf_idx_to_cursor(get_list, set_idx)
  if vim.bo.buftype == 'quickfix' then
    set_idx(vim.api.nvim_win_get_cursor(0)[1])
    return
  end
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  for i, entry in ipairs(get_list()) do
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
      if vim.tbl_isempty(vim.fn.getqflist()) then
        vim.notify('Quickfix list is empty', vim.log.levels.WARN)
        return
      end
      sync_qf_idx_to_cursor(vim.fn.getqflist, function(idx)
        vim.fn.setqflist({}, 'a', { idx = idx })
      end)
      vim.cmd(string.format([[silent! lua require('mini.bracketed').quickfix(%q)]], direction))
    end)
  end
end

local function bracketed_loc(direction)
  return function()
    with_list_nav_win(function()
      if vim.tbl_isempty(vim.fn.getloclist(0)) then
        vim.notify('Location list is empty', vim.log.levels.WARN)
        return
      end
      sync_qf_idx_to_cursor(function()
        return vim.fn.getloclist(0)
      end, function(idx)
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
-- analyzers (which auto-attach via the plugin's `ft` lazy-load on bufload).
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
local function pull_gated(bufnr)
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

local function open_git_modified()
  local scan_runner = require 'custom.core.scan_runner'
  if scan_runner.is_active() then
    vim.notify('A scan is already running', vim.log.levels.WARN)
    return
  end

  local result = vim.system({ 'git', 'ls-files', '-m', '-o', '--exclude-standard' }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify('Not a git repo', vim.log.levels.WARN)
    return
  end
  local files = {}
  for line in (result.stdout or ''):gmatch '[^\r\n]+' do
    table.insert(files, line)
  end
  if #files == 0 then
    vim.notify('No modified files', vim.log.levels.INFO)
    return
  end

  -- Skip paths that don't exist on disk: `git ls-files -m` includes
  -- deleted-but-unstaged entries, and creating buffers for missing files
  -- triggers easy-dotnet's BootstrapFile to walk a missing directory and
  -- crash with -32000.
  local bufnrs = {}
  local target = {}
  for _, f in ipairs(files) do
    local abs = vim.fn.fnamemodify(f, ':p')
    if vim.fn.filereadable(abs) == 1 then
      local bufnr = vim.fn.bufadd(abs)
      pcall(vim.fn.bufload, bufnr)
      table.insert(bufnrs, bufnr)
      target[bufnr] = true
    end
  end
  if #bufnrs == 0 then
    vim.notify('No readable modified files', vim.log.levels.INFO)
    return
  end

  -- Already-attached clients (e.g. a buffer the user had visited earlier).
  for _, bufnr in ipairs(bufnrs) do
    pull_gated(bufnr)
  end

  -- Late-attaching clients — sonarlint via filetype lazy-load, roslyn via
  -- file-association autostart. Roslyn pulls go through the init-gate; other
  -- clients get a small defer so dynamic capability registration can settle.
  local pull_group = vim.api.nvim_create_augroup('GitModifiedScanPull', { clear = true })
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

  vim.notify('Scanning ' .. #bufnrs .. ' modified file(s)…', vim.log.levels.INFO)

  scan_runner.start {
    bufnrs = bufnrs,
    debounce_ms = 5000,
    hard_timeout_ms = 5 * 60 * 1000,
    qf_title = 'Modified: diagnostics',
    qf_label = 'Modified',
    augroup_name = 'GitModifiedScan',
    on_finalise = function()
      pcall(vim.api.nvim_del_augroup_by_id, pull_group)
    end,
  }
end

function M.setup()
  -- Built-in filter plugin: :Cfilter /pat/ keeps matching qf entries,
  -- :Cfilter! /pat/ drops them. Same for :Lfilter on loclists.
  vim.cmd 'packadd cfilter'

  -- Dashboard escape is handled globally in autocmds.lua (FileType qf autocmd)
  vim.keymap.set('n', '<leader>xq', toggle_quickfix, { desc = '[Q]uickfix list toggle' })
  vim.keymap.set('n', '<leader>xl', toggle_loclist, { desc = '[L]ocation list toggle' })

  -- Diagnostics into native lists. Explicit titles let `build.lua`'s
  -- `setup_auto_clear` predicate (`^(%w+):` against `AUTO_CLEAR_KINDS`)
  -- match these lists and prune resolved entries on DiagnosticChanged.
  vim.keymap.set('n', '<leader>xx', function()
    vim.diagnostic.setqflist { title = 'Diagnostics: all' }
  end, { desc = 'All [D]iagnostics to quickfix' })
  vim.keymap.set('n', '<leader>xX', function()
    vim.diagnostic.setloclist { title = 'Diagnostics: buffer' }
  end, { desc = 'Buffer diagnostics to loclist' })

  vim.keymap.set('n', ']q', bracketed_qf 'forward', { desc = 'Next quickfix entry' })
  vim.keymap.set('n', '[q', bracketed_qf 'backward', { desc = 'Previous quickfix entry' })
  vim.keymap.set('n', ']l', bracketed_loc 'forward', { desc = 'Next location entry' })
  vim.keymap.set('n', '[l', bracketed_loc 'backward', { desc = 'Previous location entry' })

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

  vim.api.nvim_create_user_command('GitModified', open_git_modified, { desc = 'Open git-modified files and dump diagnostics to quickfix' })

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
