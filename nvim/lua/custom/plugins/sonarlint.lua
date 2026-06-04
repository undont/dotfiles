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

-- Project-local rule overrides. ESLint-style schema -- rule values are ESLint
-- severities, not SonarLint's native `{ level }` shape:
--   {
--     "rules": {
--       "go:S100": "off",
--       "go:S3776": "warn",
--       "javascript:S103": ["error", { "maximumLineLength": "120" }]
--     },
--     "overrides": [
--       { "files": ["**/*_test.go"],
--         "rules": { "go:S3776": "off" } }
--     ]
--   }
-- A rule value is a severity -- "off" | "warn" | "error" (or 0 | 1 | 2) -- or
-- the array form ["error", { params }] when a rule takes parameters. It's
-- normalised to SonarLint's `{ level, parameters }` before being sent to the
-- server. SonarLint has no warn/error split, so "warn" and "error" both map to
-- level "on"; only "off" silences a rule.
--
-- `rules` is merged into the LSP server's rule config (applies globally; works
-- in both standalone and connected mode -- in connected mode explicit "off"
-- wins over the server's "on"). `overrides` are applied client-side at
-- diagnostic publish time and can only subtractively silence diagnostics:
-- a globally-off rule can't be re-enabled per-glob because the server has
-- already stopped producing those diagnostics.
local LOCAL_RULES_FILE = '.sonarlint/localRules.json'

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

--- Read `.sonarlint/localRules.json` and return `{ rules, overrides }`, or
--- nil if the file is missing or malformed. Either field may be nil.
local function read_project_config(root)
  if not root or root == '' then
    return nil
  end
  local path = root .. '/' .. LOCAL_RULES_FILE
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
  return {
    rules = type(decoded.rules) == 'table' and decoded.rules or nil,
    overrides = type(decoded.overrides) == 'table' and decoded.overrides or nil,
  }
end

--- Map an ESLint severity token to a SonarLint level ('on' | 'off'), or nil if
--- the token isn't a recognised ESLint severity. SonarLint has no warn/error
--- distinction, so both collapse to 'on'.
---   "off"   / 0  -> "off"
---   "warn"  / 1  -> "on"
---   "error" / 2  -> "on"
local function eslint_severity_to_level(sev)
  if sev == 'off' or sev == 0 then
    return 'off'
  elseif sev == 'warn' or sev == 1 or sev == 'error' or sev == 2 then
    return 'on'
  end
  return nil
end

--- Normalise one ESLint-style rule value into SonarLint's `{ level, parameters }`
--- shape, or nil if it isn't valid ESLint syntax. Accepts a bare severity
--- ("off" | "warn" | "error", or 0 | 1 | 2) or the array form
--- ["error", { paramName = value }] -- ESLint options are positional, but
--- SonarLint parameters are named, so only a trailing object is carried across.
local function normalise_rule(value)
  if type(value) == 'string' or type(value) == 'number' then
    local level = eslint_severity_to_level(value)
    return level and { level = level } or nil
  end
  if type(value) == 'table' then
    local level = eslint_severity_to_level(value[1])
    if not level then
      return nil
    end
    local rule = { level = level }
    if type(value[2]) == 'table' then
      rule.parameters = value[2]
    end
    return rule
  end
  return nil
end

--- Translate an ESLint-style `rules` map (rule key -> severity) into the
--- SonarLint server's native `{ ruleKey = { level, parameters } }` form.
--- Unrecognised entries are dropped; returns nil when nothing survives.
local function eslint_to_sonarlint_rules(rules)
  if type(rules) ~= 'table' then
    return nil
  end
  local out = {}
  for key, value in pairs(rules) do
    local normalised = normalise_rule(value)
    if type(key) == 'string' and normalised then
      out[key] = normalised
    end
  end
  return next(out) and out or nil
end

--- Compile an `overrides` array into matcher entries:
---   { { matchers = { lpeg, ... }, off = { ["go:S3776"] = true, ... } }, ... }
--- Returns nil when there's nothing actionable (no valid globs / no "off" rules).
local function compile_overrides(overrides)
  if not overrides or vim.tbl_isempty(overrides) then
    return nil
  end
  if not (vim.glob and vim.glob.to_lpeg) then
    return nil -- needs nvim 0.10+
  end
  local compiled = {}
  for _, ov in ipairs(overrides) do
    if type(ov) == 'table' and type(ov.files) == 'table' and type(ov.rules) == 'table' then
      local matchers = {}
      for _, glob in ipairs(ov.files) do
        if type(glob) == 'string' then
          local ok, pat = pcall(vim.glob.to_lpeg, glob)
          if ok then
            table.insert(matchers, pat)
          end
        end
      end
      local off = {}
      for rule, value in pairs(ov.rules) do
        local normalised = normalise_rule(value)
        if normalised and normalised.level == 'off' then
          off[rule] = true
        end
      end
      if #matchers > 0 and next(off) then
        table.insert(compiled, { matchers = matchers, off = off })
      end
    end
  end
  return #compiled > 0 and compiled or nil
