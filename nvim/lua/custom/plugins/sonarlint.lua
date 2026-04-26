-- SonarLint diagnostics via the official sonarlint-language-server.
-- https://gitlab.com/schrieveslaach/sonarlint.nvim
--
-- Connected mode (SonarCloud) is enabled when both SONARQUBE_TOKEN and
-- SONARQUBE_ORG are present in the environment (typically sourced from
-- ~/.config/zsh/secrets.zsh). Without them the plugin still loads in
-- local-only mode -- you just lose server-side rule profile overrides.
--
-- Per-project binding uses the standard `.sonarlint/connectedMode.json`
-- convention shared with the JetBrains/VSCode "SonarQube for IDE" plugins:
--   { "projectKey": "my-org_my-project" }

local CONNECTION_ID = 'sonarcloud'
local CONNECTED_MODE_FILE = '.sonarlint/connectedMode.json'

--- Read `.sonarlint/connectedMode.json` from a project root and return its
--- `projectKey`, or nil if the file is missing or malformed.
local function read_project_key(root)
  if not root or root == '' then
    return nil
  end
  local path = root .. '/' .. CONNECTED_MODE_FILE
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  local ok, content = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  local decoded
  ok, decoded = pcall(vim.json.decode, table.concat(content, '\n'))
  if not ok or type(decoded) ~= 'table' then
    return nil
  end
  return decoded.projectKey
end

--- Build the analyzer jar list, filtering out any that aren't on disk so a
--- partial Mason install doesn't make the language server fail to start.
local function analyzer_jars()
  local dir = vim.fn.expand '$MASON/share/sonarlint-analyzers'
  local candidates = {
    'sonarpython.jar',
    'sonarcfamily.jar', -- C / C++
    'sonarjs.jar', -- JavaScript / TypeScript
    'sonargo.jar',
    'sonarcsharp.jar',
    'sonarphp.jar',
    'sonarhtml.jar', -- HTML + CSS
    'sonariac.jar', -- Terraform, Kubernetes, Docker, CloudFormation
    'sonartext.jar', -- text + secrets
    'sonarxml.jar',
  }
  local jars = {}
  for _, name in ipairs(candidates) do
    local path = dir .. '/' .. name
    if vim.fn.filereadable(path) == 1 then
      table.insert(jars, path)
    end
  end
  return jars
end

local FILETYPES = {
  'cs',
  'dockerfile',
  'python',
  'cpp',
  'c',
  'javascript',
  'javascriptreact',
  'typescript',
  'typescriptreact',
  'go',
  'php',
  'html',
  'css',
  'scss',
  'terraform',
  'hcl',
  'yaml',
  'xml',
}

-- Project scan -- analogue to JetBrains' "Analyze All Project Files".
-- SonarLint only analyses opened buffers, so we walk the project, hidden-load
-- each scannable file, debounce on quiet diagnostic activity to detect "done",
-- snapshot diagnostics into quickfix, and unload the buffers we created.

local SONARLINT_CLIENT_NAME = 'sonarlint.nvim'
local SCAN_FILE_CAP = 500
local SCAN_DEBOUNCE_MS = 2000
local SCAN_HARD_TIMEOUT_MS = 5 * 60 * 1000

-- Extensions that map to one of FILETYPES above. Used to cheaply filter
-- `git ls-files` output before opening anything.
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

local scan = {
  active = false,
  created_bufs = {},
  progress = nil,
  debounce = nil,
  hard_timeout = nil,
  augroup = nil,
}

local function clear_timer(name)
  if scan[name] then
    pcall(function()
      scan[name]:stop()
      scan[name]:close()
    end)
    scan[name] = nil
  end
end

local function sonarlint_diagnostics(bufnr)
  local clients = vim.lsp.get_clients { name = SONARLINT_CLIENT_NAME }
  if #clients == 0 then
    return {}
  end
  -- Prefer namespace filter when available; fall back to source matching.
  local ok, ns = pcall(vim.lsp.diagnostic.get_namespace, clients[1].id)
  if ok and ns then
    return vim.diagnostic.get(bufnr, { namespace = ns })
  end
  return vim.tbl_filter(function(d)
    return d.source and d.source:lower():match 'sonar'
  end, vim.diagnostic.get(bufnr))
end

