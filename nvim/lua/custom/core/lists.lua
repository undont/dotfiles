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

local modified_scan = { active = false }

local function clear_modified_timer(name)
  if modified_scan[name] then
    pcall(function()
      modified_scan[name]:stop()
      modified_scan[name]:close()
    end)
    modified_scan[name] = nil
  end
end

local function finalise_modified_scan()
  clear_modified_timer 'debounce'
  clear_modified_timer 'hard_timeout'
  if modified_scan.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, modified_scan.augroup)
    modified_scan.augroup = nil
  end

  local items = {}
  for _, bufnr in ipairs(modified_scan.bufnrs or {}) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local fname = vim.api.nvim_buf_get_name(bufnr)
      local entries = vim.diagnostic.toqflist(vim.diagnostic.get(bufnr))
      for _, item in ipairs(entries) do
        if fname ~= '' then
          item.filename = fname
        end
        item.bufnr = nil
      end
      vim.list_extend(items, entries)
    end
  end

  vim.fn.setqflist({}, 'r', { title = modified_scan.title, items = items })
  local label = modified_scan.label
  modified_scan.active = false

  if #items > 0 then
    vim.notify(label .. ': ' .. #items .. ' diagnostic(s)', vim.log.levels.WARN)
    vim.cmd 'botright copen'
  else
    vim.notify(label .. ': clean', vim.log.levels.INFO)
  end
end

local function reset_modified_debounce()
  clear_modified_timer 'debounce'
  modified_scan.debounce = vim.uv.new_timer()
  modified_scan.debounce:start(modified_scan.debounce_ms, 0, vim.schedule_wrap(finalise_modified_scan))
end

local function open_git_modified(opts)
  if modified_scan.active then
    vim.notify('Modified-scan already running', vim.log.levels.WARN)
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

  local bufnrs, watched = {}, {}
  for _, f in ipairs(files) do
    local bufnr = vim.fn.bufadd(vim.fn.fnamemodify(f, ':p'))
    pcall(vim.fn.bufload, bufnr)
    table.insert(bufnrs, bufnr)
    watched[bufnr] = true
  end

  modified_scan.active = true
  modified_scan.bufnrs = bufnrs
  modified_scan.title = title
  modified_scan.label = label
  modified_scan.debounce_ms = debounce_ms
  modified_scan.augroup = vim.api.nvim_create_augroup('GitModifiedScan', { clear = true })
  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = modified_scan.augroup,
    callback = function(args)
      if modified_scan.active and watched[args.buf] then
        reset_modified_debounce()
      end
    end,
  })

  vim.notify('Scanning ' .. #files .. ' ' .. note .. '…', vim.log.levels.INFO)
  reset_modified_debounce()
  modified_scan.hard_timeout = vim.uv.new_timer()
  modified_scan.hard_timeout:start(
    hard_timeout_ms,
    0,
    vim.schedule_wrap(function()
      if modified_scan.active then
        finalise_modified_scan()
      end
    end)
  )
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
