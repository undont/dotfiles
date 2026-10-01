-- sonarlint.nvim spec and config wiring; scans, rules, code actions and the
-- rule popup are in features/sonar-*.lua.
-- connected mode (SonarCloud) needs SONARQUBE_TOKEN and SONARQUBE_ORG in the
-- environment; without them the server runs local-only. per-project binding
-- is `.sonarlint/connectedMode.json`: { "projectKey": "my-org_my-project" }

local common = require 'custom.features.sonar-common'
local rules = require 'custom.features.sonar-rules'
local actions = require 'custom.features.sonar-actions'
local rule_popup = require 'custom.features.sonar-rule-popup'
local scan = require 'custom.features.sonar-scan'

local CONNECTION_ID = 'sonarcloud'
local FILETYPES = common.FILETYPES
local SONARLINT_CLIENT_NAME = common.SONARLINT_CLIENT_NAME

--- mason install root. `vim.env.MASON` is unset until `mason.setup()` runs,
--- which this `ft`-loaded config can precede
local function mason_root()
  return vim.env.MASON or (vim.fn.stdpath 'data' .. '/mason')
end

--- analyzer jars present on disk; a missing jar stops the language server starting
local function analyzer_jars()
  local dir = mason_root() .. '/share/sonarlint-analyzers'
  local candidates = {
    'sonarpython.jar',
    'sonarcfamily.jar', -- C / C++
    'sonarjs.jar', -- JavaScript / TypeScript
    'sonargo.jar',
    -- no C# analyzer: the language server skips sonarcsharp.jar
    -- (`SonarLint-Supported: false`), and sonarlintomnisharp.jar spawns an
    -- omnisharp that loads the solution a second time beside roslyn.nvim.
    -- see .claude/rules/sonarlint.md
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

return {
  {
    'https://gitlab.com/schrieveslaach/sonarlint.nvim',
    ft = FILETYPES,
    keys = {
      {
        '<leader>lm',
        function()
          scan.run_scan 'changed'
        end,
        desc = 'LSP: Sonar scan [M]odified files',
      },
      {
        '<leader>lb',
        function()
          scan.run_scan 'branch'
        end,
        desc = 'LSP: Sonar scan [B]ranch vs main',
      },
      {
        '<leader>lT',
        function()
          scan.run_scan 'ticket'
        end,
        desc = 'LSP: Sonar scan [T]icket commits',
      },
      {
        '<leader>lS',
        function()
          scan.run_scan 'all'
        end,
        desc = 'LSP: [S]onar scan whole project',
      },
    },
    dependencies = { 'lewis6991/gitsigns.nvim' },
    config = function()
      local cmd = { 'sonarlint-language-server', '-stdio', '-analyzers' }
      vim.list_extend(cmd, analyzer_jars())

      local opts = {
        server = {
          cmd = cmd,
          settings = {
            sonarlint = {},
          },
          -- applies `.sonarlint/localRules.json`: `rules` merges into
          -- config.settings.sonarlint.rules, `overrides` compile into glob
          -- matchers on the config for the LspAttach hook below. the
          -- connected-mode branch wraps this to bind the project key
          before_init = function(params, config)
            -- the silence-rule writer needs the root before any localRules.json exists
            local root = params.rootPath or config.root_dir
            config._sonarlint_root = root
            local cfg = rules.read_project_config(root)
            if not cfg then
              return
            end
            local sonar_rules = rules.eslint_to_sonarlint_rules(cfg.rules)
            if sonar_rules then
              config.settings = config.settings or {}
              config.settings.sonarlint = config.settings.sonarlint or {}
              config.settings.sonarlint.rules = vim.tbl_deep_extend('force', config.settings.sonarlint.rules or {}, sonar_rules)
            end
            config._sonarlint_overrides = rules.compile_overrides(cfg.overrides)
          end,
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
        local base_before_init = opts.server.before_init
        opts.server.before_init = function(params, config)
          if base_before_init then
            base_before_init(params, config)
          end
          local key = rules.read_project_key(params.rootPath)
          if key then
            config.settings.sonarlint.connectedMode.project = {
              connectionId = CONNECTION_ID,
              projectKey = key,
            }
          end
        end

        -- sonarlint.nvim's `find_server_url` crashes on SonarCloud-only setups:
        -- it iterates `connections.sonarqube` (nil here) and treats
        -- `connections.sonarcloud` as one object, not the documented array.
        -- both notification handlers are patched before setup() captures them.
        -- https://gitlab.com/schrieveslaach/sonarlint.nvim/-/issues/42
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
            -- params.reason is server-controlled; bound to keep the notify log sane
            local reason = tostring(params.reason or 'unknown'):sub(1, 200)
            vim.notify_once('Cannot connect to ' .. url .. ' (' .. cid .. '): ' .. reason, vim.log.levels.ERROR)
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

      -- `overrides` from .sonarlint/localRules.json filter diagnostics at
      -- publish time, via a wrap of the client's publishDiagnostics handler
      -- installed on first attach. the handler reads the compiled overrides
      -- from `client.config` on each call, so an override added at runtime
      -- applies on the next publish. filtering only removes: the server does
      -- not emit diagnostics for a globally disabled rule
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= SONARLINT_CLIENT_NAME then
            return
          end
          -- sonar's codeAction responses carry the silence actions
          actions.wrap_sonar_codeaction(client)

          if client._sonarlint_overrides_wrapped then
            return
          end
          client._sonarlint_overrides_wrapped = true

          -- rule-description popup from features/sonar-rule-popup
          client.handlers['sonarlint/showRuleDescription'] = rule_popup.rich_rule_handler

          local default = client.handlers['textDocument/publishDiagnostics'] or vim.lsp.handlers['textDocument/publishDiagnostics']
          client.handlers['textDocument/publishDiagnostics'] = function(err, result, ctx, hcfg)
            local compiled = client.config and client.config._sonarlint_overrides
            if compiled and result and result.uri and result.diagnostics then
              local root = client.config._sonarlint_root
              local path = vim.uri_to_fname(result.uri)
              local kept = {}
              for _, d in ipairs(result.diagnostics) do
                if not rules.is_overridden(compiled, root, path, d.code) then
                  table.insert(kept, d)
                end
              end
              result.diagnostics = kept
            end
            return default(err, result, ctx, hcfg)
          end
        end,
      })

      -- silence-rule code actions run their Command locally. this registers
      -- the command handler and wraps any sonar client attached before the
      -- LspAttach hook above existed
      vim.lsp.commands[actions.SILENCE_COMMAND] = function(command)
        local arg = command.arguments and command.arguments[1]
        if arg then
          rules.silence_rule(arg)
        end
      end

      for _, client in ipairs(vim.lsp.get_clients { name = SONARLINT_CLIENT_NAME }) do
        actions.wrap_sonar_codeaction(client)
      end
    end,
  },
}
