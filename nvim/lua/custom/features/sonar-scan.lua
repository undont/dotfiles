-- SonarLint project scan. SonarLint only analyses opened buffers, so scannable
-- files are hidden-loaded, their diagnostics snapshotted into the quickfix via
-- features/scan-runner, and the created buffers unloaded.
-- <leader>lm / lb / lT / lS take the same file sets as <leader>xm / xb / xT /
-- xS in features/diag-scan.lua

local common = require 'custom.features.sonar-common'

local M = {}

local SCAN_FILE_CAP = 500
local SCAN_DEBOUNCE_MS = 2000
local SCAN_HARD_TIMEOUT_MS = 5 * 60 * 1000

-- extensions that map to one of common.FILETYPES, to filter `git ls-files`
-- output before opening anything
local SCAN_EXTS = {
  py = true,
  c = true,
  h = true,
  cc = true,
  cxx = true,
  cpp = true,
  hpp = true,
  hh = true,
  js = true,
  mjs = true,
  cjs = true,
  jsx = true,
  ts = true,
  mts = true,
  cts = true,
  tsx = true,
  go = true,
  cs = true,
  php = true,
  html = true,
  htm = true,
  css = true,
  scss = true,
  tf = true,
  hcl = true,
  yaml = true,
  yml = true,
  xml = true,
}

local function is_scannable_path(path)
  local ext = path:match '%.([^./]+)$'
  if ext and SCAN_EXTS[ext:lower()] then
    return true
  end
  local base = vim.fs.basename(path):lower()
  return base == 'dockerfile' or base:match '%.dockerfile$' ~= nil
end

--- nil if the command failed (e.g. not in a git repo)
local function git_lines(args, cwd)
  local result = vim.system(args, { text = true, cwd = cwd }):wait()
  if result.code ~= 0 then
    return nil
  end
  local lines = {}
  for line in (result.stdout or ''):gmatch '[^\r\n]+' do
    table.insert(lines, line)
  end
  return lines
end

--- @param paths string[] absolute paths
local function scannable(paths)
  local files = {}
  for _, abs in ipairs(paths) do
    if is_scannable_path(abs) and vim.fn.filereadable(abs) == 1 then
      table.insert(files, abs)
    end
  end
  return files
end

