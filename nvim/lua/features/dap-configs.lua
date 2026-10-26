-- dap adapters and launch/attach configurations per language

local M = {}

local mason_packages = vim.fn.stdpath 'data' .. '/mason/packages'

local function mason()
  require('mason-nvim-dap').setup {
    -- automatic_installation races ensure_installed when an adapter is
    -- registered via dap.adapters[...], and the install stalls on the lockfile
    automatic_installation = false,
    -- default setup for every installed adapter, except the ones dap-go,
    -- dap-python and native() below register configurations for
    handlers = {
      delve = function() end,
      python = function() end,
      codelldb = function() end,
    },
    -- per-machine mason opt-out (see plugins/lsp.lua)
    ensure_installed = vim.g.disable_mason_auto_install and {} or { 'delve', 'coreclr', 'debugpy', 'js', 'codelldb' },
  }
end

--- neotest-golang calls dap-go's setup again before and after every debug
--- run, and each call appends dap-go's configurations. entries added under a
--- name already in the list are dropped
local function dedupe_dap_go_setup(dap)
  local dap_go = require 'dap-go'
  local dap_go_setup = dap_go.setup
  dap_go.setup = function(opts)
    local configs = dap.configurations.go or {}
    local existing, seen = #configs, {}
    for _, config in ipairs(configs) do
      seen[config.name] = true
    end
    dap_go_setup(opts)
    configs = dap.configurations.go
    for i = #configs, existing + 1, -1 do
      if seen[configs[i].name] then
        table.remove(configs, i)
      end
    end
  end
end

---@param root string module root holding go.mod
---@return string[] dirs of the main packages in the module
local function go_main_packages(root)
  local result = vim.system({ 'go', 'list', '-f', '{{if eq .Name "main"}}{{.Dir}}{{end}}', './...' }, { cwd = root, text = true }):wait()
  if result.code ~= 0 then
    vim.notify('go list failed: ' .. vim.trim(result.stderr or ''), vim.log.levels.ERROR)
  end
  return vim.split(vim.trim(result.stdout or ''), '\n', { trimempty = true })
end

--- builds whichever main package is picked, from any file in the module.
--- nvim-dap calls a config's `__call` before resolving it, so the package
--- is picked before the args prompt
local function go_main_package_launch()
  local base = { type = 'go', name = 'Debug main package', request = 'launch' }
  return setmetatable(base, {
    __call = function(config)
      -- run aborts when a field is ABORT, not the config itself
      local aborted = vim.tbl_extend('force', config, { program = require('dap').ABORT })
      local root = vim.fs.root(0, 'go.mod')
      if not root then
        vim.notify('no go.mod above this file', vim.log.levels.WARN)
        return aborted
      end
      local dirs = go_main_packages(root)
      if #dirs == 0 then
        vim.notify('no main package in this module', vim.log.levels.WARN)
        return aborted
      end
      local program = require('dap.ui').pick_if_many(dirs, 'Main package: ', function(dir)
        return vim.fs.relpath(root, dir) or dir
      end)
      if not program then
        return aborted
      end
      return vim.tbl_extend('force', config, {
        program = program,
        args = require('dap.utils').splitstr(vim.fn.input 'Args: '),
        outputMode = 'remote',
      })
    end,
  })
end

local function go(dap)
  dedupe_dap_go_setup(dap)
  require('dap-go').setup {
    delve = {
      detached = vim.fn.has 'win32' == 0,
    },
  }
  table.insert(dap.configurations.go, 1, go_main_package_launch())

  -- attach to a headless delve started with one of:
  --   dlv attach <pid> --headless --listen=127.0.0.1:38697 --api-version=2 --accept-multiclient
  --   dlv exec ./binary --headless --listen=127.0.0.1:38697 --api-version=2 --accept-multiclient
  -- TUI binaries need this: delve's DAP server has no `--tty`, so a launched debuggee gets pipe stdio.
  -- dap-go's `go` adapter spawns its own `dlv dap` even for remote attach; this one only connects.
  -- dap-view special-cases adapters named `delve` or `go`
  dap.adapters.delve = function(callback, config)
    callback { type = 'server', host = config.host, port = config.port }
  end
  dap.configurations.go = dap.configurations.go or {}
  table.insert(dap.configurations.go, {
    type = 'delve',
    name = 'Attach: headless dlv (default :38697)',
    request = 'attach',
    mode = 'remote',
    host = '127.0.0.1',
    port = function()
      return tonumber(vim.fn.input('dlv headless port: ', '38697'))
    end,
  })
end

local function python()
  -- mason's debugpy venv; nvim-dap-python still detects a project venv
  require('dap-python').setup(mason_packages .. '/debugpy/venv/bin/python')
end

local node_skip = { '<node_internals>/**' }

