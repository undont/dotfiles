-- async project build: detect project type, run build, populate quickfix

local M = {}

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

--- the project's `check` script (eslint + tsc)
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

--- a solution between the .csproj directory and cwd wins over the project
---@param csproj_dir string directory containing the matched .csproj
---@return string target path to build
local function find_dotnet_target(csproj_dir)
  local cwd = vim.fn.getcwd()
  local dir = csproj_dir

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
    marker = 'Cargo.toml',
    -- short format puts each diagnostic on one line; the default spans several
    cmd = { 'cargo', 'check', '--all-targets', '--message-format=short' },
    efm = '%f:%l:%c: %trror[E%n]: %m,%f:%l:%c: %trror: %m,%f:%l:%c: %tarning: %m,%-G%.%#',
  },
  {
    marker = 'build.zig',
    cmd = { 'zig', 'build' },
    efm = '%f:%l:%c: %trror: %m,%-G%.%#',
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

-- substrings that mark a make target or package script as a build, so bare
-- 'check' and prefixed variants ('typecheck', 'lint-check') both match. the
-- runner waits for exit, so a server or watcher (`dev`, `serve`) stays out
local build_name_parts = { 'build', 'compile', 'check' }

---@param names string[]
---@return string[] build names, broader (fewer hyphens) first
local function build_names(names)
  local targets = {}
  local seen = {}
  for _, name in ipairs(names) do
    local name_lower = name:lower()
    -- the conventional default goal, matched whole so 'install' stays out
    if name_lower == 'all' and not seen[name] then
      seen[name] = true
      table.insert(targets, name)
    end
    for _, part in ipairs(build_name_parts) do
      if name_lower:find(part, 1, true) and not seen[name] then
        seen[name] = true
        table.insert(targets, name)
        break
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

---@param makefile_path string
---@return string[] targets
local function parse_make_build_targets(makefile_path)
  local names = {}
  for _, line in ipairs(vim.fn.readfile(makefile_path)) do
    -- `target-name:` at line start; dot-prefixed specials (.PHONY) excluded
    local target = line:match '^([a-zA-Z][a-zA-Z0-9_-]*):'
    if target then
      table.insert(names, target)
    end
  end
  return build_names(names)
end

---@param cfg table
---@param dir string
---@return table resolved config with cmd as table and build_dir set
local function resolve_config(cfg, dir)
  local cmd = type(cfg.cmd) == 'function' and cfg.cmd(dir) or cfg.cmd
  return { cmd = cmd, efm = cfg.efm, build_dir = dir }
end

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

--- the current buffer's directory up to cwd, nearest first. cwd alone for
--- special buffers (neo-tree, oil, terminal, dashboard), whose expand() paths
--- are unusable, and for files outside cwd
---@return string[]
local function search_dirs()
  local cwd = vim.fn.getcwd()
  local dirs = {}
  local buf_file = vim.bo.buftype == '' and vim.fn.expand '%:p' or ''
  if buf_file ~= '' and buf_file:find(cwd, 1, true) == 1 then
    local dir = vim.fn.fnamemodify(buf_file, ':h')
    while #dir > #cwd do
      table.insert(dirs, dir)
      local parent = vim.fn.fnamemodify(dir, ':h')
      if parent == dir then
        break
      end
      dir = parent
    end
  end
  table.insert(dirs, cwd)
  return dirs
end

---@return table|nil config for the nearest language-specific marker
local function detect_build()
  for _, dir in ipairs(search_dirs()) do
    local cfg = check_dir_for_markers(dir)
    if cfg then
      return cfg
    end
  end
  return nil
end

---@return string|nil dir of the nearest package.json, string[] its build scripts
local function package_scripts()
  for _, dir in ipairs(search_dirs()) do
    local path = dir .. '/package.json'
    if vim.fn.filereadable(path) == 1 then
      local ok, pkg = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
      if not ok or type(pkg) ~= 'table' or type(pkg.scripts) ~= 'table' then
        return dir, {}
      end
      return dir, build_names(vim.tbl_keys(pkg.scripts))
    end
  end
  return nil, {}
end

---@param str string
---@return string
local function strip_ansi(str)
  return (str:gsub('\027%[[%d;]*m', ''))
end

--- only shortens notification text; execution uses the full cmd
---@param arg string
---@return boolean
local function is_path_arg(arg)
  return arg:find '^/' or arg:find '^%./' or arg:find '^%.%./' or arg:find '^~/' or arg:find('/', 1, true)
end

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

  -- `setqflist({lines=...})` resolves relative filenames against nvim's cwd, not
  -- build_dir, so a build run in a subdirectory yields absolute paths missing that
  -- subdirectory. strip the nvim cwd prefix and re-resolve against build_dir
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

--- `vim.g.build_cmd_prefix`, set per project from an exrc `.nvim.lua`, runs
--- every build through another command, e.g.
--- `{ 'docker', 'exec', '-w', '{dir}', 'ctr' }`; `{dir}` is the build dir
---@param cmd string[]
---@param build_dir string
---@return string[]
local function with_cmd_prefix(cmd, build_dir)
  local prefix = vim.g.build_cmd_prefix
  if type(prefix) ~= 'table' then
    return cmd
  end
  local full = {}
  for _, arg in ipairs(prefix) do
    table.insert(full, arg == '{dir}' and build_dir or arg)
  end
  return vim.list_extend(full, cmd)
end

---@return boolean
local function current_list_is_build()
  return vim.fn.getqflist({ title = 0 }).title:find '^Build:' ~= nil
end

--- replaces a previous build list in place, otherwise pushes a new list so
--- the current one stays reachable with :colder
---@param title string
---@param items table[]
local function set_build_list(title, items)
  local action = current_list_is_build() and 'r' or ' '
  vim.fn.setqflist({}, action, { title = title, items = items })
end

local function report_clean_build()
  if current_list_is_build() then
    vim.fn.setqflist({}, 'r', { items = {} })
    -- E444 when the qf window is the tab's only non-floating window
    local splits = vim.tbl_filter(function(win)
      return vim.api.nvim_win_get_config(win).relative == ''
    end, vim.api.nvim_tabpage_list_wins(0))
    if #splits > 1 then
      vim.cmd 'cclose'
    end
  end
  vim.notify('Build succeeded', vim.log.levels.INFO, { title = 'Build', timeout = 3000 })
end

---@param cfg table Build config with cmd and optional efm
local function run_build(cfg)
  local cmd_str = format_cmd_for_display(cfg.cmd)
  local progress = start_build_progress(cmd_str)
  local build_dir = cfg.build_dir or vim.fn.getcwd()

  vim.system(
    with_cmd_prefix(cfg.cmd, build_dir),
    {
      text = true,
      cwd = build_dir,
    },
    vim.schedule_wrap(function(result)
      if progress then
        progress:finish()
      end
      local output = strip_ansi((result.stdout or '') .. (result.stderr or ''))
      local lines = vim.split(output, '\n', { trimempty = true })
      local title = 'Build: ' .. cmd_str
      local succeeded = result.code == 0

      if #lines == 0 then
        if succeeded then
          report_clean_build()
        else
          vim.notify('Failed (exit ' .. result.code .. '): ' .. cmd_str, vim.log.levels.ERROR, { title = 'Build', timeout = 3000 })
        end
        return
      end

      local qf_items = dedupe_qf_items(vim.fn.getqflist({ lines = lines, efm = cfg.efm }).items)

      -- validity is read before repair, which can invalidate an unresolvable item
      local valid_count = 0
      for _, item in ipairs(qf_items) do
        if item.valid == 1 then
          valid_count = valid_count + 1
        end
      end

      if succeeded and valid_count == 0 then
        report_clean_build()
        return
      end

      if succeeded then
        set_build_list(title, repair_qf_paths(qf_items, build_dir))
        vim.notify('Succeeded, ' .. valid_count .. ' warning(s): ' .. cmd_str, vim.log.levels.WARN, { title = 'Build', timeout = 3000 })
      elseif valid_count > 0 then
        set_build_list(title, repair_qf_paths(qf_items, build_dir))
        vim.notify('Failed, ' .. #lines .. ' line(s): ' .. cmd_str, vim.log.levels.ERROR, { title = 'Build', timeout = 3000 })
      else
        -- nothing parsed (a link error, a stopped container): the raw output as
        -- text entries, which qf-auto-clear never prunes
        local raw = {}
        for _, line in ipairs(lines) do
          table.insert(raw, { text = line, valid = 0 })
        end
        set_build_list(title, raw)
        vim.notify('Failed (exit ' .. result.code .. '): ' .. cmd_str, vim.log.levels.ERROR, { title = 'Build', timeout = 3000 })
      end
      vim.cmd 'botright copen'
    end)
  )
end

-- gcc, clang and zig cc diagnostics, typed. ahead of go's untyped
-- `%f:%l:%c: %m`, which matches the same lines
local CC_EFM = '%f:%l:%c: %trror: %m,%f:%l:%c: %tarning: %m,%-G%f:%l:%c: note: %m'

--- efm for Makefile targets, where the underlying tool is unknown: CC_EFM, then
--- every build_configs efm in order, with each catch-all ignore (%-G%.%#)
--- replaced by one at the end so an earlier config can't swallow a later
--- config's lines
---@return string combined errorformat
local function combined_efm()
  local parts = { CC_EFM }
  for _, cfg in ipairs(build_configs) do
    local efm = cfg.efm:gsub(',?%%%-G%%.%%#', '')
    if efm ~= '' then
      table.insert(parts, efm)
    end
  end
  table.insert(parts, '%-G%.%#')
  return table.concat(parts, ',')
end

--- the detected build, then build-like Makefile targets and package scripts,
--- for the features/run.lua picker. duplicate commands keep their first entry
---@return RunEntry[]
function M.entries()
  local entries = {}
  local seen = {}
  local function add(cfg)
    local label = format_cmd_for_display(cfg.cmd)
    if seen[label] then
      return
    end
    seen[label] = true
    table.insert(entries, {
      name = 'build: ' .. label,
      run = function()
        run_build(cfg)
      end,
    })
  end

  local cfg = detect_build()
  if cfg then
    add(cfg)
  end

  local efm = combined_efm()
  local makefile_path = vim.fn.getcwd() .. '/Makefile'
  if vim.fn.filereadable(makefile_path) == 1 then
    for _, target in ipairs(parse_make_build_targets(makefile_path)) do
      add { cmd = { 'make', target }, efm = efm }
    end
  end

  local dir, scripts = package_scripts()
  if dir then
    local runner = detect_pkg_runner(dir)
    for _, script in ipairs(scripts) do
      add { cmd = { runner, 'run', script }, efm = efm, build_dir = dir }
    end
  end

  return entries
end

return M
