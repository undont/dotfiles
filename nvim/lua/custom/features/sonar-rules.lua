-- project-local sonar rule model: the .sonarlint/localRules.json schema
-- (ESLint-style rules + glob overrides), its read/write/encode layer, and the
-- live application of a silenced rule to running sonar clients. extracted from
-- plugins/sonarlint.lua.
--
-- localRules.json uses an ESLint-style schema: rule values are ESLint
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
-- a rule value is a severity ("off" | "warn" | "error", or 0 | 1 | 2) or
-- the array form ["error", { params }] when a rule takes parameters. it's
-- normalised to SonarLint's `{ level, parameters }` before being sent to the
-- server. SonarLint has no warn/error split, so "warn" and "error" both map to
-- level "on"; only "off" silences a rule.
--
-- `rules` is merged into the LSP server's rule config (applies globally; works
-- in both standalone and connected mode; in connected mode explicit "off"
-- wins over the server's "on"). `overrides` are applied client-side at
-- diagnostic publish time and can only subtractively silence diagnostics:
-- a globally-off rule can't be re-enabled per-glob because the server has
-- already stopped producing those diagnostics.

local common = require 'custom.features.sonar-common'

local M = {}

local CONNECTED_MODE_FILE = '.sonarlint/connectedMode.json'
local LOCAL_RULES_FILE = '.sonarlint/localRules.json'

--- read and JSON-decode a file, returning the decoded table or nil if the file
--- is missing or malformed. shared by the connectedMode/localRules readers
local function read_json(path)
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
  return decoded
end

--- read `.sonarlint/connectedMode.json` from a project root and return its
--- `projectKey`, or nil if the file is missing or malformed
function M.read_project_key(root)
  if not root or root == '' then
    return nil
  end
  local decoded = read_json(root .. '/' .. CONNECTED_MODE_FILE)
  return decoded and decoded.projectKey or nil
end

--- read `.sonarlint/localRules.json` and return `{ rules, overrides }`, or
--- nil if the file is missing or malformed. either field may be nil
function M.read_project_config(root)
  if not root or root == '' then
    return nil
  end
  local decoded = read_json(root .. '/' .. LOCAL_RULES_FILE)
  if not decoded then
    return nil
  end
  return {
    rules = type(decoded.rules) == 'table' and decoded.rules or nil,
    overrides = type(decoded.overrides) == 'table' and decoded.overrides or nil,
  }
end

--- read localRules.json as a raw decoded table (preserving every field), or {}
local function read_local_rules(path)
  return read_json(path) or {}
end

--- map an ESLint severity token to a SonarLint level ('on' | 'off'), or nil if
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

--- normalise one ESLint-style rule value into SonarLint's `{ level, parameters }`
--- shape, or nil if it isn't valid ESLint syntax. accepts a bare severity
--- ("off" | "warn" | "error", or 0 | 1 | 2) or the array form
--- ["error", { paramName = value }]: ESLint options are positional, but
--- SonarLint parameters are named, so only a trailing object is carried across
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

--- translate an ESLint-style `rules` map (rule key -> severity) into the
--- SonarLint server's native `{ ruleKey = { level, parameters } }` form.
--- unrecognised entries are dropped; returns nil when nothing survives
function M.eslint_to_sonarlint_rules(rules)
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

--- compile an `overrides` array into matcher entries:
---   { { matchers = { lpeg, ... }, off = { ["go:S3776"] = true, ... } }, ... }
--- returns nil when there's nothing actionable (no valid globs / no "off" rules)
function M.compile_overrides(overrides)
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

--- return true if `code` should be suppressed for `path` under `compiled`.
--- tries both the absolute path and the path relative to `root` so authors
--- can write either `**/*_test.go` or `internal/**/*_test.go` style globs
function M.is_overridden(compiled, root, path, code)
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

--- pretty-print a lua value as JSON (2-space indent, sorted object keys) so the
--- hand-edited localRules.json stays readable. strings are escaped via
--- vim.json.encode; empty tables serialise as `{}`
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

--- true if two glob lists hold the same entries (order-insensitive). used to
--- fold a test-scope silence into an existing matching `overrides` entry
--- instead of appending a duplicate
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

--- immediately drop sonar diagnostics carrying `code` so the silenced warning
--- vanishes before the server's next publish. `only_bufnr` limits the sweep to
--- one buffer (test-scope only applies in test files, so we don't clear others)
local function drop_diagnostics_with_code(code, only_bufnr)
  for _, client in ipairs(vim.lsp.get_clients { name = common.SONARLINT_CLIENT_NAME }) do
    local ok, ns = pcall(vim.lsp.diagnostic.get_namespace, client.id)
    if ok and ns then
      local bufs = only_bufnr and { only_bufnr } or vim.api.nvim_list_bufs()
      for _, bufnr in ipairs(bufs) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
          local kept, changed = {}, false
          for _, d in ipairs(vim.diagnostic.get(bufnr, { namespace = ns })) do
            if common.diagnostic_code(d) == code then
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

--- push the just-written rule change to running sonar clients so the warning
--- clears without a restart
local function apply_silence_live(scope, code, root, bufnr)
  local clients = vim.lsp.get_clients { name = common.SONARLINT_CLIENT_NAME }
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
        -- client.config.settings, so the server stops emitting the rule
        client:notify('workspace/didChangeConfiguration', { settings = cfg.settings })
      end
    end
    drop_diagnostics_with_code(code)
    return
  end

  -- test scope: recompile overrides from the updated file so the always-on
  -- publishDiagnostics wrapper filters future emits, then clear the current
  -- buffer if it now matches a test glob
  for _, client in ipairs(clients) do
    local r = (client.config and client.config._sonarlint_root) or root
    local cfg = M.read_project_config(r)
    if cfg then
      client.config._sonarlint_overrides = M.compile_overrides(cfg.overrides)
    end
  end
  local compiled = clients[1] and clients[1].config and clients[1].config._sonarlint_overrides
  if compiled and bufnr and vim.api.nvim_buf_is_loaded(bufnr) then
    local path = vim.api.nvim_buf_get_name(bufnr)
    if M.is_overridden(compiled, root, path, code) then
      drop_diagnostics_with_code(code, bufnr)
    end
  end
end

--- add a silence to .sonarlint/localRules.json and apply it live.
--- `args` = { root, code, scope = 'global'|'test', globs?, bufnr? }
function M.silence_rule(args)
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

return M
