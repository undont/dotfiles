-- Silence-rule code actions. Extracted from plugins/sonarlint.lua.
--
-- Surface "silence this rule" quick fixes in the native code-action picker
-- (gra) for any sonar diagnostic under the cursor. Two variants per rule:
--   * project-wide  -> sets `rules["<code>"] = "off"` in localRules.json
--   * in test files -> adds (or extends) an `overrides` entry whose `files`
--                       are the test globs for the buffer's language and
--                       silences the rule only there
-- Both write `.sonarlint/localRules.json` (creating the dir/file if needed),
-- then apply the change to the running server immediately so the warning
-- disappears without a restart (see sonar-rules.silence_rule).
--
-- The actions are served by riding inside the sonar client's own codeAction
-- response: vim.lsp.buf.code_action builds each client's context.diagnostics
-- from that client's namespace, and nvim aggregates actions per responding
-- client, so a separate source would land in its own group at the bottom.
-- Each action carries a Command (not a workspace edit); execution is handled
-- locally via vim.lsp.commands[SILENCE_COMMAND], registered by the spec.

local common = require 'custom.features.sonar-common'

local M = {}

M.SILENCE_COMMAND = 'sonarlint.silenceRule'

-- Test-file globs per filetype. Languages without a settled test-naming
-- convention are omitted -- they simply don't get the "in test files" action.
local TEST_GLOBS = {
  go = { '**/*_test.go' },
  python = { '**/test_*.py', '**/*_test.py' },
  javascript = { '**/*.test.js', '**/*.spec.js' },
  javascriptreact = { '**/*.test.jsx', '**/*.spec.jsx' },
  typescript = { '**/*.test.ts', '**/*.spec.ts' },
  typescriptreact = { '**/*.test.tsx', '**/*.spec.tsx' },
  cs = { '**/*Tests.cs', '**/*Test.cs' },
  cpp = { '**/*_test.cpp', '**/*_test.cc' },
  c = { '**/*_test.c' },
  php = { '**/*Test.php' },
}

--- Resolve the project root for writing localRules.json. Prefer the attached
--- sonar client's root (so the file lands where before_init will read it on
--- the next start), then the nearest `.sonarlint`/`.git` ancestor, then cwd.
local function project_root_for_buf(bufnr)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, name = common.SONARLINT_CLIENT_NAME }) do
    local root = (client.config and (client.config._sonarlint_root or client.config.root_dir)) or client.root_dir
    if root and root ~= '' then
      return root
    end
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd()
  return vim.fs.root(dir, { '.sonarlint', '.git' }) or vim.fn.getcwd()
end

--- Build silence code actions for the sonar diagnostics overlapping a
--- codeAction request's range. Returns LSP CodeAction objects whose Command is
--- handled locally by vim.lsp.commands[SILENCE_COMMAND].
local function build_silence_actions(params)
  local uri = params.textDocument and params.textDocument.uri
  if not uri then
    return {}
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return {}
  end
  local range = params.range or {}
  local first = (range.start and range.start.line) or 0
  local last = (range['end'] and range['end'].line) or first
  local root = project_root_for_buf(bufnr)
  local globs = TEST_GLOBS[vim.bo[bufnr].filetype]

  local actions, seen = {}, {}
  for _, d in ipairs(common.sonarlint_diagnostics(bufnr)) do
    local dfirst = d.lnum or 0
    local dlast = d.end_lnum or dfirst
    if dfirst <= last and dlast >= first then
      local code = common.diagnostic_code(d)
      if code and not seen[code] then
        seen[code] = true
        table.insert(actions, {
          title = 'Sonar: silence ' .. code .. ' (project)',
          kind = 'quickfix',
          command = {
            title = 'Silence ' .. code,
            command = M.SILENCE_COMMAND,
            arguments = { { root = root, code = code, scope = 'global', bufnr = bufnr } },
          },
        })
        if globs then
          table.insert(actions, {
            title = 'Sonar: silence ' .. code .. ' in test files',
            kind = 'quickfix',
            command = {
              title = 'Silence ' .. code .. ' in tests',
              command = M.SILENCE_COMMAND,
              arguments = { { root = root, code = code, scope = 'test', globs = globs, bufnr = bufnr } },
            },
          })
        end
      end
    end
  end
  return actions
end

-- Command id sonar attaches to its "Show issue details for '<rule>'" code
-- action. Used to float that action to the top of gra. (The OpenRuleDesc /
-- OpenStandaloneRuleDesc commands are internal executeCommand targets, not the
-- code-action command -- verified against the running server.)
local DETAILS_COMMANDS = {
  ['SonarLint.ShowIssueDetailsCodeAction'] = true,
}

--- The command id carried by a code action, whether it's a bare Command or a
--- CodeAction with a nested `command`. Returns nil when there's none.
local function action_command(action)
  local c = action and action.command
  if type(c) == 'table' then
    return c.command
  end
  return c -- bare Command string, or nil
end

--- Reorder a sonar codeAction result so the "Show issue details" action sits
--- first, preserving the relative order of everything else. Returns the
--- (possibly new) list; a no-op when the action isn't present.
local function details_first(result)
  if type(result) ~= 'table' or #result < 2 then
    return result
  end
  local head, tail = {}, {}
  for _, action in ipairs(result) do
    local cmd = action_command(action)
    if cmd and DETAILS_COMMANDS[cmd] then
      table.insert(head, action)
    else
      table.insert(tail, action)
    end
  end
  if #head == 0 then
    return result
  end
  return vim.list_extend(head, tail)
end

--- Wrap a sonar client's request method once so its codeAction responses carry
--- the silence actions, placing them immediately after sonar's own actions in
--- the gra picker. Neovim aggregates code actions per responding client (v0.12
--- `on_code_action_results` iterates `pairs(results)`), so riding inside the
--- sonar client's result is the only way to control where ours appear; a
--- separate code-action source would land in its own group at the bottom.
function M.wrap_sonar_codeaction(client)
  if not client or client._sonarlint_codeaction_wrapped then
    return
  end
  client._sonarlint_codeaction_wrapped = true
  local orig_request = client.request
  client.request = function(self, method, params, handler, req_bufnr)
    if method == 'textDocument/codeAction' and type(handler) == 'function' then
      local function wrapped(err, result, ctx, hcfg)
        if not err then
          result = result or {}
          if type(result) == 'table' then
            -- Float sonar's own "Show issue details" action to the top, then
            -- append our silence actions after sonar's remaining entries.
            result = details_first(result)
            for _, action in ipairs(build_silence_actions(params)) do
              table.insert(result, action)
            end
          end
        end
        return handler(err, result, ctx, hcfg)
      end
      return orig_request(self, method, params, wrapped, req_bufnr)
    end
    return orig_request(self, method, params, handler, req_bufnr)
  end
end

return M
