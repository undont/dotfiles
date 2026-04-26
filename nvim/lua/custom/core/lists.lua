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

-- Open all git-modified (unstaged) and untracked files into the arglist, then
-- wait for LSPs to analyse them and dump the resulting diagnostics into the
-- quickfix list. Debounces on DiagnosticChanged so late-arriving LSPs are
-- captured; falls through after a hard timeout if nothing publishes.
--
-- Two presets:
--   <leader>xm — fast (2s debounce / 30s timeout) for native LSPs
--   <leader>xM — slow (5s debounce / 5min timeout) so sonarlint's java
--                analyzers have time to finish (sonar auto-attaches on
--                bufload via the plugin's `ft` lazy-load, so its
--                diagnostics show up in vim.diagnostic.get without an
--                explicit scan trigger).

local function open_git_modified(opts)
  local scan_runner = require 'custom.core.scan_runner'
  if scan_runner.is_active() then
    vim.notify('A scan is already running', vim.log.levels.WARN)
    return
  end
  opts = opts or {}
  local debounce_ms = opts.debounce_ms or 2000
  local hard_timeout_ms = opts.hard_timeout_ms or 30 * 1000
  local title = opts.title or 'Modified: diagnostics'
  local label = opts.label or 'Modified'
  local note = opts.note or 'modified file(s)'

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

  local escaped = {}
  for _, f in ipairs(files) do
    table.insert(escaped, vim.fn.fnameescape(f))
  end
  vim.cmd('args ' .. table.concat(escaped, ' '))

  local bufnrs = {}
  for _, f in ipairs(files) do
    local bufnr = vim.fn.bufadd(vim.fn.fnamemodify(f, ':p'))
    pcall(vim.fn.bufload, bufnr)
    table.insert(bufnrs, bufnr)
  end

  vim.notify('Scanning ' .. #files .. ' ' .. note .. '…', vim.log.levels.INFO)

  scan_runner.start {
    bufnrs = bufnrs,
    debounce_ms = debounce_ms,
    hard_timeout_ms = hard_timeout_ms,
    qf_title = title,
    qf_label = label,
    augroup_name = 'GitModifiedScan',
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

  vim.keymap.set('n', '<leader>xm', function()
    open_git_modified()
  end, { desc = 'Git [M]odified → diagnostics qf' })

  vim.keymap.set('n', '<leader>xM', function()
    open_git_modified {
      debounce_ms = 5000,
      hard_timeout_ms = 5 * 60 * 1000,
      title = 'Modified+Sonar: diagnostics',
      label = 'Modified+Sonar',
      note = 'modified file(s) (incl. sonar)',
    }
  end, { desc = 'Git [M]odified → diagnostics qf (incl. sonar)' })

  vim.api.nvim_create_user_command('GitModified', function()
    open_git_modified()
  end, { desc = 'Open git-modified files and dump diagnostics to quickfix' })
end

return M
