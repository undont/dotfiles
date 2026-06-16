-- async project build: detect project type, run build, populate quickfix

local M = {}

local scan_runner = require 'custom.features.scan-runner'

--- detect package manager from lockfile in a directory
---@param dir string
---@return string runner 'bun', 'pnpm', 'yarn', or 'npm'
local function detect_pkg_runner(dir)
  if vim.fn.filereadable(dir .. '/bun.lock') == 1 or vim.fn.filereadable(dir .. '/bun.lockb') == 1 then
    return 'bun'
  elseif vim.fn.filereadable(dir .. '/pnpm-lock.yaml') == 1 then
    return 'pnpm'
  elseif vim.fn.filereadable(dir .. '/yarn.lock') == 1 then
    return 'yarn'
  end
  return 'npm'
end

--- build tsc command using the detected package manager
---@param dir string
---@return string[] cmd
local function tsc_cmd(dir)
  local runner = detect_pkg_runner(dir)
  if runner == 'bun' then
    return { 'bun', 'run', 'tsc', '--noEmit', '--pretty', 'false' }
  elseif runner == 'pnpm' then
    return { 'pnpm', 'exec', 'tsc', '--noEmit', '--pretty', 'false' }
  elseif runner == 'yarn' then
    return { 'yarn', 'tsc', '--noEmit', '--pretty', 'false' }
  end
  return { 'npx', 'tsc', '--noEmit', '--pretty', 'false' }
end

--- build check command (eslint + tsc) using the detected package manager
---@param dir string
---@return string[] cmd
local function check_cmd(dir)
  local runner = detect_pkg_runner(dir)
  if runner == 'bun' then
    return { 'bun', 'run', 'check' }
  elseif runner == 'pnpm' then
    return { 'pnpm', 'run', 'check' }
  elseif runner == 'yarn' then
    return { 'yarn', 'check' }
  end
  return { 'npm', 'run', 'check' }
end

--- find the best dotnet build target, preferring solutions over projects.
--- from the matched .csproj directory, walks up to cwd looking for .sln/.slnx
---@param csproj_dir string directory containing the matched .csproj
---@return string target path to build
local function find_dotnet_target(csproj_dir)
  local cwd = vim.fn.getcwd()
  local dir = csproj_dir

  -- walk up looking for a solution file
  while #dir >= #cwd do
    for _, ext in ipairs { '*.slnx', '*.sln' } do
      local matches = vim.fn.glob(dir .. '/' .. ext, false, true)
      for _, path in ipairs(matches) do
        -- skip build variants (.ci.slnx, .build.sln, .test.sln, etc)
        if not vim.fs.basename(path):match '%.[%l][%w]*%.slnx?$' then
          return path
        end
      end
    end
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then
      break
    end
    dir = parent
  end

  -- no solution found, use the .csproj directly
  local csproj = vim.fn.glob(csproj_dir .. '/*.csproj', false, true)
  return csproj[1] or csproj_dir
end

-- build commands keyed by root marker file
-- each entry: { marker, cmd (table or function(dir)->table), efm }
-- checked in priority order; first match wins (unless Makefile, which extracts targets)
local build_configs = {
  {
    marker = 'go.mod',
    cmd = { 'go', 'vet', './...' },
    efm = 'vet: %f:%l:%c: %m,vet: %f:%l: %m,%f:%l:%c: %m,%f:%l: %m,%-G# %.%#,%-G%.%#',
  },
  {
    marker = 'vite.config.*',
    cmd = check_cmd, -- resolved at runtime from the matched directory
    efm = '%f:%l:%c: ERROR: %m,%f:%l:%c: error: %m,%f:%l:%c: warning: %m,%-G%.%#',
  },
  {
    marker = 'tsconfig.json',
    cmd = tsc_cmd, -- resolved at runtime from the matched directory
    efm = '%f(%l\\,%c): error TS%n: %m,%f(%l\\,%c): warning TS%n: %m',
  },
  {
    marker = '*.csproj',
    cmd = function(dir)
      return { 'dotnet', 'build', find_dotnet_target(dir), '--no-incremental', '-consoleloggerparameters:NoSummary' }
    end,
    efm = '%f(%l\\,%c): %trror %m,%f(%l\\,%c): %tarning %m',
  },
}

