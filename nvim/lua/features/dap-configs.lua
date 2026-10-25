-- dap adapters and launch/attach configurations per language

local M = {}

local mason_packages = vim.fn.stdpath 'data' .. '/mason/packages'

local function mason()
  require('mason-nvim-dap').setup {
    -- automatic_installation races ensure_installed when an adapter is
    -- registered via dap.adapters[...], and the install stalls on the lockfile
    automatic_installation = false,
    -- default setup for every installed adapter, except the ones dap-go and
    -- dap-python already register configurations for
    handlers = {
      delve = function() end,
      python = function() end,
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

local function go(dap)
  dedupe_dap_go_setup(dap)
  require('dap-go').setup {
    delve = {
      detached = vim.fn.has 'win32' == 0,
    },
  }

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
    name = 'Attach (remote dlv)',
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

--- codelldb via mason, for the native C family and swift
local function native(dap)
  dap.adapters.codelldb = {
    type = 'server',
    port = '${port}',
    executable = {
      command = mason_packages .. '/codelldb/extension/adapter/codelldb',
      args = { '--port', '${port}' },
    },
  }

  -- prompts for the compiled binary (e.g. `.build/debug/<target>` for
  -- SwiftPM), built with debug symbols
  local codelldb_launch = {
    {
      name = 'Launch (codelldb)',
      type = 'codelldb',
      request = 'launch',
      program = function()
        return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
      args = {},
    },
  }
  dap.configurations.c = codelldb_launch
  dap.configurations.cpp = codelldb_launch
  dap.configurations.objc = codelldb_launch
  dap.configurations.swift = codelldb_launch
end

function M.setup()
  local dap = require 'dap'
  mason()
  go(dap)
  python()
  js(dap)
  native(dap)
end

return M