end

--- Return true if `code` should be suppressed for `path` under `compiled`.
--- Tries both the absolute path and the path relative to `root` so authors
--- can write either `**/*_test.go` or `internal/**/*_test.go` style globs.
local function is_overridden(compiled, root, path, code)
  if not compiled or not code or not path then
    return false
  end
  local rel = path
  if root and #root > 0 and path:sub(1, #root + 1) == root .. '/' then
    rel = path:sub(#root + 2)
  end
  for _, ov in ipairs(compiled) do
    if ov.off[code] then
      for _, pat in ipairs(ov.matchers) do
        if pat:match(path) or pat:match(rel) then
          return true
        end
      end
    end
  end
  return false
end

--- Mason install root. `vim.env.MASON` is only set after `mason.setup()`
--- runs, which may not have happened by the time sonarlint.nvim's config
--- fires (sonarlint.nvim doesn't depend on mason.nvim, so lazy-loading via
--- `ft = FILETYPES` can outrun mason). Fall back to mason's documented
--- default install location so paths resolve regardless of load order.
local function mason_root()
  return vim.env.MASON or (vim.fn.stdpath 'data' .. '/mason')
end

--- Build the analyzer jar list, filtering out any that aren't on disk so a
--- partial Mason install doesn't make the language server fail to start.
local function analyzer_jars()
  local dir = mason_root() .. '/share/sonarlint-analyzers'
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

--- @param mode 'changed' | 'all'
local function run_scan(mode)
  local scan_runner = require 'custom.core.scan_runner'
  if scan_runner.is_active() then
    vim.notify('A scan is already running', vim.log.levels.WARN)
    return
  end

  local files = list_scan_targets(mode)
  if #files == 0 then
    local msg = mode == 'changed' and 'No changed sonarlint-scannable files' or 'No sonarlint-scannable files in ' .. vim.fn.getcwd()
    vim.notify(msg, vim.log.levels.INFO)
    return
  end

  local label = mode == 'changed' and 'changed' or 'project'

  local function proceed()
    -- Track the buffers we open so we can unload only those in on_finalise.
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

    -- Pre-existing sonarlint buffers should still surface in the qf even
    -- though they don't drive the debounce.
    local extra = {}
    for _, client in ipairs(vim.lsp.get_clients { name = SONARLINT_CLIENT_NAME }) do
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
    -- Also watch already-loaded buffers from `files` so debounce reacts to
    -- them; they're not in `created` because they pre-existed.
    for _, path in ipairs(files) do
      local b = vim.fn.bufnr(path)
      if b ~= -1 then
        table.insert(watched, b)
      end
    end

    local collect = vim.list_extend(vim.list_extend({}, watched), extra)

    scan_runner.start {
      bufnrs = watched,
      collect_bufnrs = collect,
      get_diagnostics = sonarlint_diagnostics,
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

-- Suppress sonarlint when entering diff/review contexts (Octo, Diffview).
-- Strategy: leave existing clients running (they continue analysing the
-- pre-review buffers), but block new attaches via the FileType-handler gate
-- installed in config(). This avoids a JVM cold-start cost when leaving
-- review and dramatically reduces chatter, at the cost of sonarlint
-- continuing to analyse the small set of files open before the review.
--
-- vim.g.sonarlint_suppressed gates the FileType-handler attach-block (below)
-- and ui.lua's vim.notify chatter filter. Fidget progress for the
-- `sonarlint.nvim` client is dropped unconditionally in ui.lua — analysis
-- fires per-BufEnter and would otherwise pop a toast on every file open.
vim.g.sonarlint_suppressed = false

local function suppress_sonarlint()
  vim.g.sonarlint_suppressed = true
end

local function try_restore_sonarlint()
  if not vim.g.sonarlint_suppressed then
    return
  end

  -- Same guard as roslyn: don't restore while still in a review context
  local dv_ok, dv_lib = pcall(require, 'diffview.lib')
  if dv_ok and dv_lib.get_current_view() then
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'octo' then
      return
    end
  end

  vim.g.sonarlint_suppressed = false

  local ok, _ = pcall(require, 'sonarlint')
  if not ok then
    return
  end

  -- Re-fire FileType for loaded buffers so sonarlint.nvim reattaches
  local filetype_set = {}
  for _, ft in ipairs(FILETYPES) do
    filetype_set[ft] = true
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and filetype_set[vim.bo[buf].filetype] then
      vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
    end
  end
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'octo', 'DiffviewFiles', 'DiffviewFileHistory' },
  callback = suppress_sonarlint,
})