-- lua patterns that indicate a build-related make target
-- plain find for 'build'/'compile' (match anywhere in name)
-- 'check' requires a prefix separator so bare 'check' doesn't match
local make_build_patterns = {
  { pattern = 'build', plain = true },
  { pattern = 'compile', plain = true },
  { pattern = '[_-]check', plain = false },
}

--- parse Makefile and extract build-related targets
---@param makefile_path string
---@return string[] targets
local function parse_make_build_targets(makefile_path)
  local lines = vim.fn.readfile(makefile_path)
  if not lines or #lines == 0 then
    return {}
  end

  local targets = {}
  local seen = {}
  for _, line in ipairs(lines) do
    -- match target definitions: `target-name:` at start of line
    -- exclude .PHONY, .DEFAULT_GOAL, etc (dot-prefixed)
    local target = line:match '^([a-zA-Z][a-zA-Z0-9_-]*):'
    if target then
      local name_lower = target:lower()
      for _, p in ipairs(make_build_patterns) do
        if name_lower:find(p.pattern, 1, p.plain) and not seen[target] then
          seen[target] = true
          table.insert(targets, target)
          break
        end
      end
    end
  end
  -- sort by fewest segments (hyphens) so broader targets appear first
  table.sort(targets, function(a, b)
    local _, a_seps = a:gsub('-', '')
    local _, b_seps = b:gsub('-', '')
    if a_seps ~= b_seps then
      return a_seps < b_seps
    end
    return a < b
  end)
  return targets
end

--- resolve a build config's cmd for a given directory
--- cmd can be a static table or a function(dir) returning a table
---@param cfg table
---@param dir string
---@return table resolved config with cmd as table and build_dir set
local function resolve_config(cfg, dir)
  local cmd = type(cfg.cmd) == 'function' and cfg.cmd(dir) or cfg.cmd
  return { cmd = cmd, efm = cfg.efm, build_dir = dir }
end

--- check a directory for any language-specific marker
---@param dir string
---@return table|nil resolved config with build_dir
local function check_dir_for_markers(dir)
  for _, cfg in ipairs(build_configs) do
    if cfg.marker:find '%*' then
      local matches = vim.fn.glob(dir .. '/' .. cfg.marker, false, true)
      if #matches > 0 then
        return resolve_config(cfg, dir)
      end
    else
      if vim.fn.filereadable(dir .. '/' .. cfg.marker) == 1 then
        return resolve_config(cfg, dir)
      end
    end
  end
  return nil
end

--- detect project type and return build config
--- walks up from the current buffer's directory to find the nearest
--- language-specific marker before falling back to Makefile targets
---@return table|nil config, boolean|nil is_makefile
local function detect_build()
  local cwd = vim.fn.getcwd()

  -- walk up from current buffer dir to cwd looking for language markers.
  -- only attempt for normal file buffers; special buffers (neo-tree, oil,
  -- terminal, dashboard, etc) can return nonsensical paths from expand()
  if vim.bo.buftype == '' then
    local buf_file = vim.fn.expand '%:p'
    if buf_file ~= '' and buf_file:find(cwd, 1, true) == 1 then
      local dir = vim.fn.fnamemodify(buf_file, ':h')
      while #dir >= #cwd do
        local cfg = check_dir_for_markers(dir)
        if cfg then
          return cfg, false
        end
        local parent = vim.fn.fnamemodify(dir, ':h')
        if parent == dir then
          break
        end
        dir = parent
      end
    end
  end

  -- no marker found from buffer walk, check cwd itself
  local cfg = check_dir_for_markers(cwd)
  if cfg then
    return cfg, false
  end

  -- check for Makefile with build targets
  local makefile_path = cwd .. '/Makefile'
  if vim.fn.filereadable(makefile_path) == 1 then
    local targets = parse_make_build_targets(makefile_path)
    if #targets > 0 then
      return { makefile_path = makefile_path, targets = targets }, true
    end
  end

  return nil, nil
end

--- strip ANSI escape codes from a string
---@param str string
---@return string
local function strip_ansi(str)
  return (str:gsub('\027%[[%d;]*m', ''))
end