local function node_configs()
  return {
    -- node 23 strips TS types from .ts files (not enums, namespaces or .tsx)
    launch = {
      type = 'pwa-node',
      request = 'launch',
      name = 'Launch file (node)',
      program = '${file}',
      cwd = '${workspaceFolder}',
      skipFiles = node_skip,
    },
    -- SIGUSR1 opens a running node's inspector on its default port. js-debug's
    -- `processId` attach doesn't send it outside VS Code, so it's sent here
    attach_pid = {
      type = 'pwa-node',
      request = 'attach',
      name = 'Attach to process (node)',
      port = function()
        local pid = require('dap.utils').pick_process { filter = 'node' }
        if type(pid) ~= 'number' then
          return pid
        end
        vim.uv.kill(pid, 'sigusr1')
        return 9229
      end,
      cwd = '${workspaceFolder}',
      skipFiles = node_skip,
    },
    attach_port = {
      type = 'pwa-node',
      request = 'attach',
      name = 'Attach: node --inspect on :9229',
      port = 9229,
      cwd = '${workspaceFolder}',
      skipFiles = node_skip,
    },
  }
end

--- dev server config file prefixes and the port each server defaults to
local dev_servers = {
  { config = 'vite.config', url = 'http://localhost:5173' },
  { config = 'astro.config', url = 'http://localhost:4321' },
  { config = 'next.config', url = 'http://localhost:3000' },
}

local dev_server_configs = {}
for _, server in ipairs(dev_servers) do
  for _, ext in ipairs { 'ts', 'mts', 'js', 'mjs' } do
    table.insert(dev_server_configs, server.config .. '.' .. ext)
  end
end

---@return string? path of the nearest dev server config above the current file
local function find_dev_server_config()
  return vim.fs.find(dev_server_configs, { upward = true, path = vim.fn.expand '%:p:h' })[1]
end

--- opens a separate chrome profile at the dev server; breakpoints in source
--- files bind through the dev server's source maps, whose paths are relative
--- to the app's root (apps/web in a monorepo), not nvim's cwd
local function chrome_launch()
  return {
    type = 'pwa-chrome',
    request = 'launch',
    name = 'Launch chrome (dev server)',
    url = function()
      local name = vim.fs.basename(find_dev_server_config() or '')
      local default = dev_servers[1].url
      for _, server in ipairs(dev_servers) do
        if vim.startswith(name, server.config .. '.') then
          default = server.url
        end
      end
      return vim.fn.input('dev server url: ', default)
    end,
    webRoot = function()
      local config = find_dev_server_config()
      return config and vim.fs.dirname(config) or vim.fn.getcwd()
    end,
  }
end