-- Re-enable sonarlint when returning to normal buffers after review closes.
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    if vim.g.sonarlint_suppressed then
      vim.defer_fn(function()
        if not vim.g.sonarlint_suppressed then
          return
        end
        try_restore_sonarlint()
      end, 2000)
    end
  end,
})

-- ---------------------------------------------------------------------------
-- Silence-rule code actions
--
-- Surface "silence this rule" quick fixes in the native code-action picker
-- (gra) for any sonar diagnostic under the cursor. Two variants per rule:
--   * project-wide  -> sets `rules["<code>"] = "off"` in localRules.json
--   * in test files -> adds (or extends) an `overrides` entry whose `files`
--                       are the test globs for the buffer's language and
--                       silences the rule only there
-- Both write `.sonarlint/localRules.json` (creating the dir/file if needed),
-- then apply the change to the running server immediately so the warning
-- disappears without a restart.
--
-- The actions are served by a tiny in-process LSP client (no JVM) rather than
-- by monkeypatching the sonar client: `vim.lsp.buf.code_action` builds each
-- client's `context.diagnostics` from that client's own namespace, so a
-- separate source that ignores the passed context and queries sonar
-- diagnostics directly is both simpler and independent of whatever the sonar
-- server itself offers for the line. Each action carries a Command (not a
-- workspace edit); execution is handled locally via vim.lsp.commands.
-- ---------------------------------------------------------------------------

local SILENCE_COMMAND = 'sonarlint.silenceRule'

-- Test-file globs per filetype. Languages without a settled test-naming
-- convention are omitted -- they simply don't get the "in test files" action.
local TEST_GLOBS = {
  go = { '**/*_test.go' },
  python = { '**/test_*.py', '**/*_test.py' },
  javascript = { '**/*.test.js', '**/*.spec.js' },
  javascriptreact = { '**/*.test.jsx', '**/*.spec.jsx' },
  typescript = { '**/*.test.ts', '**/*.spec.ts' },
  typescriptreact = { '**/*.test.tsx', '**/*.spec.tsx' },
  cs = { '**/*Tests.cs', '**/*Test.cs' },
  cpp = { '**/*_test.cpp', '**/*_test.cc' },
  c = { '**/*_test.c' },
  php = { '**/*Test.php' },
}

--- The rule key for a diagnostic (e.g. "go:S3776"), or nil. Mirrors how the
--- override filter reads `d.code`, with a fallback to the raw LSP payload.
local function diagnostic_code(d)
  local code = d.code
  if code == nil and d.user_data and d.user_data.lsp then
    code = d.user_data.lsp.code
  end
  return code ~= nil and tostring(code) or nil
end

--- Resolve the project root for writing localRules.json. Prefer the attached
--- sonar client's root (so the file lands where before_init will read it on
--- the next start), then the nearest `.sonarlint`/`.git` ancestor, then cwd.
local function project_root_for_buf(bufnr)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, name = SONARLINT_CLIENT_NAME }) do
    local root = (client.config and (client.config._sonarlint_root or client.config.root_dir)) or client.root_dir
    if root and root ~= '' then
      return root
    end
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd()
  return vim.fs.root(dir, { '.sonarlint', '.git' }) or vim.fn.getcwd()
end

--- Read localRules.json as a raw decoded table (preserving every field), or {}.
local function read_local_rules(path)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local ok, content = pcall(vim.fn.readfile, path)
  if not ok then
    return {}
  end
  local decoded
  ok, decoded = pcall(vim.json.decode, table.concat(content, '\n'))
  if ok and type(decoded) == 'table' then
    return decoded
  end
  return {}
end

--- Pretty-print a Lua value as JSON (2-space indent, sorted object keys) so the
--- hand-edited localRules.json stays readable. Strings are escaped via
--- vim.json.encode; empty tables serialise as `{}`.
local function encode_json(value, indent)
  indent = indent or ''
  local child = indent .. '  '
  local t = type(value)
  if t == 'table' then
    if vim.islist(value) and #value > 0 then
      local parts = {}
      for _, item in ipairs(value) do
        table.insert(parts, child .. encode_json(item, child))
      end
      return '[\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. ']'
    elseif next(value) == nil then
      return '{}'
    end
    local keys = {}
    for k in pairs(value) do
      table.insert(keys, tostring(k))
    end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      table.insert(parts, child .. vim.json.encode(k) .. ': ' .. encode_json(value[k], child))
    end
    return '{\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. '}'
  elseif t == 'string' then
    return vim.json.encode(value)
  elseif t == 'number' or t == 'boolean' then
    return tostring(value)
  end
  return 'null'
end