--- detect whether a command argument is a filesystem path.
--- used only for shortening notification text; execution still uses the full cmd
---@param arg string
---@return boolean
local function is_path_arg(arg)
  return arg:find '^/' or arg:find '^%./' or arg:find '^%.%./' or arg:find '^~/' or arg:find('/', 1, true)
end

--- format a command for notifications without noisy path arguments
---@param cmd string[]
---@return string
local function format_cmd_for_display(cmd)
  local parts = {}
  for _, arg in ipairs(cmd) do
    if not is_path_arg(arg) then
      table.insert(parts, arg)
    end
  end
  return table.concat(parts, ' ')
end

--- create a fidget progress handle for builds if the plugin is available
---@param cmd_str string
---@return table|nil
local function start_build_progress(cmd_str)
  local ok, progress = pcall(require, 'fidget.progress')
  if not ok then
    return nil
  end

  return progress.handle.create {
    message = cmd_str,
    lsp_client = { name = 'build' },
  }
end

-- directories to skip when hunting for a real path in a monorepo
local ignore_dirs = { ['node_modules'] = true, ['.git'] = true, ['dist'] = true, ['build'] = true, ['.next'] = true, ['.turbo'] = true }

--- search for cand inside build_dir up to `max_depth` subdirs deep,
--- skipping heavy/irrelevant directories (node_modules, .git, etc)
---@param build_dir string
---@param cand string relative path from some package root
---@param max_depth integer
---@return string|nil absolute path if exactly one match is found
local function search_monorepo(build_dir, cand, max_depth)
  local found
  local function walk(dir, depth)
    if found ~= nil or depth > max_depth then
      return
    end
    local handle = vim.loop.fs_scandir(dir)
    if not handle then
      return
    end
    while true do
      local n, t = vim.loop.fs_scandir_next(handle)
      if not n then
        break
      end
      if t == 'directory' and not ignore_dirs[n] and n:sub(1, 1) ~= '.' then
        local sub = dir .. '/' .. n
        local candidate = sub .. '/' .. cand
        if vim.fn.filereadable(candidate) == 1 then
          if found then
            found = false -- ambiguous: more than one match, give up
            return
          end
          found = candidate
        end
        walk(sub, depth + 1)
      end
    end
  end
  walk(build_dir, 1)
  return found or nil
end

