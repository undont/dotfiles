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
--
-- This file is the thin lazy spec + config wiring. The bespoke concerns live
-- in features/: sonar-scan (project/changed/ticket scans), sonar-rules
-- (localRules.json model + live silence), sonar-actions (silence code
-- actions), sonar-rule-popup (rich rule-description popup), and sonar-common
-- (shared constants + sonar-diagnostic accessors).

local common = require 'custom.features.sonar-common'
local rules = require 'custom.features.sonar-rules'
local actions = require 'custom.features.sonar-actions'
local rule_popup = require 'custom.features.sonar-rule-popup'
local scan = require 'custom.features.sonar-scan'

local CONNECTION_ID = 'sonarcloud'
local FILETYPES = common.FILETYPES
local SONARLINT_CLIENT_NAME = common.SONARLINT_CLIENT_NAME

--- Mason install root. `vim.env.MASON` is only set after `mason.setup()`
--- runs, which may not have happened by the time sonarlint.nvim's config
--- fires (sonarlint.nvim doesn't depend on mason.nvim, so lazy-loading via
--- `ft = FILETYPES` can outrun mason). Fall back to mason's documented
--- default install location so paths resolve regardless of load order.
local function mason_root()
  return vim.env.MASON or (vim.fn.stdpath 'data' .. '/mason')
end

--- Build the analyzer jar list, filtering out any that aren't on disk so a
--- partial Mason install doesn't make the language server fail to start.
local function analyzer_jars()
  local dir = mason_root() .. '/share/sonarlint-analyzers'
  local candidates = {
    'sonarpython.jar',
    'sonarcfamily.jar', -- C / C++
    'sonarjs.jar', -- JavaScript / TypeScript
    'sonargo.jar',
    -- No C# analyzer, deliberately. sonarcsharp.jar is the server-side
    -- plugin (`SonarLint-Supported: false` in its manifest -- the language
    -- server silently skips it), and the real sonarlint C# path
    -- (sonarlintomnisharp.jar) spawns a bundled omnisharp that does a second
    -- MSBuild solution load competing with roslyn.nvim. Read
    -- .claude/rules/sonarlint.md before re-adding either.
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

-- Suppress sonarlint when entering diff/review contexts (Octo, Diffview).
-- Strategy: leave existing clients running (they continue analysing the
-- pre-review buffers), but block new attaches via the FileType-handler gate
-- installed in config(). This avoids a JVM cold-start cost when leaving
-- review and dramatically reduces chatter, at the cost of sonarlint
-- continuing to analyse the small set of files open before the review.
--
-- vim.g.sonarlint_suppressed gates the FileType-handler attach-block (below)
-- and ui.lua's vim.notify chatter filter. Fidget progress for the
-- `sonarlint.nvim` client is dropped unconditionally in ui.lua — analysis
-- fires per-BufEnter and would otherwise pop a toast on every file open.
vim.g.sonarlint_suppressed = false

local function suppress_sonarlint()
  vim.g.sonarlint_suppressed = true
end

local function try_restore_sonarlint()
  if not vim.g.sonarlint_suppressed then
    return
  end

  -- Same guard as roslyn: don't restore while still in a review context
  if require('custom.core.review-context').is_active() then
    return
  end

  vim.g.sonarlint_suppressed = false

  local ok, _ = pcall(require, 'sonarlint')
  if not ok then
    return
  end

  -- Re-fire FileType for loaded buffers so sonarlint.nvim reattaches
  local filetype_set = {}
  for _, ft in ipairs(FILETYPES) do
    filetype_set[ft] = true
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and filetype_set[vim.bo[buf].filetype] then
      vim.api.nvim_exec_autocmds('FileType', { buffer = buf })
    end
  end
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'octo', 'DiffviewFiles', 'DiffviewFileHistory' },
  callback = suppress_sonarlint,
})