--- True if two glob lists hold the same entries (order-insensitive). Used to
--- fold a test-scope silence into an existing matching `overrides` entry
--- instead of appending a duplicate.
local function same_globs(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' or #a ~= #b then
    return false
  end
  local sa, sb = vim.deepcopy(a), vim.deepcopy(b)
  table.sort(sa)
  table.sort(sb)
  for i = 1, #sa do
    if sa[i] ~= sb[i] then
      return false
    end
  end
  return true
end

--- Immediately drop sonar diagnostics carrying `code` so the silenced warning
--- vanishes before the server's next publish. `only_bufnr` limits the sweep to
--- one buffer (test-scope only applies in test files, so we don't clear others).
local function drop_diagnostics_with_code(code, only_bufnr)
  for _, client in ipairs(vim.lsp.get_clients { name = SONARLINT_CLIENT_NAME }) do
    local ok, ns = pcall(vim.lsp.diagnostic.get_namespace, client.id)
    if ok and ns then
      local bufs = only_bufnr and { only_bufnr } or vim.api.nvim_list_bufs()
      for _, bufnr in ipairs(bufs) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
          local kept, changed = {}, false
          for _, d in ipairs(vim.diagnostic.get(bufnr, { namespace = ns })) do
            if diagnostic_code(d) == code then
              changed = true
            else
              table.insert(kept, d)
            end
          end
          if changed then
            vim.diagnostic.set(ns, bufnr, kept)
          end
        end
      end
    end
  end
end

--- Push the just-written rule change to running sonar clients so the warning
--- clears without a restart.
local function apply_silence_live(scope, code, root, bufnr)
  local clients = vim.lsp.get_clients { name = SONARLINT_CLIENT_NAME }
  if scope == 'global' then
    for _, client in ipairs(clients) do
      local cfg = client.config
      if cfg then
        cfg.settings = cfg.settings or {}
        cfg.settings.sonarlint = cfg.settings.sonarlint or {}
        cfg.settings.sonarlint.rules = cfg.settings.sonarlint.rules or {}
        cfg.settings.sonarlint.rules[code] = { level = 'off' }
        -- sonarlint re-pulls config via workspace/configuration after this
        -- notify; nvim's default handler answers from the (now updated)
        -- client.config.settings, so the server stops emitting the rule.
        client:notify('workspace/didChangeConfiguration', { settings = cfg.settings })
      end
    end
    drop_diagnostics_with_code(code)
    return
  end

  -- Test scope: recompile overrides from the updated file so the always-on
  -- publishDiagnostics wrapper filters future emits, then clear the current
  -- buffer if it now matches a test glob.
  for _, client in ipairs(clients) do
    local r = (client.config and client.config._sonarlint_root) or root
    local cfg = read_project_config(r)
    if cfg then
      client.config._sonarlint_overrides = compile_overrides(cfg.overrides)
    end
  end
  local compiled = clients[1] and clients[1].config and clients[1].config._sonarlint_overrides
  if compiled and bufnr and vim.api.nvim_buf_is_loaded(bufnr) then
    local path = vim.api.nvim_buf_get_name(bufnr)
    if is_overridden(compiled, root, path, code) then
      drop_diagnostics_with_code(code, bufnr)
    end
  end
end

--- Add a silence to .sonarlint/localRules.json and apply it live.
--- `args` = { root, code, scope = 'global'|'test', globs?, bufnr? }
local function silence_rule(args)
  local root, code, scope = args.root, args.code, args.scope
  if not root or not code then
    return
  end
  local dir = root .. '/.sonarlint'
  local path = dir .. '/localRules.json'
  if vim.fn.isdirectory(dir) == 0 and vim.fn.mkdir(dir, 'p') == 0 then
    vim.notify('Sonar: could not create ' .. dir, vim.log.levels.ERROR)
    return
  end

  local data = read_local_rules(path)
  if scope == 'global' then
    data.rules = type(data.rules) == 'table' and data.rules or {}
    data.rules[code] = 'off'
  else
    local globs = args.globs or {}
    data.overrides = type(data.overrides) == 'table' and data.overrides or {}
    local entry
    for _, ov in ipairs(data.overrides) do
      if type(ov) == 'table' and same_globs(ov.files, globs) then
        entry = ov
        break
      end
    end
    if not entry then
      entry = { files = globs, rules = {} }
      table.insert(data.overrides, entry)
    end
    entry.rules = type(entry.rules) == 'table' and entry.rules or {}
    entry.rules[code] = 'off'
  end

  local lines = vim.split(encode_json(data, ''), '\n')
  if not pcall(vim.fn.writefile, lines, path) then
    vim.notify('Sonar: could not write ' .. path, vim.log.levels.ERROR)
    return
  end

  apply_silence_live(scope, code, root, args.bufnr)
  local where = scope == 'global' and 'project-wide' or 'in test files'
  vim.notify('Sonar: silenced ' .. code .. ' ' .. where, vim.log.levels.INFO)
end

--- Build silence code actions for the sonar diagnostics overlapping a
--- codeAction request's range. Returns LSP CodeAction objects whose Command is
--- handled locally by vim.lsp.commands[SILENCE_COMMAND].
local function build_silence_actions(params)
  local uri = params.textDocument and params.textDocument.uri
  if not uri then
    return {}
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return {}
  end
  local range = params.range or {}
  local first = (range.start and range.start.line) or 0
  local last = (range['end'] and range['end'].line) or first
  local root = project_root_for_buf(bufnr)
  local globs = TEST_GLOBS[vim.bo[bufnr].filetype]

  local actions, seen = {}, {}
  for _, d in ipairs(sonarlint_diagnostics(bufnr)) do
    local dfirst = d.lnum or 0
    local dlast = d.end_lnum or dfirst
    if dfirst <= last and dlast >= first then
      local code = diagnostic_code(d)
      if code and not seen[code] then
        seen[code] = true
        table.insert(actions, {
          title = 'Sonar: silence ' .. code .. ' (project)',
          kind = 'quickfix',
          command = {
            title = 'Silence ' .. code,
            command = SILENCE_COMMAND,
            arguments = { { root = root, code = code, scope = 'global', bufnr = bufnr } },
          },
        })
        if globs then
          table.insert(actions, {
            title = 'Sonar: silence ' .. code .. ' in test files',
            kind = 'quickfix',
            command = {
              title = 'Silence ' .. code .. ' in tests',
              command = SILENCE_COMMAND,
              arguments = { { root = root, code = code, scope = 'test', globs = globs, bufnr = bufnr } },
            },
          })
        end
      end
    end
  end
  return actions
end

-- Command id sonar attaches to its "Show issue details for '<rule>'" code
-- action. Used to float that action to the top of gra. (The OpenRuleDesc /
-- OpenStandaloneRuleDesc commands are internal executeCommand targets, not the
-- code-action command -- verified against the running server.)
local DETAILS_COMMANDS = {
  ['SonarLint.ShowIssueDetailsCodeAction'] = true,
}

--- The command id carried by a code action, whether it's a bare Command or a
--- CodeAction with a nested `command`. Returns nil when there's none.
local function action_command(action)
  local c = action and action.command
  if type(c) == 'table' then
    return c.command
  end
  return c -- bare Command string, or nil
end

--- Reorder a sonar codeAction result so the "Show issue details" action sits
--- first, preserving the relative order of everything else. Returns the
--- (possibly new) list; a no-op when the action isn't present.
local function details_first(result)
  if type(result) ~= 'table' or #result < 2 then
    return result
  end
  local head, tail = {}, {}
  for _, action in ipairs(result) do
    local cmd = action_command(action)
    if cmd and DETAILS_COMMANDS[cmd] then
      table.insert(head, action)
    else
      table.insert(tail, action)
    end
  end
  if #head == 0 then
    return result
  end
  return vim.list_extend(head, tail)
end

--- Wrap a sonar client's request method once so its codeAction responses carry
--- the silence actions, placing them immediately after sonar's own actions in
--- the gra picker. Neovim aggregates code actions per responding client (v0.12
--- `on_code_action_results` iterates `pairs(results)`), so riding inside the
--- sonar client's result is the only way to control where ours appear; a
--- separate code-action source would land in its own group at the bottom.
local function wrap_sonar_codeaction(client)
  if not client or client._sonarlint_codeaction_wrapped then
    return
  end
  client._sonarlint_codeaction_wrapped = true
  local orig_request = client.request
  client.request = function(self, method, params, handler, req_bufnr)
    if method == 'textDocument/codeAction' and type(handler) == 'function' then
      local function wrapped(err, result, ctx, hcfg)
        if not err then
          result = result or {}
          if type(result) == 'table' then
            -- Float sonar's own "Show issue details" action to the top, then
            -- append our silence actions after sonar's remaining entries.
            result = details_first(result)
            for _, action in ipairs(build_silence_actions(params)) do
              table.insert(result, action)
            end
          end
        end
        return handler(err, result, ctx, hcfg)
      end
      return orig_request(self, method, params, wrapped, req_bufnr)
    end
    return orig_request(self, method, params, handler, req_bufnr)
  end
end

-- ---------------------------------------------------------------------------
-- Rich "issue details" popup
--
-- Selecting sonar's "Show issue details for '<rule>'" code action makes the
-- server push sonarlint/showRuleDescription, which sonarlint.nvim renders as a
-- generic full-screen popup of the rule's HTML description. We replace that
-- rendering with our own popup that, for deprecation findings, leads with the
-- deprecated symbol's signature and its "@deprecated -> use X instead" note --
-- the specific guidance sonar's own (generic) S1874 text explicitly defers to
-- ("check the deprecation message ... what the recommended alternative is").
--
-- That note is pulled from the editor-facing language server's hover at the
-- finding. Deprecation is detected language-agnostically via a co-located
-- diagnostic carrying the LSP `Deprecated` tag (e.g. ts_ls reports
-- "'X' is deprecated" tagged Deprecated alongside sonar's S1874), so it extends
-- to any language whose server tags deprecated usages -- no rule-key list.
--
-- The action-reordering helpers (DETAILS_COMMANDS / details_first) live above
-- wrap_sonar_codeaction, which consumes them.
-- ---------------------------------------------------------------------------

--- The editor-facing LSP diagnostic at `lnum` carrying the `Deprecated` tag, or
--- nil. Neovim normalises LSP `tags: [2]` to `_tags.deprecated`; we also accept
--- the raw payload form. Sonar's own diagnostics never set the tag, so a match
--- always comes from a language server (ts_ls, gopls, roslyn, ...).
local function deprecated_diagnostic_at(bufnr, lnum)
  for _, d in ipairs(vim.diagnostic.get(bufnr, { lnum = lnum })) do
    if d._tags and d._tags.deprecated then
      return d
    end
    local tags = d.user_data and d.user_data.lsp and d.user_data.lsp.tags
    if type(tags) == 'table' then
      for _, t in ipairs(tags) do
        if t == 2 then
          return d
        end
      end
    end
  end
  return nil
end

--- Request hover at `position` from every editor-facing (non-sonar) LSP client
--- on `bufnr`, returning the first non-empty result as markdown lines via `cb`.
--- Falls back to `cb(nil)` if nothing useful answers within the timeout.
local function deprecation_hover(bufnr, position, cb)
  local clients = vim.tbl_filter(function(c)
    return c.name ~= SONARLINT_CLIENT_NAME and c:supports_method 'textDocument/hover'
  end, vim.lsp.get_clients { bufnr = bufnr })

  local done = false
  local function finish(lines)
    if done then
      return
    end
    done = true
    cb(lines)
  end

  if #clients == 0 then
    return finish(nil)
  end

  local params = { textDocument = { uri = vim.uri_from_bufnr(bufnr) }, position = position }
  local remaining = #clients
  for _, client in ipairs(clients) do
    client:request('textDocument/hover', params, function(_, result)
      remaining = remaining - 1
      if not done and result and result.contents then
        local md = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
        if md and #md > 0 then
          return finish(md)
        end
      end
      if remaining == 0 then
        finish(nil)
      end
    end, bufnr)
  end

  -- Safety net: never leave the popup unshown if a server stalls.
  vim.defer_fn(function()
    finish(nil)
  end, 2000)
end

--- SonarLint appends a generic "others" fallback context (resource
--- `others_section_html_content.html`: "How can I fix it in another component
--- or framework?" + "Help us improve") to contextual tabs when it has no
--- framework-specific guidance. It carries no real fix, so we drop it; if a tab
--- has nothing left, the tab is skipped entirely (see rule_description_lines).
local function is_fallback_context(ctx)
  local key = ctx.contextKey and ctx.contextKey:lower()
  return key == 'others' or ctx.displayName == 'Others'
end

--- Render one rule-description tab's body. A tab is either non-contextual
--- (`ruleDescriptionTabNonContextual.htmlContent`) or contextual, where
--- `ruleDescriptionTabContextual` is a *list* of per-context variants
--- ({ htmlContent, contextKey, displayName }), e.g. "How to fix it in PropTypes"
--- vs "...in TypeScript". sonarlint.nvim's own renderer reads `.htmlContent` off
--- that list and so shows contextual tabs (S6767's "How can I fix it?") empty;
--- we render every real context, default first, each under its displayName.
--- Returns {} when the tab has no useful content (e.g. only the "others"
--- fallback) so the caller can omit it.
local function tab_body_lines(tab, filetype)
  local utils = require 'sonarlint.utils'

  local nonctx = tab.ruleDescriptionTabNonContextual
  if type(nonctx) == 'table' and nonctx.htmlContent and nonctx.htmlContent ~= '' then
    return utils.html_to_markdown_lines(nonctx.htmlContent, filetype)
  end

  local contexts = tab.ruleDescriptionTabContextual
  if type(contexts) ~= 'table' then
    return {}
  end

  -- Drop the generic fallback, then put the default context first.
  local useful = {}
  for _, ctx in ipairs(contexts) do
    if not is_fallback_context(ctx) then
      if ctx.contextKey and ctx.contextKey == tab.defaultContextKey then
        table.insert(useful, 1, ctx)
      else
        table.insert(useful, ctx)
      end
    end
  end
  if #useful == 0 then
    return {}
  end

  local lines = {}
  for i, ctx in ipairs(useful) do
    if i > 1 then
      table.insert(lines, '')
    end
    if ctx.displayName and ctx.displayName ~= '' then
      vim.list_extend(lines, { '### ' .. ctx.displayName, '' })
    end
    if ctx.htmlContent and ctx.htmlContent ~= '' then
      vim.list_extend(lines, utils.html_to_markdown_lines(ctx.htmlContent, filetype))
    end
  end
  return lines
end

--- Build the rule-description body (markdown lines) from a showRuleDescription
--- payload: a single htmlDescription, or the tabbed form ("Why is this an
--- issue?", "How can I fix it?", ...). Tabs with no useful body (e.g. a "How can
--- I fix it?" that only held the generic fallback) are omitted entirely.
local function rule_description_lines(result, filetype)
  local html = result.htmlDescription
  if html ~= nil and html ~= '' then
    return require('sonarlint.utils').html_to_markdown_lines(html, filetype)
  end
  local lines = {}
  for _, tab in ipairs(result.htmlDescriptionTabs or {}) do
    local body = tab_body_lines(tab, filetype)
    if #body > 0 then
      if #lines > 0 then
        table.insert(lines, '')
      end
      vim.list_extend(lines, { '## ' .. (tab.title or ''), '' })
      vim.list_extend(lines, body)
    end
  end
  return lines
end

--- Open a centred, read-only markdown popup. `q`/`<Esc>` close it.
local function show_details_popup(lines)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  local win = vim.api.nvim_open_win(buf, true, {
    style = 'minimal',
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = 'rounded',
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].conceallevel = 2
  for _, key in ipairs { 'q', '<Esc>' } do
    vim.keymap.set('n', key, '<cmd>close<cr>', { buffer = buf, silent = true })
  end
end

--- showRuleDescription handler: render the rule description in our popup, led
--- by the deprecated symbol's hover note when the finding under the cursor is a
--- deprecation. Replaces sonarlint.nvim's generic renderer. Context (which
--- buffer/finding) is read from the current window -- focus stays on the source
--- buffer until this popup opens.
local function rich_rule_handler(_, result, _)
  if type(result) ~= 'table' then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype
  local title = { '# ' .. (result.key or '') .. ': ' .. (result.name or ''), '' }
  local body = rule_description_lines(result, filetype)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local depr = deprecated_diagnostic_at(bufnr, cursor[1] - 1)
  if not depr then
    vim.list_extend(title, body)
    return show_details_popup(title)
  end

  deprecation_hover(bufnr, { line = depr.lnum, character = depr.col }, function(hover_lines)
    local lines = title
    if hover_lines and #hover_lines > 0 then
      vim.list_extend(lines, { '## Deprecated API', '' })
      vim.list_extend(lines, hover_lines)
      vim.list_extend(lines, { '', '---', '' })
    end
    vim.list_extend(lines, body)
    show_details_popup(lines)
  end)
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

      local extension_dir = mason_root() .. '/packages/sonarlint-language-server/extension'
      local opts = {
        server = {
          cmd = cmd,
          -- C# analysis runs through omnisharp bundled inside the sonarlint
          -- vsix -- it doesn't replace roslyn (which keeps providing the
          -- editor-facing LSP). Safe to set unconditionally; sonarlint only
          -- spawns omnisharp when actually scanning a .cs file.
          init_options = {
            omnisharpDirectory = extension_dir .. '/omnisharp',
            csharpOssPath = mason_root() .. '/share/sonarlint-analyzers/sonarcsharp.jar',
          },
          settings = {
            sonarlint = {},
          },
          -- Always-on: load `.sonarlint/localRules.json` and apply it.
          -- `rules` is merged into config.settings.sonarlint.rules (sent to
          -- the LSP server). `overrides` are compiled into glob matchers and
          -- stashed on the config; the LspAttach hook below uses them to
          -- filter diagnostics client-side. The connected-mode branch below
          -- wraps this to additionally bind the project key when SonarCloud
          -- creds are present.
          before_init = function(params, config)
            -- Always stash the root so the silence-rule writer and the
            -- override recompile can find the project even before any
            -- localRules.json exists.
            local root = params.rootPath or config.root_dir
            config._sonarlint_root = root
            local cfg = read_project_config(root)
            if not cfg then
              return
            end
            local rules = eslint_to_sonarlint_rules(cfg.rules)
            if rules then
              config.settings = config.settings or {}
              config.settings.sonarlint = config.settings.sonarlint or {}
              config.settings.sonarlint.rules = vim.tbl_deep_extend('force', config.settings.sonarlint.rules or {}, rules)
            end
            config._sonarlint_overrides = compile_overrides(cfg.overrides)
          end,
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
        local base_before_init = opts.server.before_init
        opts.server.before_init = function(params, config)
          if base_before_init then
            base_before_init(params, config)
          end
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
        --
        -- Upstream tracking: https://gitlab.com/schrieveslaach/sonarlint.nvim/-/issues/42
        -- Remove this block once the fix lands and we've bumped the plugin.
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

      -- Apply project-local `overrides` from .sonarlint/localRules.json at
      -- diagnostic publish time. We wrap the sonarlint client's
      -- publishDiagnostics handler once on first attach so each diagnostic
      -- gets filtered against the compiled glob+rule matchers. The compiled
      -- overrides and root are read from `client.config` *inside* the handler
      -- rather than captured up front, so a silence-rule code action that adds
      -- an override at runtime takes effect on the next publish without a
      -- restart. Filtering is subtractive only -- a rule that's off globally
      -- can't be re-enabled per-glob because the server has already stopped
      -- emitting those diagnostics.
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= SONARLINT_CLIENT_NAME then
            return
          end
          -- Make sonar's own codeAction responses carry our silence actions,
          -- so they appear right after sonar's entries in the gra picker.
          wrap_sonar_codeaction(client)

          if client._sonarlint_overrides_wrapped then
            return
          end
          client._sonarlint_overrides_wrapped = true

          -- Replace sonar's generic rule-description popup with our richer one
          -- (deprecation note + full description). See rich_rule_handler.
          client.handlers['sonarlint/showRuleDescription'] = rich_rule_handler

          local default = client.handlers['textDocument/publishDiagnostics'] or vim.lsp.handlers['textDocument/publishDiagnostics']
          client.handlers['textDocument/publishDiagnostics'] = function(err, result, ctx, hcfg)
            local compiled = client.config and client.config._sonarlint_overrides
            if compiled and result and result.uri and result.diagnostics then
              local root = client.config._sonarlint_root
              local path = vim.uri_to_fname(result.uri)
              local kept = {}
              for _, d in ipairs(result.diagnostics) do
                if not is_overridden(compiled, root, path, d.code) then
                  table.insert(kept, d)
                end
              end
              result.diagnostics = kept
            end
            return default(err, result, ctx, hcfg)
          end
        end,
      })

      -- Gate sonarlint's FileType autocmd on `vim.g.sonarlint_suppressed`.
      -- Without this, every `FileType cs` (review buffers, `<leader>de`'s
      -- `:edit`) runs the handler synchronously -- which calls find_root_dir
      -- (walks the filesystem) and, on cache miss, start_sonarlint_lsp
      -- (spawns a JVM-backed client). On large .NET repos that's ~1s warm /
      -- ~15s cold, blocking the editor on every cs file open during review.
      --
      -- sonarlint.nvim registers a single FileType autocmd with
      -- `pattern = table.concat(FILETYPES, ',')`. nvim_get_autocmds splits
      -- multi-pattern autocmds into per-pattern entries that share an id and
      -- callback, so we can't compare patterns directly -- find the id
      -- whose entries cover the most of FILETYPES (uniquely sonarlint).
      local filetype_set = {}
      for _, ft in ipairs(FILETYPES) do
        filetype_set[ft] = true
      end

      local id_count, id_callback = {}, {}
      for _, ac in ipairs(vim.api.nvim_get_autocmds { event = 'FileType' }) do
        if ac.callback and filetype_set[ac.pattern] then
          id_count[ac.id] = (id_count[ac.id] or 0) + 1
          id_callback[ac.id] = ac.callback
        end
      end

      local sonar_id, sonar_count, sonar_cb = nil, 0, nil
      for id, count in pairs(id_count) do
        if count > sonar_count then
          sonar_id, sonar_count, sonar_cb = id, count, id_callback[id]
        end
      end

      if sonar_id and sonar_count >= math.floor(#FILETYPES / 2) then
        vim.api.nvim_del_autocmd(sonar_id)
        vim.api.nvim_create_autocmd('FileType', {
          pattern = FILETYPES,
          callback = function(args)
            if vim.g.sonarlint_suppressed then
              return
            end
            return sonar_cb(args)
          end,
        })
      end

      -- Silence-rule code actions: execute the action's Command locally (no
      -- round-trip to a server). The codeAction wrap is installed from the
      -- LspAttach hook above; here we register the command handler and wrap any
      -- sonar client that already attached before the hook existed (e.g. the ft
      -- buffer that loaded this plugin).
      vim.lsp.commands[SILENCE_COMMAND] = function(command)
        local arg = command.arguments and command.arguments[1]
        if arg then
          silence_rule(arg)
        end
      end

      for _, client in ipairs(vim.lsp.get_clients { name = SONARLINT_CLIENT_NAME }) do
        wrap_sonar_codeaction(client)
      end
    end,
  },
}
