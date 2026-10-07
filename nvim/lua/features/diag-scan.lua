-- git-scoped diagnostics → quickfix scanner. hidden-loads a changeset in
-- bounded batches so LSPs attach, snapshots the resulting diagnostics, and
-- merges them into a titled quickfix without switching the current buffer

local M = {}

local scan_runner = require 'features.scan-runner'

-- roslyn only pushes diagnostics for visible documents, so scanned buffers
-- need a `textDocument/diagnostic` pull. a pull before its workspace
-- initialises returns -30099, so its `workspace/projectInitializationComplete`
-- handler is wrapped and the pull runs from inside the wrap. the coupling is to
-- the LSP method name, not roslyn.nvim's `User RoslynInitialized` autocmd
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

-- idempotent. installed at LspAttach (see setup) so it precedes the
-- notification, which keeps `__git_modified_init_done` valid for later scans
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

local function on_roslyn_ready(client, on_ready)
  wrap_roslyn(client)
  if client.__git_modified_init_done then
    pcall(on_ready)
  else
    table.insert(client.__git_modified_init_cbs, on_ready)
  end
end

-- C#-family buffers pull after roslyn's project-init notification; when roslyn
-- hasn't attached, the LspAttach handler in scan_files does the pull. the
-- validity guard covers that handler's deferred call, which can run after the
-- scan deleted its buffers (vim.bo on a deleted buffer throws)
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

