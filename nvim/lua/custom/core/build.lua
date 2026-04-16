-- Async project build: detect project type, run build, populate quickfix

local M = {}

--- Detect package manager from lockfile in a directory
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

--- Build tsc command using the detected package manager
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

--- Build check command (eslint + tsc) using the detected package manager
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

--- Find the best dotnet build target, preferring solutions over projects.
--- From the matched .csproj directory, walks up to cwd looking for .sln/.slnx.
---@param csproj_dir string directory containing the matched .csproj
---@return string target path to build
local function find_dotnet_target(csproj_dir)
  local cwd = vim.fn.getcwd()
  local dir = csproj_dir

  -- Walk up looking for a solution file
  while #dir >= #cwd do
    for _, ext in ipairs { '*.slnx', '*.sln' } do
      local matches = vim.fn.glob(dir .. '/' .. ext, false, true)
      for _, path in ipairs(matches) do
        -- Skip build variants (.ci.slnx, .build.sln, .test.sln, etc.)
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

  -- No solution found — use the .csproj directly
  local csproj = vim.fn.glob(csproj_dir .. '/*.csproj', false, true)
  return csproj[1] or csproj_dir
end

-- Build commands keyed by root marker file
-- Each entry: { marker, cmd (table or function(dir)->table), efm }
-- Checked in priority order — first match wins (unless Makefile, which extracts targets)
local build_configs = {
  {
    marker = 'go.mod',
    cmd = { 'go', 'vet', './...' },
    efm = 'vet: %f:%l:%c: %m,vet: %f:%l: %m,%f:%l:%c: %m,%f:%l: %m,%-G# %.%#,%-G%.%#',
  },
  {
    marker = 'vite.config.*',
    cmd = check_cmd, -- resolved at runtime from matched directory
    efm = '%f:%l:%c: ERROR: %m,%f:%l:%c: error: %m,%f:%l:%c: warning: %m,%-G%.%#',
  },
  {
    marker = 'tsconfig.json',
    cmd = tsc_cmd, -- resolved at runtime from matched directory
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

-- Lua patterns that indicate a build-related make target
-- Plain find for 'build'/'compile' (match anywhere in name)
-- 'check' requires a prefix separator so bare 'check' doesn't match
local make_build_patterns = {
  { pattern = 'build', plain = true },
  { pattern = 'compile', plain = true },
  { pattern = '[_-]check', plain = false },
}

--- Parse Makefile and extract build-related targets
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
    -- Match target definitions: `target-name:` at start of line
    -- Exclude .PHONY, .DEFAULT_GOAL, etc (dot-prefixed)
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
  -- Sort by fewest segments (hyphens) so broader targets appear first
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

--- Resolve a build config's cmd for a given directory
--- cmd can be a static table or a function(dir) returning a table
---@param cfg table
---@param dir string
---@return table resolved config with cmd as table and build_dir set
local function resolve_config(cfg, dir)
  local cmd = type(cfg.cmd) == 'function' and cfg.cmd(dir) or cfg.cmd
  return { cmd = cmd, efm = cfg.efm, build_dir = dir }
end

--- Check a directory for any language-specific marker
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

--- Detect project type and return build config
--- Walks up from the current buffer's directory to find the nearest
--- language-specific marker before falling back to Makefile targets
---@return table|nil config, boolean|nil is_makefile
local function detect_build()
  local cwd = vim.fn.getcwd()

  -- Walk up from current buffer dir to cwd looking for language markers.
  -- Only attempt for normal file buffers — special buffers (neo-tree, oil,
  -- terminal, dashboard, etc.) can return nonsensical paths from expand().
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

  -- No marker found from buffer walk — check cwd itself
  local cfg = check_dir_for_markers(cwd)
  if cfg then
    return cfg, false
  end

  -- Check for Makefile with build targets
  local makefile_path = cwd .. '/Makefile'
  if vim.fn.filereadable(makefile_path) == 1 then
    local targets = parse_make_build_targets(makefile_path)
    if #targets > 0 then
      return { makefile_path = makefile_path, targets = targets }, true
    end
  end

  return nil, nil
end

--- Strip ANSI escape codes from a string
---@param str string
---@return string
local function strip_ansi(str)
  return (str:gsub('\027%[[%d;]*m', ''))
end

--- Detect whether a command argument is a filesystem path.
--- Used only for shortening notification text; execution still uses the full cmd.
---@param arg string
---@return boolean
local function is_path_arg(arg)
  return arg:find '^/' or arg:find '^%./' or arg:find '^%.%./' or arg:find '^~/' or arg:find('/', 1, true)
end

--- Format a command for notifications without noisy path arguments.
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

--- Deduplicate quickfix items produced from build output.
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

--- Run async build and populate quickfix list, then open the quickfix window
---@param cfg table Build config with cmd and optional efm
local function run_build(cfg)
  local cmd_str = format_cmd_for_display(cfg.cmd)

  -- Show progress notification
  local notify_opts = { title = 'Build', timeout = false }
  local notify_id = vim.notify('Running: ' .. cmd_str, vim.log.levels.INFO, notify_opts)

  vim.system(
    cfg.cmd,
    {
      text = true,
      cwd = cfg.build_dir or vim.fn.getcwd(),
    },
    vim.schedule_wrap(function(result)
      local output = strip_ansi((result.stdout or '') .. (result.stderr or ''))
      local lines = vim.split(output, '\n', { trimempty = true })
      local replace_opts = { title = 'Build', replace = notify_id, timeout = 3000 }

      -- Build succeeded
      if result.code == 0 then
        vim.notify('Build succeeded', vim.log.levels.INFO, replace_opts)
        return
      end

      -- Build failed but no output
      if #lines == 0 then
        vim.notify('Failed (exit ' .. result.code .. '): ' .. cmd_str, vim.log.levels.ERROR, replace_opts)
        return
      end

      -- Parse output into quickfix entries
      local qf_opts = { title = 'Build: ' .. cmd_str, lines = lines }
      if cfg.efm then
        qf_opts.efm = cfg.efm
      end
      vim.fn.setqflist({}, 'r', qf_opts)

      local qf_items = dedupe_qf_items(vim.fn.getqflist())
      vim.fn.setqflist({}, 'r', { title = 'Build: ' .. cmd_str, items = qf_items })

      -- Check if any parsed entries have a valid file/line — if not, treat as success
      -- (e.g. bun echoes the command being run, producing output that doesn't match efm)
      local has_valid = false
      for _, item in ipairs(qf_items) do
        if item.valid == 1 then
          has_valid = true
          break
        end
      end
      if not has_valid then
        vim.notify('Build succeeded', vim.log.levels.INFO, replace_opts)
        return
      end

      vim.notify('Failed — ' .. #lines .. ' line(s): ' .. cmd_str, vim.log.levels.ERROR, replace_opts)
      vim.cmd 'botright copen'
    end)
  )
end

--- Build a combined efm from all build_configs (most specific patterns first)
--- Used for Makefile targets where the underlying tool is unknown.
--- Strips %-G%.%# (catch-all ignore) from individual efms so earlier configs
--- don't swallow lines that later configs need to match.
---@return string combined errorformat
local function combined_efm()
  local parts = {}
  for _, cfg in ipairs(build_configs) do
    -- Remove catch-all ignore patterns that would short-circuit later configs
    local efm = cfg.efm:gsub(',?%%%-G%%.%%#', '')
    if efm ~= '' then
      table.insert(parts, efm)
    end
  end
  -- Single catch-all at the very end, after all patterns have been tried
  table.insert(parts, '%-G%.%#')
  return table.concat(parts, ',')
end

--- Show make target picker and run selected target
---@param targets string[]
local function pick_make_target(targets)
  local efm = combined_efm()

  -- Single target — run directly without sub-picker
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

--- Run project build (auto-detects project type)
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

--- Run the Makefile build picker directly, bypassing language-specific detection.
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

function M.setup()
  vim.keymap.set('n', '<leader>q', M.run, { desc = 'Build project or pick Make target' })
  vim.keymap.set('n', '<leader>Q', M.run_make, { desc = 'Pick Make target' })
end

return M
