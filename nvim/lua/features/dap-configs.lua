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