--- @param mode 'changed' | 'branch' | 'all'
local function list_scan_targets(mode)
  if mode == 'changed' then
    -- same file set as <leader>xm / <leader>sm (features/ticket.lua). nil
    -- (already notified) outside a git repo
    local paths = require('custom.features.ticket').modified_files()
    return paths and scannable(paths) or nil
  end

  if mode == 'branch' then
    -- every file changed vs merge-base(main), same set as <leader>xb
    local paths = require('custom.features.ticket').branch_files()
    return paths and scannable(paths) or nil
  end

  local cwd = vim.fn.getcwd()
  local raw = git_lines({ 'git', 'ls-files', '-co', '--exclude-standard' }, cwd)
  if not raw then
    raw = vim.fs.find(function(name, _)
      return is_scannable_path(name)
    end, { type = 'file', limit = math.huge, path = cwd })
    local prefix = cwd .. '/'
    for i, p in ipairs(raw) do
      raw[i] = (p:sub(1, #prefix) == prefix) and p:sub(#prefix + 1) or p
    end
  end

  local abs = {}
  for _, rel in ipairs(raw) do
    table.insert(abs, cwd .. '/' .. rel)
  end
  return scannable(abs)
end

--- `label` is shown in the fidget message
local function start_scan(files, label)
  -- buffers created here, the only ones unloaded in on_finalise
  local created = {}
  for _, path in ipairs(files) do
    local existed = vim.fn.bufnr(path) ~= -1
    local bufnr = vim.fn.bufadd(path)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      pcall(vim.fn.bufload, bufnr)
      local ft = vim.filetype.match { buf = bufnr, filename = path }
      if ft then
        vim.bo[bufnr].filetype = ft
      end
    end
    if not existed then
      table.insert(created, bufnr)
    end
  end

  -- pre-existing sonarlint buffers go into the qf but don't drive the debounce
  local extra = {}
  for _, client in ipairs(vim.lsp.get_clients { name = common.SONARLINT_CLIENT_NAME }) do
    for bufnr, _ in pairs(client.attached_buffers or {}) do
      table.insert(extra, bufnr)
    end
  end

  local ok, fidget = pcall(require, 'fidget.progress')
  local progress = ok
      and fidget.handle.create {
        title = 'SonarLint',
        message = 'scanning ' .. #files .. ' ' .. label .. ' file(s)',
        lsp_client = { name = 'sonar-scan' },
      }
    or nil

  local watched = {}
  for _, b in ipairs(created) do
    table.insert(watched, b)
  end
  -- already-loaded buffers from `files` are watched too; they aren't in
  -- `created`
  for _, path in ipairs(files) do
    local b = vim.fn.bufnr(path)
    if b ~= -1 then
      table.insert(watched, b)
    end
  end

  local collect = vim.list_extend(vim.list_extend({}, watched), extra)

  require('custom.features.scan-runner').start {
    bufnrs = watched,
    collect_bufnrs = collect,
    get_diagnostics = common.sonarlint_diagnostics,
    debounce_ms = SCAN_DEBOUNCE_MS,
    hard_timeout_ms = SCAN_HARD_TIMEOUT_MS,
    qf_title = 'Sonar: scan',
    qf_label = 'Sonar scan',
    augroup_name = 'SonarlintScan',
    progress = progress,
    hard_timeout_message = 'Sonar scan: hit ' .. (SCAN_HARD_TIMEOUT_MS / 60000) .. 'min hard timeout',
    on_finalise = function()
      for _, b in ipairs(created) do
        if vim.api.nvim_buf_is_valid(b) then
          pcall(vim.api.nvim_buf_delete, b, { force = true })
        end
      end
    end,
  }
end

--- @param mode 'changed' | 'branch' | 'ticket' | 'all'
function M.run_scan(mode)
  if require('custom.features.scan-runner').is_active() then
    vim.notify('A scan is already running', vim.log.levels.WARN)
    return
  end

  -- ticket mode resolves its file list asynchronously: same commit
  -- discovery as <leader>dT / <leader>xT (features/ticket.lua), filtered to
  -- sonarlint-scannable files
  if mode == 'ticket' then
    local ticket = require 'custom.features.ticket'
    ticket.prompt_commits(function(ctx)
      local paths = ticket.commit_files(ctx)
      if not paths then
        return
      end
      local files = scannable(paths)
      if #files == 0 then
        vim.notify('No sonarlint-scannable files in matching commits', vim.log.levels.INFO)
        return
      end
      vim.notify(#ctx.commits .. ' commit(s) matching "' .. ctx.input .. '", ' .. #files .. ' scannable file(s)', vim.log.levels.INFO)
      start_scan(files, 'ticket')
    end)
    return
  end

  local files = list_scan_targets(mode)
  if not files then
    return -- not a git repo, modified_files already notified
  end
  if #files == 0 then
    local msg = ({
      changed = 'No changed sonarlint-scannable files',
      branch = 'No sonarlint-scannable files changed vs main',
      all = 'No sonarlint-scannable files in ' .. vim.fn.getcwd(),
    })[mode]
    vim.notify(msg, vim.log.levels.INFO)
    return
  end

  local label = ({ changed = 'changed', branch = 'branch', all = 'project' })[mode]

  -- the other modes are bounded by their changeset
  if mode == 'all' and #files > SCAN_FILE_CAP then
    vim.ui.select({ 'Yes', 'No' }, {
      prompt = 'Scan ' .. #files .. ' files (>' .. SCAN_FILE_CAP .. ')?',
    }, function(choice)
      if choice == 'Yes' then
        start_scan(files, label)
      end
    end)
  else
    start_scan(files, label)
  end
end

return M