-- codes dropped from scan snapshots, not from in-editor diagnostics. roslyn's
-- pull for a hidden-loaded buffer runs a reduced pass and reports these falsely
-- (dotnet/roslyn#47288, #75887): IDE0079 needs the suppressed analyzer to run,
-- IDE0005 needs full reference resolution. opening the file runs the full pass
-- and clears them. lists.lua's diags_to_items applies the same filter to
-- buffers shown in no window
local SCAN_IGNORED_CODES = { IDE0079 = true, IDE0005 = true }

-- `code` arrives as a string, a number, or only inside the raw LSP diagnostic
-- (`user_data.lsp.code`) depending on the producer. shared with lists.lua
function M.scan_ignored(d)
  local code = d.code
  if code == nil and d.user_data and d.user_data.lsp then
    code = d.user_data.lsp.code
  end
  return code ~= nil and SCAN_IGNORED_CODES[tostring(code)] == true
end

-- the same filtering as lists.lua's diags_to_items: scan-ignored codes,
-- library/dependency code and generated code are dropped
local function scan_diagnostics(bufnr)
  return vim.tbl_filter(function(d)
    return not M.scan_ignored(d) and not scan_runner.in_library(d) and not scan_runner.is_generated(d)
  end, vim.diagnostic.get(bufnr))
end

-- files hidden-loaded at once. roslyn's analyzer scope is `openFiles`, so its
-- peak memory follows the open .cs count; each chunk's created buffers are
-- deleted (sending `didClose`) before the next chunk loads. the solution stays
-- loaded across chunks. a larger value trades peak memory for fewer chunks
local SCAN_BATCH_SIZE = 12

-- a multi-batch scan leaves scan_runner momentarily inactive between chunks, so
-- scan_runner.is_active() alone can't guard re-entry; this owns the
-- whole-operation lock
local scanning = false

local function scan_in_progress()
  return scanning or require('features.scan-runner').is_active()
end

--- `created` is the subset of bufnrs this call created, deleted after the
--- snapshot; `target` is the lookup for the per-batch pull autocmd
--- @param paths string[]
--- @return integer[] bufnrs, integer[] created, table<integer, boolean> target
local function load_batch(paths)
  local bufnrs = {}
  local created = {}
  local target = {}
  for _, abs in ipairs(paths) do
    local existed = vim.fn.bufnr(abs) ~= -1
    local bufnr = vim.fn.bufadd(abs)
    pcall(vim.fn.bufload, bufnr)
    -- bufload doesn't reliably run filetype detection for hidden buffers.
    -- sonarlint's FileType attach, pull_gated's ROSLYN_FTS gate and the qf
    -- [source] fallback label all need the filetype (same as sonar-scan.lua)
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
  return bufnrs, created, target
end

--- driver behind <leader>xm / xb / xT / xS: loads the paths in batches (see
--- SCAN_BATCH_SIZE), snapshots each batch via scan_runner and merges the items
--- into one titled quickfix
--- @param paths string[] absolute paths
--- @param opts { qf_title: string, qf_label: string, augroup_name: string, empty_message: string }
local function scan_files(paths, opts)
  if scan_in_progress() then
    vim.notify('A scan is already running', vim.log.levels.WARN)
    return
  end

  -- sources can name files that are gone from disk (ticket commits may touch
  -- since-deleted files), and a buffer for a missing file makes easy-dotnet's
  -- BootstrapFile fail with -32000
  local readable = {}
  for _, abs in ipairs(paths) do
    if vim.fn.filereadable(abs) == 1 then
      table.insert(readable, abs)
    end
  end
  if #readable == 0 then
    vim.notify(opts.empty_message, vim.log.levels.INFO)
    return
  end

  local batches = {}
  for i = 1, #readable, SCAN_BATCH_SIZE do
    local chunk = {}
    for j = i, math.min(i + SCAN_BATCH_SIZE - 1, #readable) do
      table.insert(chunk, readable[j])
    end
    table.insert(batches, chunk)
  end

  -- counts across the whole run, not per batch. falls back to a plain notify
  local fidget_ok, fidget = pcall(require, 'fidget.progress')
  local progress = fidget_ok
      and fidget.handle.create {
        title = opts.qf_label,
        message = 'scanning ' .. #readable .. ' file(s) in ' .. #batches .. ' batch(es)',
        lsp_client = { name = opts.qf_label:lower() .. '-scan' },
      }
    or nil
  if not progress then
    vim.notify('Scanning ' .. #readable .. ' file(s) in ' .. #batches .. ' batch(es)…', vim.log.levels.INFO)
  end

  scanning = true
  local all_items = {}
  local scanned = 0

  local function finish_all()
    scanning = false
    if progress then
      pcall(function()
        progress:finish()
      end)
    end
    vim.fn.setqflist({}, 'r', { title = opts.qf_title, items = all_items })
    if #all_items > 0 then
      vim.notify(opts.qf_label .. ': ' .. #all_items .. ' issue(s)', vim.log.levels.WARN)
      vim.cmd 'botright copen'
    else
      vim.notify(opts.qf_label .. ': clean', vim.log.levels.INFO)
    end
  end

  local run_batch
  run_batch = function(idx)
    local chunk = batches[idx]
    if not chunk then
      finish_all()
      return
    end

    local bufnrs, created, target = load_batch(chunk)

    -- clients already attached (roslyn stays attached across batches)
    for _, bufnr in ipairs(bufnrs) do
      pull_gated(bufnr)
    end

    -- clients attaching during this batch: sonarlint via filetype lazy-load,
    -- roslyn via autostart on the first batch. other clients get a defer so
    -- dynamic capability registration settles
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

    local started = scan_runner.start {
      bufnrs = bufnrs,
      get_diagnostics = scan_diagnostics,
      debounce_ms = 5000,
      -- used once every watched buffer has reported
      settled_debounce_ms = 500,
      -- ...unless sonarlint is attached to a scanned buffer: its java analyzers
      -- publish later than the buffer's first report, which debounce_ms covers
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
      on_report = progress and function(reported)
        progress:report { message = (scanned + reported) .. '/' .. #readable .. ' file(s) reported' }
      end or nil,
      on_complete = function(items)
        pcall(vim.api.nvim_del_augroup_by_id, pull_group)
        for _, item in ipairs(items) do
          table.insert(all_items, item)
        end
        for _, b in ipairs(created) do
          if vim.api.nvim_buf_is_valid(b) then
            pcall(vim.api.nvim_buf_delete, b, { force = true })
          end
        end
        scanned = scanned + #chunk
        if progress then
          pcall(function()
            progress:report { message = scanned .. '/' .. #readable .. ' file(s) scanned' }
          end)
        end
        -- deferred so roslyn processes this chunk's didClose before the next
        -- chunk's didOpen
        vim.schedule(function()
          run_batch(idx + 1)
        end)
      end,
    }

    -- the runner is idle between batches, so this is a safeguard: release the
    -- chunk's buffers and finish with the items so far
    if not started then
      pcall(vim.api.nvim_del_augroup_by_id, pull_group)
      for _, b in ipairs(created) do
        if vim.api.nvim_buf_is_valid(b) then
          pcall(vim.api.nvim_buf_delete, b, { force = true })
        end
      end
      vim.notify('Scan aborted: runner busy', vim.log.levels.WARN)
      finish_all()
    end
  end

  run_batch(1)
end

-- modified-file discovery shared with <leader>lm and <leader>sm
-- (features/ticket.lua), so scan and picker operate on the same set
local function open_git_modified()
  local paths = require('features.ticket').modified_files()
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

-- every file changed on the branch vs main, the same merge-base discovery as
-- <leader>dt (features/ticket.lua)
local function open_branch_scan()
  local paths = require('features.ticket').branch_files()
  if not paths then
    return
  end
  if #paths == 0 then
    vim.notify('No files changed vs main', vim.log.levels.INFO)
    return
  end
  scan_files(paths, {
    qf_title = 'Branch: diagnostics',
    qf_label = 'Branch',
    augroup_name = 'GitBranchScan',
    empty_message = 'No readable files changed vs main',
  })
end

-- every tracked-or-untracked file. the set is unbounded, so a confirm guards
-- runs above PROJECT_SCAN_CAP
local PROJECT_SCAN_CAP = 500

local function project_files()
  local cwd = vim.fn.getcwd()
  local result = vim.system({ 'git', 'ls-files', '-co', '--exclude-standard' }, { text = true, cwd = cwd }):wait()
  if result.code ~= 0 then
    return nil
  end
  local paths = {}
  for line in (result.stdout or ''):gmatch '[^\r\n]+' do
    table.insert(paths, cwd .. '/' .. line)
  end
  return paths
end

local function open_project_scan()
  local paths = project_files()
  if not paths then
    vim.notify('Not a git repository', vim.log.levels.WARN)
    return
  end
  if #paths == 0 then
    vim.notify('No files in project', vim.log.levels.INFO)
    return
  end

  local function go()
    scan_files(paths, {
      qf_title = 'Project: diagnostics',
      qf_label = 'Project',
      augroup_name = 'GitProjectScan',
      empty_message = 'No readable project files',
    })
  end

  if #paths > PROJECT_SCAN_CAP then
    vim.ui.select({ 'Yes', 'No' }, {
      prompt = 'Scan ' .. #paths .. ' files (>' .. PROJECT_SCAN_CAP .. ')?',
    }, function(choice)
      if choice == 'Yes' then
        go()
      end
    end)
  else
    go()
  end
end

-- the union of files touched by the matched commits, the same commit
-- discovery as <leader>dT and <leader>lT (features/ticket.lua)
local function open_ticket_scan()
  if scan_in_progress() then
    vim.notify('A scan is already running', vim.log.levels.WARN)
    return
  end

  local ticket = require 'features.ticket'
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

function M.setup()
  vim.keymap.set('n', '<leader>xm', open_git_modified, { desc = 'Git [M]odified → diagnostics qf' })
  vim.keymap.set('n', '<leader>xb', open_branch_scan, { desc = '[B]ranch vs main → diagnostics qf' })
  vim.keymap.set('n', '<leader>xT', open_ticket_scan, { desc = 'Git [T]icket commits → diagnostics qf' })
  vim.keymap.set('n', '<leader>xS', open_project_scan, { desc = 'Whole project [S]can → diagnostics qf' })

  vim.api.nvim_create_user_command('GitModified', open_git_modified, { desc = 'Open git-modified files and dump diagnostics to quickfix' })
  vim.api.nvim_create_user_command('BranchScan', open_branch_scan, { desc = 'Scan all files changed vs main and dump diagnostics to quickfix' })
  vim.api.nvim_create_user_command('TicketScan', open_ticket_scan, { desc = 'Scan files from ticket-matching commits and dump diagnostics to quickfix' })
  vim.api.nvim_create_user_command('ProjectScan', open_project_scan, { desc = 'Scan every project file and dump diagnostics to quickfix' })

  -- `workspace/projectInitializationComplete` fires once per client lifetime,
  -- so every roslyn client is wrapped at attach, before any scan runs
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
