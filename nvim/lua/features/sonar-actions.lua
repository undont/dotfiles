-- "silence this rule" code actions in the native picker (gra) for sonar
-- diagnostics under the cursor: project-wide (`rules["<code>"] = "off"`) or in
-- test files (an `overrides` entry with the language's test globs). both go
-- through sonar-rules.silence_rule.
-- the actions are added to the sonar client's own codeAction response: nvim
-- groups actions per responding client. each carries a Command, run locally
-- via vim.lsp.commands[SILENCE_COMMAND], registered by the spec

local common = require 'features.sonar-common'

local M = {}

M.SILENCE_COMMAND = 'sonarlint.silenceRule'

-- test-file globs per filetype. a filetype absent here gets no "in test
-- files" action
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

--- the attached sonar client's root first (where before_init reads
--- localRules.json on the next start), then the nearest `.sonarlint`/`.git`
--- ancestor, then cwd
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

--- LSP CodeAction objects for the sonar diagnostics overlapping a codeAction
--- request's range
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

-- command id sonar attaches to its "Show issue details for '<rule>'" code
-- action. the OpenRuleDesc / OpenStandaloneRuleDesc commands are
-- executeCommand targets, not the code-action command
local DETAILS_COMMANDS = {
  ['SonarLint.ShowIssueDetailsCodeAction'] = true,
}

--- the command id of a bare Command or of a CodeAction with a nested
--- `command`; nil when there's none
local function action_command(action)
  local c = action and action.command
  if type(c) == 'table' then
    return c.command
  end
  return c -- bare Command string, or nil
end

--- moves the "Show issue details" action first, keeping the order of the rest
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

--- wraps the client's request method once, so its codeAction responses carry
--- the silence actions after sonar's own
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