--- find the real path for a filename that efm captured with a runner prefix
--- (e.g. turbo's "@scope/pkg:task: src/foo.ts"). tries progressive strips of
--- "<prefix>: " chunks, resolving each candidate against build_dir directly
--- and then searching its subdirectories (common monorepo package layout)
---@param name string filename as stored on the qf item's buffer
---@param build_dir string directory the build ran in
---@return string|nil absolute path if a real file is found
local function resolve_real_path(name, build_dir)
  local function try(p)
    if p == '' then
      return nil
    end
    if p:sub(1, 1) ~= '/' then
      p = build_dir .. '/' .. p
    end
    return vim.fn.filereadable(p) == 1 and p or nil
  end

  local candidates = { name }
  local current = name
  while true do
    local rest = current:match '^.-:%s+(.+)$'
    if not rest or rest == current then
      break
    end
    current = rest
    table.insert(candidates, current)
  end

  for _, cand in ipairs(candidates) do
    local direct = try(cand)
    if direct then
      return direct
    end
    if cand:sub(1, 1) ~= '/' then
      local found = search_monorepo(build_dir, cand, 3)
      if found then
        return found
      end
    end
  end

  -- fallback: when `setqflist({lines=...})` parses build output it resolves relative
  -- filenames against nvim's CWD, not the build tool's CWD (build_dir). in monorepos
  -- where the build subdirectory differs from the project root (e.g. a `web/` workspace
  -- inside the git root) this produces absolute paths missing the subdirectory prefix.
  -- strip the nvim CWD prefix to recover the relative portion and re-resolve against
  -- build_dir
  local nvim_cwd = vim.fn.getcwd() .. '/'
  for _, cand in ipairs(candidates) do
    if cand:sub(1, #nvim_cwd) == nvim_cwd then
      local rel = cand:sub(#nvim_cwd + 1)
      local direct = try(rel)
      if direct then
        return direct
      end
      local found = search_monorepo(build_dir, rel, 3)
      if found then
        return found
      end
    end
  end

  return nil
end

--- repair qf items whose filenames were polluted by task-runner prefixes.
--- memoizes per unique source name so a repeated prefix is stat'd once
---@param items table[]
---@param build_dir string
---@return table[] items with repaired bufnrs (unresolvable entries marked invalid)
local function repair_qf_paths(items, build_dir)
  local cache = {}
  for _, item in ipairs(items) do
    if item.valid == 1 and item.bufnr and item.bufnr > 0 then
      local name = vim.api.nvim_buf_get_name(item.bufnr)
      if name ~= '' and vim.fn.filereadable(name) ~= 1 then
        local fixed = cache[name]
        if fixed == nil then
          fixed = resolve_real_path(name, build_dir) or false
          cache[name] = fixed
        end
        if fixed then
          item.bufnr = vim.fn.bufadd(fixed)
        else
          item.valid = 0
          item.bufnr = 0 -- prevent navigation to the wrong empty buffer
        end
      end
    end
  end
  return items
end

--- deduplicate quickfix items produced from build output
---@param items table[]
---@return table[]
local function dedupe_qf_items(items)
  local seen = {}
  local deduped = {}

  for _, item in ipairs(items) do
    local file = item.filename or ''
    if file == '' and item.bufnr and item.bufnr > 0 then
      file = vim.api.nvim_buf_get_name(item.bufnr)
    end

    local key = table.concat({
      item.valid or 0,
      file,
      item.lnum or 0,
      item.end_lnum or 0,
      item.col or 0,
      item.end_col or 0,
      item.type or '',
      item.nr or '',
      item.text or '',
    }, ':')

    if not seen[key] then
      seen[key] = true
      table.insert(deduped, item)
    end
  end

  return deduped
end

--- run async build and populate quickfix list, then open the quickfix window
---@param cfg table Build config with cmd and optional efm
local function run_build(cfg)
  local cmd_str = format_cmd_for_display(cfg.cmd)
  local progress = start_build_progress(cmd_str)

  vim.system(
    cfg.cmd,
    {
      text = true,
      cwd = cfg.build_dir or vim.fn.getcwd(),
    },
    vim.schedule_wrap(function(result)
      local output = strip_ansi((result.stdout or '') .. (result.stderr or ''))
      local lines = vim.split(output, '\n', { trimempty = true })

      -- build succeeded
      if result.code == 0 then
        if progress then
          progress:finish()
        end
        vim.notify('Build succeeded', vim.log.levels.INFO, { title = 'Build', timeout = 3000 })
        return
      end

      -- build failed but no output
      if #lines == 0 then
        if progress then
          progress:finish()
        end
        vim.notify('Failed (exit ' .. result.code .. '): ' .. cmd_str, vim.log.levels.ERROR, { title = 'Build', timeout = 3000 })
        return
      end

      -- parse output into quickfix entries
      local qf_opts = { title = 'Build: ' .. cmd_str, lines = lines }
      if cfg.efm then
        qf_opts.efm = cfg.efm
      end
      vim.fn.setqflist({}, 'r', qf_opts)

      local qf_items = dedupe_qf_items(vim.fn.getqflist())

      -- check ORIGINAL validity before repair: if efm matched nothing,
      -- the tool was probably just noisy (e.g. bun echoing scripts) and
      -- we treat a non-zero exit as success
      local has_valid = false
      for _, item in ipairs(qf_items) do
        if item.valid == 1 then
          has_valid = true
          break
        end
      end

      qf_items = repair_qf_paths(qf_items, cfg.build_dir or vim.fn.getcwd())
      vim.fn.setqflist({}, 'r', { title = 'Build: ' .. cmd_str, items = qf_items })
      if not has_valid then
        if progress then
          progress:finish()
        end
        vim.notify('Build succeeded', vim.log.levels.INFO, { title = 'Build', timeout = 3000 })
        return
      end

      if progress then
        progress:finish()
      end
      vim.notify('Failed — ' .. #lines .. ' line(s): ' .. cmd_str, vim.log.levels.ERROR, { title = 'Build', timeout = 3000 })
      vim.cmd 'botright copen'
    end)
  )
end

--- build a combined efm from all build_configs (most specific patterns first)
--- used for Makefile targets where the underlying tool is unknown.
--- strips %-G%.%# (catch-all ignore) from individual efms so earlier configs
--- don't swallow lines that later configs need to match
---@return string combined errorformat
local function combined_efm()
  local parts = {}
  for _, cfg in ipairs(build_configs) do
    -- remove catch-all ignore patterns that would short-circuit later configs
    local efm = cfg.efm:gsub(',?%%%-G%%.%%#', '')
    if efm ~= '' then
      table.insert(parts, efm)
    end
  end
  -- single catch-all at the very end, after all patterns have been tried
  table.insert(parts, '%-G%.%#')
  return table.concat(parts, ',')
end

--- show make target picker and run selected target
---@param targets string[]
local function pick_make_target(targets)
  local efm = combined_efm()

  -- single target, run directly without sub-picker
  if #targets == 1 then
    run_build { cmd = { 'make', targets[1] }, efm = efm }
    return
  end

  vim.ui.select(targets, {
    prompt = 'Make target',
    format_item = function(target)
      for i, t in ipairs(targets) do
        if t == target then
          return i .. '. make ' .. target
        end
      end
      return 'make ' .. target
    end,
  }, function(target)
    if not target then
      return
    end
    run_build { cmd = { 'make', target }, efm = efm }
  end)
end

--- run project build (auto-detects project type)
function M.run()
  local cfg, is_makefile = detect_build()
  if not cfg then
    vim.notify('No build config detected (go.mod, vite.config.*, tsconfig.json, *.csproj, Makefile)', vim.log.levels.WARN)
    return
  end
  if is_makefile then
    pick_make_target(cfg.targets)
  else
    run_build(cfg)
  end
end

--- run the Makefile build picker directly, bypassing language-specific detection
function M.run_make()
  local cwd = vim.fn.getcwd()
  local makefile_path = cwd .. '/Makefile'
  if vim.fn.filereadable(makefile_path) ~= 1 then
    vim.notify('No Makefile in ' .. cwd, vim.log.levels.WARN)
    return
  end
  local targets = parse_make_build_targets(makefile_path)
  if #targets == 0 then
    vim.notify('No build targets found in Makefile', vim.log.levels.WARN)
    return
  end
  pick_make_target(targets)
end

--- prune diagnostics-backed qf entries as the underlying issues are fixed.
--- fires on DiagnosticChanged: for a loaded buffer with an LSP attached,
--- drops qf items that no longer have a matching live diagnostic. triggers
--- on titles starting with "<Kind>:" where Kind is in AUTO_CLEAR_KINDS.
---
--- the `match` field selects how an item is matched against live diagnostics:
---   - 'line'      : drop if no diagnostic exists on the same line. used for
---                   Build entries, which come from compiler output and don't
---                   carry the `[source]` text prefix that the diagnostic
---                   lists use.
---   - 'line_text' : drop unless a live diagnostic has the same (lnum, text)
---                   tuple. used for Sonar/Modified/Diagnostics, where items
---                   are built via scan_runner.diag_to_item and carry a
---                   `[source] message` text. stops stale entries surviving
---                   just because an unrelated diagnostic landed on the row.
local AUTO_CLEAR_KINDS = {
  Build = { label = 'Build errors resolved', match = 'line' },
  Sonar = { label = 'Sonar issues resolved', match = 'line_text' },
  Modified = { label = 'Modified file diagnostics resolved', match = 'line_text' },
  Ticket = { label = 'Ticket diagnostics resolved', match = 'line_text' },
  Diagnostics = { label = 'Diagnostics resolved', match = 'line_text' },
}

--- prune diagnostic-backed items from `list` for `bufnr`. returns
--- (kind, label) when the list ends up empty so the caller can close
--- the window and notify; returns nil when nothing was dropped or the
--- title isn't in AUTO_CLEAR_KINDS.
---
--- preserves the list's current-entry idx across the rebuild: if the
--- entry the user was pointed at survives, it stays current; if it was
--- the one just resolved, idx snaps to the nearest surviving predecessor
--- so the next ]q advances forward to the next outstanding issue rather
--- than jumping back to entry 1 (setqflist's default after replace).
local function prune_diag_list(list, replace, set_idx, bufnr, lookups)
  if not list.title then
    return
  end
  local kind = list.title:match '^(%w+):'
  local info = kind and AUTO_CLEAR_KINDS[kind]
  if not info then
    return
  end
  local lookup = lookups[info.match]

  local kept = {}
  local old_to_new = {}
  local dropped = 0
  for i, item in ipairs(list.items) do
    local key = info.match == 'line_text' and (item.lnum .. '\0' .. (item.text or '')) or item.lnum
    if item.bufnr == bufnr and item.valid == 1 and not lookup[key] then
      dropped = dropped + 1
    else
      table.insert(kept, item)
      old_to_new[i] = #kept
    end
  end

  if dropped == 0 then
    return
  end

  replace { title = list.title, items = kept }

  if #kept == 0 then
    return kind, info.label
  end

  if list.idx and list.idx > 0 then
    local new_idx = old_to_new[list.idx]
    if not new_idx then
      for i = list.idx - 1, 1, -1 do
        if old_to_new[i] then
          new_idx = old_to_new[i]
          break
        end
      end
    end
    if new_idx then
      set_idx(new_idx)
    end
  end
end

-- per-buffer baseline of `changedtick` recorded on the first DiagnosticChanged
-- we observe. auto-clear is gated on the tick having advanced past the
-- baseline, i.e. the user has actually edited the buffer since we first saw
-- it. without this, a `]q` jump into a fresh buffer fires the LSP's initial
-- publish, whose line set may not overlap with the qf entries' source (build
-- output, sonar scan, modified-scan snapshot), and the prune wipes still-valid
-- entries that the user hasn't fixed.
local first_seen_tick = {}

local function setup_auto_clear()
  local group = vim.api.nvim_create_augroup('CustomBuildAutoClear', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
    group = group,
    callback = function(args)
      first_seen_tick[args.buf] = nil
    end,
  })

  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      if not vim.api.nvim_buf_is_loaded(bufnr) then
        return
      end
      if #vim.lsp.get_clients { bufnr = bufnr } == 0 then
        return
      end

      local tick = vim.b[bufnr].changedtick
      local baseline = first_seen_tick[bufnr]
      if baseline == nil then
        first_seen_tick[bufnr] = tick
        return
      end
      if tick <= baseline then
        return
      end

      local lines_with_diag = {}
      local diag_keys = {}
      for _, d in ipairs(vim.diagnostic.get(bufnr)) do
        local lnum = d.lnum + 1
        lines_with_diag[lnum] = true
        diag_keys[lnum .. '\0' .. scan_runner.qf_text(d)] = true
      end
      local lookups = { line = lines_with_diag, line_text = diag_keys }

      -- quickfix list
      local qf = vim.fn.getqflist { title = 0, items = 0, idx = 0 }
      local qf_kind, qf_label = prune_diag_list(qf, function(d)
        vim.fn.setqflist({}, 'r', d)
      end, function(idx)
        vim.fn.setqflist({}, 'a', { idx = idx })
      end, bufnr, lookups)
      if qf_kind then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local b = vim.api.nvim_win_get_buf(win)
          local info = vim.fn.getwininfo(win)[1]
          if vim.bo[b].buftype == 'quickfix' and info and info.loclist == 0 then
            vim.api.nvim_win_close(win, true)
          end
        end
        vim.notify(qf_label, vim.log.levels.INFO, { title = qf_kind, timeout = 3000 })
      end

      -- per-window location lists. skip qf/loclist windows themselves to
      -- avoid double-processing (their getloclist points back to the parent)
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(win)
        if vim.bo[b].buftype ~= 'quickfix' then
          local loc = vim.fn.getloclist(win, { title = 0, items = 0, idx = 0 })
          local loc_kind, loc_label = prune_diag_list(loc, function(d)
            vim.fn.setloclist(win, {}, 'r', d)
          end, function(idx)
            vim.fn.setloclist(win, {}, 'a', { idx = idx })
          end, bufnr, lookups)
          if loc_kind then
            vim.api.nvim_win_call(win, function()
              vim.cmd 'lclose'
            end)
            vim.notify(loc_label, vim.log.levels.INFO, { title = loc_kind, timeout = 3000 })
          end
        end
      end
    end,
  })
end

function M.setup()
  vim.keymap.set('n', '<leader>q', M.run, { desc = 'Build project or pick Make target' })
  vim.keymap.set('n', '<leader>Q', M.run_make, { desc = 'Pick Make target' })
  setup_auto_clear()
end

return M