local function finalise_scan()
  clear_timer 'debounce'
  clear_timer 'hard_timeout'
  if scan.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, scan.augroup)
    scan.augroup = nil
  end

  -- Collect diagnostics, converting bufnr -> filename so qf entries survive
  -- the buffer-unload below. Items keyed only by bufnr would crash setqflist
  -- ("E92: Buffer N not found") once the underlying buffer is gone.
  local function collect(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return {}
    end
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local out = vim.diagnostic.toqflist(sonarlint_diagnostics(bufnr))
    for _, item in ipairs(out) do
      if fname ~= '' then
        item.filename = fname
      end
      item.bufnr = nil
    end
    return out
  end

  local items = {}
  for bufnr, _ in pairs(scan.created_bufs) do
    vim.list_extend(items, collect(bufnr))
  end
  -- Also pick up diagnostics from any pre-existing sonarlint buffers the
  -- user already had open -- a "project scan" should reflect everything
  -- sonarlint knows about.
  for _, client in ipairs(vim.lsp.get_clients { name = SONARLINT_CLIENT_NAME }) do
    for bufnr, _ in pairs(client.attached_buffers or {}) do
      if not scan.created_bufs[bufnr] then
        vim.list_extend(items, collect(bufnr))
      end
    end
  end

  for bufnr, _ in pairs(scan.created_bufs) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end
  scan.created_bufs = {}

  vim.fn.setqflist({}, 'r', { title = 'Sonar: scan', items = items })

  if scan.progress then
    pcall(function()
      scan.progress:finish()
    end)
    scan.progress = nil
  end

  scan.active = false

  if #items > 0 then
    vim.notify('Sonar scan: ' .. #items .. ' issue(s)', vim.log.levels.WARN, { title = 'SonarLint', timeout = 4000 })
    vim.cmd 'botright copen'
  else
    vim.notify('Sonar scan: clean', vim.log.levels.INFO, { title = 'SonarLint', timeout = 3000 })
  end
end

local function reset_debounce()
  clear_timer 'debounce'
  scan.debounce = vim.uv.new_timer()
  scan.debounce:start(SCAN_DEBOUNCE_MS, 0, vim.schedule_wrap(finalise_scan))
end

--- Run a git command and return its stdout split into lines.
--- Returns nil if the command failed (e.g. not in a git repo).
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

--- @param mode 'changed' | 'all'
local function list_scan_targets(mode)
  local cwd = vim.fn.getcwd()
  local raw

  if mode == 'changed' then
    -- Modified tracked files (staged + unstaged vs HEAD), excluding deletions,
    -- plus untracked files that aren't gitignored.
    local modified = git_lines({ 'git', 'diff', '--name-only', '--diff-filter=ACMR', 'HEAD' }, cwd)
    local untracked = git_lines({ 'git', 'ls-files', '--others', '--exclude-standard' }, cwd)
    if not modified and not untracked then
      vim.notify('Not a git repo — `<leader>ls` (changed-only) needs git', vim.log.levels.WARN)
      return {}
    end
    raw = {}
    local seen = {}
    for _, list in ipairs { modified or {}, untracked or {} } do
      for _, p in ipairs(list) do
        if not seen[p] then
          seen[p] = true
          table.insert(raw, p)
        end
      end
    end
  else
    raw = git_lines({ 'git', 'ls-files', '-co', '--exclude-standard' }, cwd)
    if not raw then
      raw = vim.fs.find(function(name, _)
        return is_scannable_path(name)
      end, { type = 'file', limit = math.huge, path = cwd })
      local prefix = cwd .. '/'
      for i, p in ipairs(raw) do
        raw[i] = (p:sub(1, #prefix) == prefix) and p:sub(#prefix + 1) or p
      end
    end
  end

  local files = {}
  for _, rel in ipairs(raw) do
    if is_scannable_path(rel) then
      local abs = cwd .. '/' .. rel
      if vim.fn.filereadable(abs) == 1 then
        table.insert(files, abs)
      end
    end
  end
  return files
end

local function load_files(files)
  scan.augroup = vim.api.nvim_create_augroup('SonarlintScan', { clear = true })
  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = scan.augroup,
    callback = function(args)
      if scan.active and scan.created_bufs[args.buf] then
        reset_debounce()
      end
    end,
  })

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
      scan.created_bufs[bufnr] = true
    end
  end

  reset_debounce()

  scan.hard_timeout = vim.uv.new_timer()
  scan.hard_timeout:start(
    SCAN_HARD_TIMEOUT_MS,
    0,
    vim.schedule_wrap(function()
      if scan.active then
        vim.notify('Sonar scan: hit ' .. (SCAN_HARD_TIMEOUT_MS / 60000) .. 'min hard timeout', vim.log.levels.WARN)
        finalise_scan()
      end
    end)
  )
end

--- @param mode 'changed' | 'all'
local function run_scan(mode)
  if scan.active then
    vim.notify('Sonar scan already running', vim.log.levels.WARN)
    return
  end

  local files = list_scan_targets(mode)
  if #files == 0 then
    local label = mode == 'changed' and 'No changed sonarlint-scannable files' or 'No sonarlint-scannable files in ' .. vim.fn.getcwd()
    vim.notify(label, vim.log.levels.INFO)
    return
  end

  local label = mode == 'changed' and 'changed' or 'project'

  local function proceed()
    scan.active = true
    scan.created_bufs = {}

    local ok, fidget = pcall(require, 'fidget.progress')
    if ok then
      scan.progress = fidget.handle.create {
        title = 'SonarLint',
        message = 'scanning ' .. #files .. ' ' .. label .. ' file(s)',
        lsp_client = { name = 'sonar-scan' },
      }
    end

    load_files(files)
  end

  -- Only the full-project scan asks for confirmation above the cap; the
  -- changed-files mode is naturally bounded by your working tree.
  if mode == 'all' and #files > SCAN_FILE_CAP then
    vim.ui.select({ 'Yes', 'No' }, {
      prompt = 'Scan ' .. #files .. ' files (>' .. SCAN_FILE_CAP .. ')?',
    }, function(choice)
      if choice == 'Yes' then
        proceed()
      end
    end)
  else
    proceed()
  end
end

return {
  {
    'https://gitlab.com/schrieveslaach/sonarlint.nvim',
    ft = FILETYPES,
    keys = {
      {
        '<leader>ls',
        function()
          run_scan 'changed'
        end,
        desc = 'LSP: [S]onar scan changed files',
      },
      {
        '<leader>lS',
        function()
          run_scan 'all'
        end,
        desc = 'LSP: [S]onar scan whole project',
      },
    },
    dependencies = { 'lewis6991/gitsigns.nvim' },
    config = function()
      local cmd = { 'sonarlint-language-server', '-stdio', '-analyzers' }
      vim.list_extend(cmd, analyzer_jars())

      local extension_dir = vim.fn.expand '$MASON/packages/sonarlint-language-server/extension'
      local opts = {
        server = {
          cmd = cmd,
          -- C# analysis runs through omnisharp bundled inside the sonarlint
          -- vsix -- it doesn't replace roslyn (which keeps providing the
          -- editor-facing LSP). Safe to set unconditionally; sonarlint only
          -- spawns omnisharp when actually scanning a .cs file.
          init_options = {
            omnisharpDirectory = extension_dir .. '/omnisharp',
            csharpOssPath = vim.fn.expand '$MASON/share/sonarlint-analyzers/sonarcsharp.jar',
          },
          settings = {
            sonarlint = {},
          },
        },
        filetypes = FILETYPES,
      }

      local token = vim.env.SONARQUBE_TOKEN
      local org = vim.env.SONARQUBE_ORG
      if token and token ~= '' and org and org ~= '' then
        opts.connected = {
          get_credentials = function()
            return token
          end,
        }
        opts.server.settings.sonarlint.connectedMode = {
          connections = {
            sonarcloud = {
              {
                connectionId = CONNECTION_ID,
                region = 'EU',
                organizationKey = org,
                disableNotifications = false,
              },
            },
          },
        }
        opts.server.before_init = function(params, config)
          local key = read_project_key(params.rootPath)
          if key then
            config.settings.sonarlint.connectedMode.project = {
              connectionId = CONNECTION_ID,
              projectKey = key,
            }
          end
        end

        -- Upstream bug workaround: sonarlint.nvim's `find_server_url` crashes
        -- on SonarCloud-only setups. Two issues:
        --   1. unconditionally iterates `connections.sonarqube` (nil when only
        --      sonarcloud is configured) -> bad argument to ipairs
        --   2. treats `connections.sonarcloud` as a single object but the
        --      documented config (and ours) makes it an array of connections
        -- Patch both notification handlers before setup() captures the
        -- function references on line 113-114 of sonarlint.lua.
        local cm = require 'sonarlint.connected_mode'
        local function safe_server_url(client, connection_id)
          local conns = vim.tbl_get(client, 'config', 'settings', 'sonarlint', 'connectedMode', 'connections') or {}
          for _, con in ipairs(conns.sonarqube or {}) do
            if con.connectionId == connection_id then
              return con.serverUrl
            end
          end
          for _, con in ipairs(conns.sonarcloud or {}) do
            if con.connectionId == connection_id then
              local region = (con.region or 'EU'):upper()
              return region == 'US' and 'https://sonarqube.us' or 'https://sonarcloud.io'
            end
          end
          return nil
        end

        cm.notify_connection_result = function(_, params, ctx)
          local client = vim.lsp.get_client_by_id(ctx.client_id)
          if not client then
            return
          end
          local cid = params.connectionId
          local url = safe_server_url(client, cid) or '<unknown>'
          local status = 'connected'
          if params.success == true then
            vim.notify_once('Connected to ' .. url .. ' (' .. cid .. ')', vim.log.levels.DEBUG)
          else
            status = 'failed-connection'
            -- params.reason is server-controlled; bound to keep the notify log sane.
            local reason = tostring(params.reason or 'unknown'):sub(1, 200)
            vim.notify_once('Cannot connect to ' .. url .. ' (' .. cid .. '): ' .. reason, vim.log.levels.ERROR)
          end
          cm._connected_clients[client.id] = status
        end

        cm.notify_invalid_token = function(_, params, ctx)
          local client = vim.lsp.get_client_by_id(ctx.client_id)
          if not client then
            return
          end
          local cid = params.connectionId
          local url = safe_server_url(client, cid) or '<unknown>'
          vim.notify('Cannot connect to ' .. url .. '. Invalid token for connection ' .. cid, vim.log.levels.WARN)
        end
      end

      require('sonarlint').setup(opts)
    end,
  },
}