-- Re-enable sonarlint when returning to normal buffers after review closes.
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    if vim.g.sonarlint_suppressed then
      vim.defer_fn(function()
        if not vim.g.sonarlint_suppressed then
          return
        end
        try_restore_sonarlint()
      end, 2000)
    end
  end,
})

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
          -- Always-on: load `.sonarlint/localRules.json` and apply it.
          -- `rules` is merged into config.settings.sonarlint.rules (sent to
          -- the LSP server). `overrides` are compiled into glob matchers and
          -- stashed on the config; the LspAttach hook below uses them to
          -- filter diagnostics client-side. The connected-mode branch below
          -- wraps this to additionally bind the project key when SonarCloud
          -- creds are present.
          before_init = function(params, config)
            -- Always stash the root so the silence-rule writer and the
            -- override recompile can find the project even before any
            -- localRules.json exists.
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

        -- Upstream bug workaround: sonarlint.nvim's `find_server_url` crashes
        -- on SonarCloud-only setups. Two issues:
        --   1. unconditionally iterates `connections.sonarqube` (nil when only
        --      sonarcloud is configured) -> bad argument to ipairs
        --   2. treats `connections.sonarcloud` as a single object but the
        --      documented config (and ours) makes it an array of connections
        -- Patch both notification handlers before setup() captures the
        -- function references on line 113-114 of sonarlint.lua.
        --
        -- Upstream tracking: https://gitlab.com/schrieveslaach/sonarlint.nvim/-/issues/42
        -- Remove this block once the fix lands and we've bumped the plugin.
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
            -- params.reason is server-controlled; bound to keep the notify log sane.
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

      -- Apply project-local `overrides` from .sonarlint/localRules.json at
      -- diagnostic publish time. We wrap the sonarlint client's
      -- publishDiagnostics handler once on first attach so each diagnostic
      -- gets filtered against the compiled glob+rule matchers. The compiled
      -- overrides and root are read from `client.config` *inside* the handler
      -- rather than captured up front, so a silence-rule code action that adds
      -- an override at runtime takes effect on the next publish without a
      -- restart. Filtering is subtractive only -- a rule that's off globally
      -- can't be re-enabled per-glob because the server has already stopped
      -- emitting those diagnostics.
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= SONARLINT_CLIENT_NAME then
            return
          end
          -- Make sonar's own codeAction responses carry our silence actions,
          -- so they appear right after sonar's entries in the gra picker.
          actions.wrap_sonar_codeaction(client)

          if client._sonarlint_overrides_wrapped then
            return
          end
          client._sonarlint_overrides_wrapped = true

          -- Replace sonar's generic rule-description popup with our richer one
          -- (deprecation note + full description). See rich_rule_handler.
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

      -- Gate sonarlint's FileType autocmd on `vim.g.sonarlint_suppressed`.
      -- Without this, every `FileType cs` (review buffers, `<leader>de`'s
      -- `:edit`) runs the handler synchronously -- which calls find_root_dir
      -- (walks the filesystem) and, on cache miss, start_sonarlint_lsp
      -- (spawns a JVM-backed client). On large .NET repos that's ~1s warm /
      -- ~15s cold, blocking the editor on every cs file open during review.
      --
      -- sonarlint.nvim registers a single FileType autocmd with
      -- `pattern = table.concat(FILETYPES, ',')`. nvim_get_autocmds splits
      -- multi-pattern autocmds into per-pattern entries that share an id and
      -- callback, so we can't compare patterns directly -- find the id
      -- whose entries cover the most of FILETYPES (uniquely sonarlint).
      local filetype_set = {}
      for _, ft in ipairs(FILETYPES) do
        filetype_set[ft] = true
      end

      local id_count, id_callback = {}, {}
      for _, ac in ipairs(vim.api.nvim_get_autocmds { event = 'FileType' }) do
        if ac.callback and filetype_set[ac.pattern] then
          id_count[ac.id] = (id_count[ac.id] or 0) + 1
          id_callback[ac.id] = ac.callback
        end
      end

      local sonar_id, sonar_count, sonar_cb = nil, 0, nil
      for id, count in pairs(id_count) do
        if count > sonar_count then
          sonar_id, sonar_count, sonar_cb = id, count, id_callback[id]
        end
      end

      if sonar_id and sonar_cb and sonar_count >= math.floor(#FILETYPES / 2) then
        vim.api.nvim_del_autocmd(sonar_id)
        vim.api.nvim_create_autocmd('FileType', {
          pattern = FILETYPES,
          callback = function(args)
            if vim.g.sonarlint_suppressed then
              return
            end
            return sonar_cb(args)
          end,
        })
      end

      -- Silence-rule code actions: execute the action's Command locally (no
      -- round-trip to a server). The codeAction wrap is installed from the
      -- LspAttach hook above; here we register the command handler and wrap any
      -- sonar client that already attached before the hook existed (e.g. the ft
      -- buffer that loaded this plugin).
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
