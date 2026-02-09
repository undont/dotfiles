-- Quickfix picker: buffer diagnostics, workspace diagnostics, or async project build

local M = {}

-- Build commands keyed by root marker file
-- Each entry: { marker = file/pattern to detect, cmd = build command, efm = errorformat }
local build_configs = {
  {
    marker = 'go.mod',
    cmd = { 'go', 'vet', './...' },
    efm = '%f:%l:%c: %m,%f:%l: %m',
  },
  {
    marker = 'tsconfig.json',
    cmd = { 'npx', 'tsc', '--noEmit', '--pretty', 'false' },
    efm = '%f(%l\\,%c): error TS%n: %m,%f(%l\\,%c): warning TS%n: %m',
  },
  {
    marker = '*.csproj',
    cmd = { 'dotnet', 'build', '--no-restore', '-consoleloggerparameters:NoSummary' },
    efm = '%f(%l\\,%c): %trror %m,%f(%l\\,%c): %tarning %m',
  },
  {
    marker = 'Makefile',
    cmd = { 'make' },
    efm = nil, -- uses Neovim default errorformat
  },
}

--- Detect project type from cwd and return build config
---@return table|nil
local function detect_build()
  local cwd = vim.fn.getcwd()
  for _, cfg in ipairs(build_configs) do
    -- Check for glob patterns (e.g. *.csproj)
    if cfg.marker:find '%*' then
      local matches = vim.fn.glob(cwd .. '/' .. cfg.marker, false, true)
      if #matches > 0 then
        return cfg
      end
    else
      if vim.fn.filereadable(cwd .. '/' .. cfg.marker) == 1 then
        return cfg
      end
    end
  end
  return nil
end

--- Run async build and populate quickfix list
---@param cfg table Build config from detect_build()
local function run_build(cfg)
  local cmd_str = table.concat(cfg.cmd, ' ')
  vim.notify('Building: ' .. cmd_str, vim.log.levels.INFO)

  vim.system(cfg.cmd, {
    text = true,
    cwd = vim.fn.getcwd(),
  }, vim.schedule_wrap(function(result)
    local output = (result.stdout or '') .. (result.stderr or '')
    local lines = vim.split(output, '\n', { trimempty = true })

    if #lines == 0 then
      vim.notify('Build clean — no issues found', vim.log.levels.INFO)
      return
    end

    local qf_opts = { title = 'Build: ' .. cmd_str, lines = lines }
    if cfg.efm then
      qf_opts.efm = cfg.efm
    end
    vim.fn.setqflist({}, 'r', qf_opts)
    vim.cmd 'copen'
  end))
end

--- Show quickfix picker
function M.pick()
  local options = {
    { label = 'Buffer diagnostics', value = 'buffer' },
    { label = 'Workspace diagnostics', value = 'workspace' },
    { label = 'Build project', value = 'build' },
  }

  vim.ui.select(options, {
    prompt = 'Quickfix',
    format_item = function(item)
      for i, opt in ipairs(options) do
        if opt == item then
          return i .. '. ' .. item.label
        end
      end
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end

    if choice.value == 'buffer' then
      vim.diagnostic.setqflist {
        severity = { min = vim.diagnostic.severity.WARN },
        open = true,
      }

    elseif choice.value == 'workspace' then
      vim.diagnostic.setqflist {
        severity = { min = vim.diagnostic.severity.WARN },
      }

    elseif choice.value == 'build' then
      local cfg = detect_build()
      if not cfg then
        vim.notify('No build config detected (go.mod, tsconfig.json, *.csproj, Makefile)', vim.log.levels.WARN)
        return
      end
      run_build(cfg)
    end
  end)
end

return M
