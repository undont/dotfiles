-- monkeypatches over neotest and its adapters; apply() is called from the
-- neotest spec's config before neotest.setup

local M = {}

--- neotest parses with nvim's default in-progress tree-sitter match cap, past
--- which the earliest matches are dropped, truncating long table-driven tests
--- to their tail. neotest takes a match_limit, but no adapter passes one
local function raise_treesitter_match_limit()
  local ok, ts = pcall(require, 'neotest.lib.treesitter')
  if not ok or ts.match_limit_raised then
    return
  end
  local parse_positions = ts.parse_positions
  ts.parse_positions = function(path, query, opts)
    return parse_positions(path, query, vim.tbl_extend('keep', opts or {}, { match_limit = 100000 }))
  end
  ts.match_limit_raised = true
end

--- the subtest query yields one position named `""` for `t.Run("", ...)`,
--- while go names each table row `TestX/#00`, `#01` and so on. the single node
--- matches no event, and neotest gives a result-less position the run root's
--- status (client/runner.lua), which propagates to the parent. one position
--- per row is substituted, numbered as go does; the node is dropped when the
--- row count can't be read statically
local function expand_empty_subtest_positions()
  local ok, ts = pcall(require, 'neotest.lib.treesitter')
  if not ok or ts.empty_subtests_expanded then
    return
  end
  local Tree = require('neotest.types').Tree
  local parse_positions = ts.parse_positions

  local table_query = [[
    (short_var_declaration
      left: (expression_list (identifier) @name)
      right: (expression_list (composite_literal body: (literal_value) @body)))
  ]]
  local run_query = [[
    (call_expression
      function: (selector_expression
        operand: (identifier) @op (#match? @op "^(t|s|suite)$")
        field: (field_identifier) @method (#eq? @method "Run"))
      arguments: (argument_list . (interpreted_string_literal) @arg)) @call
  ]]

  local function captured(query, match, name)
    for id, nodes in pairs(match) do
      if query.captures[id] == name then
        return type(nodes) == 'table' and nodes[#nodes] or nodes
      end
    end
  end

  local function enclosing(node, node_type)
    while node do
      if node:type() == node_type then
        return node
      end
      node = node:parent()
    end
  end

  --- rows of the table `name` is bound to, searched only inside `scope`, so two
  --- test functions in one file can both call their table `tests`
  local function rows_in_scope(scope, name, src)
    local tq = vim.treesitter.query.parse('go', table_query)
    for _, match in tq:iter_matches(scope, src, nil, nil, { all = true }) do
      local ident, body = captured(tq, match, 'name'), captured(tq, match, 'body')
      if ident and body and vim.treesitter.get_node_text(ident, src) == name then
        local rows = {}
        for i = 0, body:named_child_count() - 1 do
          local element = body:named_child(i)
          if element:type() == 'literal_element' then
            rows[#rows + 1] = { element:range() }
          end
        end
        return rows
      end
    end
  end

  --- row ranges of the table each `t.Run("")` iterates, keyed by call start line
  local function rows_by_call_line(path)
    local fh = io.open(path, 'r')
    if not fh then
      return {}
    end
    local src = fh:read '*a'
    fh:close()
    local parsed, root = pcall(function()
      return vim.treesitter.get_string_parser(src, 'go'):parse()[1]:root()
    end)
    if not parsed or not root then
      return {}
    end

    local by_line = {}
    local cq = vim.treesitter.query.parse('go', run_query)
    for _, match in cq:iter_matches(root, src, nil, nil, { all = true }) do
      local arg, call = captured(cq, match, 'arg'), captured(cq, match, 'call')
      if arg and call and vim.treesitter.get_node_text(arg, src) == '""' then
        local loop = enclosing(call, 'for_statement')
        local scope = enclosing(call, 'function_declaration')
        local ranged
        if loop then
          for i = 0, loop:named_child_count() - 1 do
            local clause = loop:named_child(i)
            if clause:type() == 'range_clause' and clause:named_child_count() > 0 then
              ranged = vim.treesitter.get_node_text(clause:named_child(clause:named_child_count() - 1), src)
            end
          end
        end
        if ranged and scope then
          by_line[select(1, call:range())] = rows_in_scope(scope, ranged, src)
        end
      end
    end
    return by_line
  end

  local function rewrite(node, rows)
    local kept = { node[1] }
    for i = 2, #node do
      local pos = node[i][1]
      if pos.type == 'test' and pos.name == '""' then
        local parent_id = pos.id:gsub('::""$', '')
        for index, range in ipairs(rows[pos.range[1]] or {}) do
          local name = ('#%02d'):format(index - 1)
          kept[#kept + 1] = {
            {
              id = parent_id .. '::"' .. name .. '"',
              name = name,
              path = pos.path,
              range = range,
              type = 'test',
            },
          }
        end
      else
        kept[#kept + 1] = rewrite(node[i], rows)
      end
    end
    return kept
  end

  ts.parse_positions = function(path, query, opts)
    local tree = parse_positions(path, query, opts)
    if not path:match '%.go$' then
      return tree
    end
    local ok_rows, rows = pcall(rows_by_call_line, path)
    return Tree.from_list(rewrite(tree:to_list(), ok_rows and rows or {}), function(pos)
      return pos.id
    end)
  end
  ts.empty_subtests_expanded = true
end

--- neotest-golang can return no result for a position whose events were in
--- flight when the stream stopped, and neotest gives a result-less position the
--- run root's status (client/runner.lua), which propagates to the parent. a
--- missing position gets the aggregate of its descendants, a missing leaf
--- `skipped`
local function backfill_missing_results()
  local ok, rf = pcall(require, 'neotest-golang.results_finalize')
  if not ok or rf.missing_results_backfilled then
    return
  end
  local test_results = rf.test_results
  rf.test_results = function(spec, result, tree)
    local results = test_results(spec, result, tree)
    local function fill(node)
      local seen, status = false, 'passed'
      for _, child in ipairs(node:children()) do
        local child_status = fill(child)
        if child_status then
          seen = true
          if child_status == 'failed' then
            status = 'failed'
          elseif child_status == 'skipped' and status == 'passed' then
            status = 'skipped'
          end
        end
      end
      local pos_id = node:data().id
      if results[pos_id] then
        return results[pos_id].status
      end
      if seen then
        results[pos_id] = { status = status }
        return status
      end
      -- a leaf whose result was dropped is unknown, not failed
      results[pos_id] = { status = 'skipped' }
      return 'skipped'
    end
    fill(tree)
    return results
  end
  rf.missing_results_backfilled = true
end

--- neotest-golang keys its per-file discovery cache on whole-second mtime, so
--- a second write inside the same second gets the stale tree; autosave
--- (core/autocmds.lua) writes that often. the cache is keyed on the full stat
--- signature, captured before the parse so a write mid-parse leaves the entry
--- stale
local function fix_golang_discovery_cache()
  local ok, cache = pcall(require, 'neotest-golang.lib.discovery_cache')
  if not ok or type(cache.get) ~= 'function' or type(cache.set) ~= 'function' then
    return
  end
  local store = {} ---@type table<string, {tree: neotest.Tree|nil, sig: string|nil}>
  local pending = {} ---@type table<string, string|nil>
  local function signature(path)
    local stat = vim.uv.fs_stat(path)
    return stat and string.format('%d:%d:%d', stat.mtime.sec, stat.mtime.nsec, stat.size) or nil
  end
  cache.get = function(path)
    local sig = signature(path)
    pending[path] = sig
    local entry = store[path]
    if entry and sig and entry.sig == sig then
      return entry.tree
    end
    return nil
  end
  cache.set = function(path, tree)
    store[path] = { tree = tree, sig = pending[path] }
  end
  cache.invalidate = function(path)
    store[path] = nil
  end
  cache.clear = function()
    store, pending = {}, {}
  end
  cache.stats = function()
    local files = vim.tbl_keys(store)
    return { size = #files, files = files }
  end
end

--- picks one of the test binaries neotest-zig installs to zig-out/test, which
--- it otherwise asks for as a typed path. neotest starts the session inside a
--- nio task, where dap.ui's coroutine-based picker can't suspend
local function pick_zig_test_binary()
  local dap = require 'dap'
  local binaries = vim.fn.glob(vim.fn.getcwd() .. '/zig-out/test/*', false, true)
  if #binaries == 0 then
    vim.notify('neotest-zig: no test binary in zig-out/test', vim.log.levels.WARN)
    return dap.ABORT
  end
  if #binaries == 1 then
    return binaries[1]
  end
  -- nio.ui.select holds the vim.ui.select that existed when nio loaded; this
  -- looks it up per call, so a picker plugin set up later is used
  local select = require('nio').wrap(function(items, opts, on_choice)
    vim.ui.select(items, opts, on_choice)
  end, 3)
  local binary = select(binaries, { prompt = 'Test binary', format_item = vim.fs.basename })
  return binary or dap.ABORT
end

--- neotest-zig's debug spec sources ~/.lldbinit unconditionally, and codelldb
--- fails the launch when that file doesn't exist
local function patch_zig_debug_spec()
  local ok, zig = pcall(require, 'neotest-zig')
  if not ok or zig.debug_spec_patched then
    return
  end
  local build_spec = zig._build_spec_with_buildfile
  zig._build_spec_with_buildfile = function(...)
    local spec = build_spec(...)
    if spec and type(spec.strategy) == 'table' then
      spec.strategy.initCommands = nil
      -- only set when the build succeeded
      if spec.strategy.program then
        spec.strategy.program = pick_zig_test_binary
      end
    end
    return spec
  end
  zig.debug_spec_patched = true
end

function M.apply()
  raise_treesitter_match_limit()
  expand_empty_subtest_positions()
  backfill_missing_results()
  fix_golang_discovery_cache()
  patch_zig_debug_spec()
end

return M