--- vscode-js-debug via mason. `${port}` has nvim-dap pick a free port per
--- session and spawn the adapter as a child. neotest-vitest's
--- `strategy = 'dap'` uses it
local function js(dap)
  local js_debug_server = mason_packages .. '/js-debug-adapter/js-debug/src/dapDebugServer.js'
  for _, adapter in ipairs { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost' } do
    dap.adapters[adapter] = {
      type = 'server',
      host = 'localhost',
      port = '${port}',
      executable = {
        command = 'node',
        args = { js_debug_server, '${port}' },
      },
    }
  end

  local node = node_configs()
  local chrome = chrome_launch()
  dap.configurations.javascript = { node.launch, chrome, node.attach_pid, node.attach_port }
  dap.configurations.typescript = dap.configurations.javascript
  -- node can't run .tsx; react files run in the browser, or in node for SSR
  dap.configurations.javascriptreact = { chrome, node.attach_pid, node.attach_port }
  dap.configurations.typescriptreact = dap.configurations.javascriptreact
  -- astro component frontmatter renders in node; <script> blocks run in the browser
  dap.configurations.astro = dap.configurations.javascriptreact
end

--- where each build tool writes its binaries, for prefilling the program prompt
local native_build_dirs = {
  { marker = 'build.zig', dir = 'zig-out/bin/' },
  { marker = 'Cargo.toml', dir = 'target/debug/' },
  { marker = 'Package.swift', dir = '.build/debug/' },
}

local function native_build_dir()
  for _, tool in ipairs(native_build_dirs) do
    local root = vim.fs.root(0, tool.marker)
    if root then
      return root .. '/' .. tool.dir
    end
  end
  return vim.fn.getcwd() .. '/'
end

---@return string|table program path, or dap.ABORT on an empty answer
local function prompt_native_program()
  local program = vim.fn.input('Path to executable: ', native_build_dir(), 'file')
  return program ~= '' and program or require('dap').ABORT
end

local function native_configs()
  return {
    -- `__call` runs before field resolution, so the program prompt comes before args
    setmetatable({ type = 'codelldb', name = 'Launch (codelldb)', request = 'launch' }, {
      __call = function(config)
        return vim.tbl_extend('force', config, {
          program = prompt_native_program(),
          args = require('dap.utils').splitstr(vim.fn.input 'Args: '),
          cwd = '${workspaceFolder}',
          -- runInTerminal: nvim-dap gives the program a real terminal, so TUIs work
          terminal = 'integrated',
        })
      end,
    }),
    {
      type = 'codelldb',
      name = 'Attach to process (codelldb)',
      request = 'attach',
      pid = function()
        return require('dap.utils').pick_process()
      end,
    },
    -- for TUIs: the program gets its own tmux pane beside nvim
    setmetatable({ type = 'codelldb', name = 'Launch in tmux split (codelldb)', request = 'launch' }, {
      __call = function(config)
        return vim.tbl_extend('force', config, {
          program = prompt_native_program(),
          args = require('dap.utils').splitstr(vim.fn.input 'Args: '),
          cwd = '${workspaceFolder}',
          terminal = 'external',
        })
      end,
    }),
    -- attaches as soon as the binary starts, to catch startup code (macOS only)
    {
      type = 'codelldb',
      name = 'Attach when program starts (codelldb)',
      request = 'attach',
      program = prompt_native_program,
      waitFor = true,
    },
  }
end

--- codelldb via mason, for the C family, swift, zig and rust. rustaceanvim
--- adds its own rust launch configs; it has no attach
local function native(dap)
  dap.adapters.codelldb = {
    type = 'server',
    port = '${port}',
    executable = {
      command = mason_packages .. '/codelldb/extension/adapter/codelldb',
      args = { '--port', '${port}' },
    },
  }
  -- `terminal = 'external'` runs the program through this command
  dap.defaults.codelldb.external_terminal = { command = 'tmux', args = { 'split-window', '-h' } }
  local configs = native_configs()
  for _, ft in ipairs { 'c', 'cpp', 'objc', 'swift', 'zig', 'rust' } do
    dap.configurations[ft] = configs
  end
end

local osv_port = 8086

--- osv debugs lua running inside an nvim: the nvim being debugged starts the
--- server (`M.osv_toggle`, or NVIM_OSV=1 at startup) and another attaches
local function lua_configs(dap)
  dap.adapters.nlua = function(callback, config)
    callback { type = 'server', host = config.host, port = config.port }
  end

  local lldebugger = mason_packages .. '/local-lua-debugger-vscode/extension'
  dap.adapters['local-lua'] = {
    type = 'executable',
    command = 'node',
    args = { lldebugger .. '/extension/debugAdapter.js' },
    -- the adapter loads lldebugger.lua from extensionPath
    enrich_config = function(config, on_config)
      on_config(vim.tbl_extend('keep', config, { extensionPath = lldebugger }))
    end,
  }

  dap.configurations.lua = {
    {
      type = 'nlua',
      request = 'attach',
      name = 'Attach to nvim (osv)',
      host = '127.0.0.1',
      port = osv_port,
    },
    -- nlua is `nvim -l`: plain lua plus the vim.* API
    {
      type = 'local-lua',
      request = 'launch',
      name = 'Launch file (nlua)',
      program = { lua = 'nlua', file = '${file}' },
      cwd = '${workspaceFolder}',
    },
  }
end

--- starts or stops osv in this nvim, for another nvim to attach to
function M.osv_toggle()
  local osv = require 'osv'
  if osv.is_running() then
    osv.stop()
    vim.notify('osv stopped', vim.log.levels.INFO)
    return
  end
  osv.launch { port = osv_port }
  vim.notify(('osv listening on %d'):format(osv_port), vim.log.levels.INFO)
end

--- picks one of the current filetype's attach configs and runs it
function M.attach()
  local dap = require 'dap'
  local configs = vim.tbl_filter(function(config)
    return config.request == 'attach'
  end, dap.configurations[vim.bo.filetype] or {})
  if #configs == 0 then
    vim.notify(('no attach configs for %s'):format(vim.bo.filetype), vim.log.levels.WARN)
    return
  end
  vim.ui.select(configs, {
    prompt = 'Attach',
    format_item = function(config)
      return config.name
    end,
  }, function(config)
    if config then
      dap.run(config)
    end
  end)
end

--- ends the session; an attached program is detached from rather than
--- killed. js-debug's child sessions are attaches under a launch, so the
--- top-level session decides
function M.stop()
  local dap = require 'dap'
  local session = dap.session()
  if not session then
    return
  end
  local root = session
  while root.parent do
    root = root.parent
  end
  if root.config.request == 'attach' then
    dap.disconnect { terminateDebuggee = false }
  else
    dap.terminate()
  end
end

function M.setup()
  local dap = require 'dap'
  mason()
  go(dap)
  python()
  js(dap)
  native(dap)
  lua_configs(dap)
end

return M
