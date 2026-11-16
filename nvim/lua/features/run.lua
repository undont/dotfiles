-- one picker over runnable commands (build, make, scripts, tests, dotnet,
-- scans), most recently run first per cwd. <leader>Q reruns the last pick

local M = {}

---@class RunEntry
---@field name string `<kind>: <label>`, also the history key
---@field run fun()

local HISTORY_PATH = vim.fn.stdpath 'state' .. '/run-history.json'
local HISTORY_LIMIT = 50

---@type RunEntry|nil
local last

---@return table<string, string[]> names keyed by cwd, most recent first
local function read_history()
  local fh = io.open(HISTORY_PATH, 'r')
  if not fh then
    return {}
  end
  local ok, data = pcall(vim.json.decode, fh:read '*a')
  fh:close()
  if not ok or type(data) ~= 'table' then
    return {}
  end
  return data
end

---@param name string
local function record(name)
  local history = read_history()
  local cwd = vim.fn.getcwd()
  local names = { name }
  for _, n in ipairs(history[cwd] or {}) do
    if n ~= name and #names < HISTORY_LIMIT then
      table.insert(names, n)
    end
  end
  history[cwd] = names
  local fh = io.open(HISTORY_PATH, 'w')
  if fh then
    fh:write(vim.json.encode(history))
    fh:close()
  end
end

---@return RunEntry[]
local function test_entries()
  -- .cs tests run through easy-dotnet (plugins/dotnet.lua)
  if vim.bo.filetype == 'cs' then
    return {}
  end
  local file = vim.fn.expand '%'
  return {
    {
      name = 'test: run all',
      run = function()
        require('neotest').run.run { suite = true }
      end,
    },
    {
      name = 'test: toggle watch (file)',
      run = function()
        require('neotest').watch.toggle(file)
      end,
    },
    {
      name = 'test: debug nearest',
      run = function()
        require('neotest').run.run { strategy = 'dap' }
      end,
    },
  }
end

---@return RunEntry[]
local function dotnet_entries()
  -- easy-dotnet loads on the first .cs buffer and registers :Dotnet then
  if not package.loaded['easy-dotnet'] then
    return {}
  end
  local entries = {}
  for _, sub in ipairs { 'build', 'run', 'watch', 'clean', 'secrets', 'new', 'outdated' } do
    table.insert(entries, {
      name = 'dotnet: ' .. sub,
      run = function()
        vim.cmd('Dotnet ' .. sub)
      end,
    })
  end
  return entries
end

---@return RunEntry[]
local function sonar_entries()
  local modes = { { 'changed', 'modified' }, { 'branch', 'branch vs main' }, { 'ticket', 'ticket commits' }, { 'all', 'whole project' } }
  local entries = {}
  for _, m in ipairs(modes) do
    table.insert(entries, {
      name = 'sonar: ' .. m[2],
      run = function()
        require('lazy').load { plugins = { 'sonarlint.nvim' } }
        require('features.sonar-scan').run_scan(m[1])
      end,
    })
  end
  return entries
end

local providers = {
  function()
    return require('features.build').entries()
  end,
  test_entries,
  dotnet_entries,
  function()
    return require('features.diag-scan').entries()
  end,
  sonar_entries,
}

---@return RunEntry[]
local function collect()
  local entries = {}
  for _, provider in ipairs(providers) do
    vim.list_extend(entries, provider())
  end
  return entries
end

---@param entry RunEntry
local function run_entry(entry)
  last = entry
  record(entry.name)
  entry.run()
end

local function pick()
  local entries = collect()
  local rank = {}
  for i, name in ipairs(read_history()[vim.fn.getcwd()] or {}) do
    rank[name] = i
  end
  local order = {}
  for i, entry in ipairs(entries) do
    order[entry] = i
  end
  table.sort(entries, function(a, b)
    local ra, rb = rank[a.name] or math.huge, rank[b.name] or math.huge
    if ra ~= rb then
      return ra < rb
    end
    return order[a] < order[b]
  end)

  vim.ui.select(entries, {
    prompt = 'Run',
    format_item = function(entry)
      return entry.name
    end,
  }, function(entry)
    if entry then
      run_entry(entry)
    end
  end)
end

--- the last pick this session, else the cwd's most recent history entry
--- resolved against what is runnable now
local function rerun()
  if last then
    run_entry(last)
    return
  end
  local recent = (read_history()[vim.fn.getcwd()] or {})[1]
  if recent then
    for _, entry in ipairs(collect()) do
      if entry.name == recent then
        run_entry(entry)
        return
      end
    end
  end
  vim.notify('Nothing to rerun', vim.log.levels.INFO)
end

function M.setup()
  vim.keymap.set('n', '<leader>q', pick, { desc = 'Run picker (build, make, tests, scans)' })
  vim.keymap.set('n', '<leader>Q', rerun, { desc = 'Rerun last pick' })
end

return M
