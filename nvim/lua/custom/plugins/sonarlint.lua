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

--- Build the analyzer jar list, filtering out any that aren't on disk so a
--- partial Mason install doesn't make the language server fail to start.
local function analyzer_jars()
  local dir = vim.fn.expand '$MASON/share/sonarlint-analyzers'
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

return {
  {
    'https://gitlab.com/schrieveslaach/sonarlint.nvim',
    ft = FILETYPES,
    dependencies = { 'lewis6991/gitsigns.nvim' },
    config = function()
      local cmd = { 'sonarlint-language-server', '-stdio', '-analyzers' }
      vim.list_extend(cmd, analyzer_jars())

      local extension_dir = vim.fn.expand '$MASON/packages/sonarlint-language-server/extension'
      local opts = {
        server = {
          cmd = cmd,
          -- C# analysis runs through omnisharp bundled inside the sonarlint
          -- vsix -- it doesn't replace roslyn (which keeps providing the
          -- editor-facing LSP). Safe to set unconditionally; sonarlint only
          -- spawns omnisharp when actually scanning a .cs file.
          init_options = {
            omnisharpDirectory = extension_dir .. '/omnisharp',
            csharpOssPath = vim.fn.expand '$MASON/share/sonarlint-analyzers/sonarcsharp.jar',
          },
          settings = {
            sonarlint = {},
          },
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
        opts.server.before_init = function(params, config)
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
            vim.notify_once('Cannot connect to ' .. url .. ' (' .. cid .. '): ' .. (params.reason or 'unknown'), vim.log.levels.ERROR)
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
    end,
  },
}
