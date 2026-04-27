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
local function bracketed_qf(direction)
  return function()
    if vim.tbl_isempty(vim.fn.getqflist()) then
      vim.notify('Quickfix list is empty', vim.log.levels.WARN)
      return
    end
    vim.cmd(string.format([[silent! lua require('mini.bracketed').quickfix(%q)]], direction))
  end
end

local function bracketed_loc(direction)
  return function()
    if vim.tbl_isempty(vim.fn.getloclist(0)) then
      vim.notify('Location list is empty', vim.log.levels.WARN)
      return
    end
    vim.cmd(string.format([[silent! lua require('mini.bracketed').location(%q)]], direction))
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
-- need an explicit pull via `textDocument/diagnostic`. We hook LspAttach for
-- the modified bufnrs and trigger a pull once the client has had a chance to
-- dynamically register the diagnostic capability — same pattern roslyn.nvim
-- uses on `workspace/projectInitializationComplete`.

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

  local bufnrs = {}
  local target = {}
  for _, f in ipairs(files) do
    local bufnr = vim.fn.bufadd(vim.fn.fnamemodify(f, ':p'))
    pcall(vim.fn.bufload, bufnr)
    table.insert(bufnrs, bufnr)
    target[bufnr] = true
  end

  -- Already-attached clients (e.g. a buffer the user had visited earlier).
  for _, bufnr in ipairs(bufnrs) do
    pull_diagnostics(bufnr)
  end

  -- Late-attaching clients (roslyn most often) — defer the pull so dynamic
  -- capability registration can complete before we issue the request.
  local pull_group = vim.api.nvim_create_augroup('GitModifiedScanPull', { clear = true })
  vim.api.nvim_create_autocmd('LspAttach', {
    group = pull_group,
    callback = function(args)
      if not target[args.buf] then
        return
      end
      vim.defer_fn(function()
        pull_diagnostics(args.buf)
      end, 500)
    end,
  })

  vim.notify('Scanning ' .. #files .. ' modified file(s)…', vim.log.levels.INFO)

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
  -- Dashboard escape is handled globally in autocmds.lua (FileType qf autocmd)
  vim.keymap.set('n', '<leader>xq', toggle_quickfix, { desc = '[Q]uickfix list toggle' })
  vim.keymap.set('n', '<leader>xl', toggle_loclist, { desc = '[L]ocation list toggle' })

  -- Diagnostics into native lists
  vim.keymap.set('n', '<leader>xx', function()
    vim.diagnostic.setqflist()
  end, { desc = 'All [D]iagnostics to quickfix' })
  vim.keymap.set('n', '<leader>xX', function()
    vim.diagnostic.setloclist()
  end, { desc = 'Buffer diagnostics to loclist' })

  vim.keymap.set('n', ']q', bracketed_qf 'forward', { desc = 'Next quickfix entry' })
  vim.keymap.set('n', '[q', bracketed_qf 'backward', { desc = 'Previous quickfix entry' })
  vim.keymap.set('n', ']l', bracketed_loc 'forward', { desc = 'Next location entry' })
  vim.keymap.set('n', '[l', bracketed_loc 'backward', { desc = 'Previous location entry' })

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
end

return M
