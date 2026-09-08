-- test runner with neotest
-- https://github.com/nvim-neotest/neotest
-- .NET tests handled by easy-dotnet.nvim (see dotnet.lua)

--- find the nearest directory containing node_modules/.bin/<bin>.
--- walks up from the path, then checks immediate subdirectories as fallback (monorepo root).
--- results are cached per (path, bin) since binary locations don't change in a session
local node_bin_root_cache = {} ---@type table<string, string|false>
local function find_node_bin_root(path, bin)
  local start = vim.fn.isdirectory(path) == 1 and path or vim.fn.fnamemodify(path, ':h')
  local key = start .. ':' .. bin
  if node_bin_root_cache[key] ~= nil then
    return node_bin_root_cache[key] or nil
  end
  local dir = start
  while dir and dir ~= '/' do
    if vim.uv.fs_stat(dir .. '/node_modules/.bin/' .. bin) then
      node_bin_root_cache[key] = dir
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end
  -- walk-up failed (e.g. monorepo root); check immediate subdirectories
  for name, type in vim.fs.dir(start) do
    if type == 'directory' and name ~= 'node_modules' then
      if vim.uv.fs_stat(start .. '/' .. name .. '/node_modules/.bin/' .. bin) then
        node_bin_root_cache[key] = start .. '/' .. name
        return node_bin_root_cache[key]
      end
    end
  end
  node_bin_root_cache[key] = false
end

local function find_vitest_root(path)
  return find_node_bin_root(path, 'vitest')
end

local function find_jest_root(path)
  return find_node_bin_root(path, 'jest')
end

--- wrap a neotest function to skip .cs files (handled by easy-dotnet)
local function neotest_fn(fn)
  return function()
    if vim.bo.filetype ~= 'cs' then
      fn()
    end
  end
end

--- neotest parses with nvim's default 256 in-progress tree-sitter match cap, and
--- past it the earliest-starting matches are dropped, so long table-driven tests
--- are silently truncated to their tail (43 cases for a keyed `tt := []struct{}`
--- table, 84 for map and unkeyed shapes). neotest takes a match_limit, but no
--- adapter passes one
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

--- the subtest query captures any string literal as a name, so `t.Run("", ...)`
--- yields one position named `""`, while go runs the loop body once per table
--- row and names those `TestX/#00`, `#01` and so on. the single node matches no
--- event, and neotest fills a result-less position with the run root's status
--- (client/runner.lua) and propagates it up, reddening the real parent too.
--- count the rows the loop iterates and stand in one position per row, matching
--- go's numbering; drop the node when the row count can't be read statically
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

--- neotest-golang intermittently returns no result for a position (a file or
--- package whose events were still in flight when the stream was stopped), and
--- neotest fills a result-less position with `failed`, then propagates that over
--- the parent's real status. on a suite run that reddens a random passing
--- package about one run in eight. give any missing position the aggregate of
--- its descendants, and a missing leaf `skipped`, so the fill never fires
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
      -- a leaf whose result was dropped: unknown, which is not the same as failed
      results[pos_id] = { status = 'skipped' }
      return 'skipped'
    end
    fill(tree)
    return results
  end
  rf.missing_results_backfilled = true
end

--- neotest-golang keys its per-file discovery cache on whole-second mtime, so a
--- second write inside the same second is served the stale tree, and nothing
--- expires it afterwards. autosave writes on every normal-mode edit (see
--- core/autocmds.lua), so deleting table test cases strands them in the summary.
--- re-key on the full stat signature, captured before the parse: a write landing
--- mid-parse then leaves the entry stamped stale rather than fresh, costing a
--- re-parse instead of serving stale positions
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

--- the summary's expanded set lives on each adapter's SummaryComponent and no
--- public function clears it (`e` toggles the subtree under the cursor), so a
--- whole-tree collapse needs the instances. wrap the module's constructor before
--- the consumer requires it, which happens inside neotest.setup
local summary_components = {}
local function track_summary_components()
  local module = 'neotest.consumers.summary.component'
  local ok, build = pcall(require, module)
  if not ok or type(build) ~= 'function' then
    return
  end
  package.loaded[module] = function(client, adapter_id)
    local component = build(client, adapter_id)
    summary_components[#summary_components + 1] = component
    return component
  end
end

--- collapse or expand every node in the summary tree
local function set_summary_expanded(expanded)
  require('nio').run(function()
    for _, component in ipairs(summary_components) do
      component.expanded_positions = {}
      if expanded then
        local tree = component.client:get_position(nil, { adapter = component.adapter_id })
        if tree then
          for _, node in tree:iter_nodes() do
            if #node:children() > 0 then
              component.expanded_positions[node:data().id] = true
            end
          end
        end
      end
    end
    require('neotest').summary.render()
  end)
end

--- rows of `position_type`, found the way upstream finds failures: by the
--- highlight the name carries, which is the position's type whatever its run
--- status, so a failing file row is still a file row
local function summary_rows(position_type)
  local group = require('neotest.config').highlights[position_type]
  local ns = require('neotest.consumers.summary.canvas').namespace
  local rows = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    if mark[4].hl_group == group and rows[#rows] ~= mark[2] + 1 then
      rows[#rows + 1] = mark[2] + 1
    end
  end
  return rows
end

--- step the cursor between those rows, wrapping past the ends and saying so, as
--- differ's panel does on the same keys
local function summary_row_jump(position_type, forward)
  return function()
    local rows = summary_rows(position_type)
    if #rows == 0 then
      return
    end
    local cur, target = vim.fn.line '.', nil
    if forward then
      for _, row in ipairs(rows) do
        if row > cur then
          target = row
          break
        end
      end
    else
      for i = #rows, 1, -1 do
        if rows[i] < cur then
          target = rows[i]
          break
        end
      end
    end
    local wrapped = target == nil
    vim.api.nvim_win_set_cursor(0, { target or (forward and rows[1] or rows[#rows]), 0 })
    if wrapped then
      local edge = forward and 'first' or 'last'
      local what = position_type == 'dir' and 'directory' or position_type
      vim.notify(('neotest: wrapped to the %s %s'):format(edge, what), vim.log.levels.INFO)
    end
  end
end

return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    -- adapters
    'fredrikaverpil/neotest-golang', -- Go
    'marilari88/neotest-vitest', -- Vitest/Bun test runner
    'haydenmeade/neotest-jest', -- Jest (React Native, RTL, plain JS/TS)
    'nvim-neotest/neotest-python', -- pytest/unittest
  },
  keys = {
    { '<leader>tt', neotest_fn(function()
      require('neotest').run.run()
    end), desc = 'Run neares[T]' },
    { '<leader>tf', neotest_fn(function()
      require('neotest').run.run(vim.fn.expand '%')
    end), desc = 'Run [F]ile' },
    { '<leader>ta', neotest_fn(function()
      require('neotest').run.run { suite = true }
    end), desc = 'Run [A]ll' },
    { '<leader>tl', neotest_fn(function()
      require('neotest').run.run_last()
    end), desc = 'Run [L]ast' },
    { '<leader>ts', neotest_fn(function()
      require('neotest').summary.toggle()
    end), desc = 'Toggle [S]ummary' },
    { '<leader>to', neotest_fn(function()
      require('neotest').output.open { enter = true, auto_close = true }
    end), desc = 'Show [O]utput' },
    { '<leader>tO', neotest_fn(function()
      require('neotest').output_panel.toggle()
    end), desc = 'Toggle [O]utput panel' },
    { '<leader>tS', neotest_fn(function()
      require('neotest').run.stop()
    end), desc = '[S]top' },
    { '<leader>tw', neotest_fn(function()
      require('neotest').watch.toggle(vim.fn.expand '%')
    end), desc = 'Toggle [W]atch' },
    { '<leader>td', neotest_fn(function()
      require('neotest').run.run { strategy = 'dap' }
    end), desc = '[D]ebug nearest' },
  },
  config = function()
    raise_treesitter_match_limit()
    expand_empty_subtest_positions()
    backfill_missing_results()
    fix_golang_discovery_cache()
    track_summary_components()

    require('neotest').setup {
      adapters = {
        require 'neotest-golang' {
          go_test_args = { '-v', '-count=1' },
          warn_test_name_dupes = false,
        },
        require 'neotest-vitest' {
          vitestCommand = function(path)
            local dir = find_vitest_root(path)
            if not dir then
              return 'vitest'
            end
            -- return `node <vitest.mjs>` rather than the .bin/vitest wrapper:
            -- neotest-vitest passes command[1] as DAP's `runtimeExecutable`,
            -- which must be a node-equivalent runtime. using `.bin/vitest`
            -- directly breaks package.json resolution under js-debug-adapter
            local vitest_mjs = dir .. '/node_modules/vitest/vitest.mjs'
            if vim.uv.fs_stat(vitest_mjs) then
              return 'node ' .. vitest_mjs
            end
            return dir .. '/node_modules/.bin/vitest'
          end,
          -- don't override cwd: neotest-vitest defaults to the dir of the
          -- nearest vitest.config.*, which is the per-project root in a
          -- monorepo. forcing the hoisted-node_modules root here causes
          -- vitest's per-project `include` globs to miss the test file
          filter_dir = function(name)
            return name ~= 'node_modules' and name ~= 'dist' and name ~= '.git' and name ~= 'coverage'
          end,
        },
        require 'neotest-jest' {
          jestCommand = function(path)
            local dir = find_jest_root(path)
            return dir and (dir .. '/node_modules/.bin/jest') or 'jest'
          end,
          cwd = find_jest_root,
          -- only claim files when a jest binary is reachable, so this adapter stays
          -- out of vitest projects (which use the same .test./.spec. naming)
          is_test_file = function(path)
            if not path:match '%.test%.[jt]sx?$' and not path:match '%.spec%.[jt]sx?$' then
              return false
            end
            return find_jest_root(path) ~= nil
          end,
        },
        require 'neotest-python' {
          runner = 'pytest',
          args = { '-v' },
          dap = { justMyCode = false },
        },
      },
      summary = {
        animated = true,
        open = 'botright vsplit | vertical resize 50',
        mappings = {
          expand = { 'o', '<CR>', '<2-LeftMouse>' },
          output = 'p',
          -- short output unbound, which frees O for expand-all below. an empty
          -- list is the disable: a `false` reaches nvim_buf_set_keymap as an lhs
          short = {},
          help = { '?', 'g?' },
          -- buffer-local, so they shadow the global ]t/[t (which walk a source
          -- buffer's failed positions) with the summary's own tree walk. J/K
          -- stay bound
          next_failed = { 'J', ']t' },
          prev_failed = { 'K', '[t' },
        },
      },
      output = {
        open_on_run = false,
      },
      -- neotest's quickfix consumer is on by default and pushes a fresh
      -- untitled list on every failing run, which drops the forward half of
      -- the qf stack and pauses the live <leader>xx diagnostics sync (it only
      -- rebuilds while the current list is titled `Diagnostics: all`). the
      -- summary, signs and ]t/[t jump-to-failed cover the same ground
      quickfix = { enabled = false },
      -- test output is a terminal buffer, so its grid is resized to whatever
      -- window shows it and the scrollback is truncated, not reflowed, when
      -- that window is much narrower than the pty it was written at
      -- (vim.o.columns). at 0.7 a long assertion line lost its tail outright,
      -- and no window option recovers it: the characters are gone from the
      -- buffer. width stays min(content, max_width - 2), so this lifts the
      -- ceiling rather than widening every float
      floating = {
        border = 'rounded',
        max_height = 0.7,
        max_width = 0.95,
      },
      -- ]t/[t read the failed signs to find each failing position, so signs
      -- off leaves them walking diagnostics alone (see features/lists.lua)
      status = {
        virtual_text = false,
        signs = true,
      },
      icons = {
        passed = '✓',
        failed = '✗',
        running = '⟳',
        skipped = '○',
        unknown = '?',
      },
    }

    -- the diagnostic consumer publishes failures as real ERROR diagnostics, so
    -- a failing test drew an error squiggle and an error sign and read as a
    -- file that doesn't compile. keep the message (virtual_lines still puts it
    -- on the failing assertion) but drop both markers: neotest's own ✗ status
    -- sign already owns the gutter cell (priority 1000 against the diagnostic
    -- sign's 10). the statusline counts this namespace separately, as ✗N rather
    -- than EN, and the <leader>xx list filters it out; see features/statusline.lua
    -- and features/lists.lua, where ]t/[t land on this namespace and ]d/[d skip
    -- it. neotest-golang sets severity per error, so `diagnostic.severity`
    -- above wouldn't reach these
    vim.diagnostic.config({ underline = false, signs = false }, vim.api.nvim_create_namespace 'neotest')

    -- C/O collapse and expand the whole tree, as they do in differ's panel.
    -- the canvas rebinds its own action keys on every render but never these,
    -- so they survive
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'neotest-summary',
      callback = function(args)
        local function map(lhs, fn, desc)
          vim.keymap.set('n', lhs, fn, { buffer = args.buf, nowait = true, desc = desc })
        end
        map('C', function()
          set_summary_expanded(false)
        end, 'Collapse all')
        map('O', function()
          set_summary_expanded(true)
        end, 'Expand all')
        -- ]f/[f and ]]/[[ step files and dirs, as they do in differ's panel.
        -- both fall through to mini.bracketed otherwise, whose file jump is
        -- inert here: the summary window is winfixbuf, so its edit can't land
        map(']f', summary_row_jump('file', true), 'Next file')
        map('[f', summary_row_jump('file', false), 'Previous file')
        map(']]', summary_row_jump('dir', true), 'Next directory')
        map('[[', summary_row_jump('dir', false), 'Previous directory')
      end,
    })

    -- close output preview on any keypress for a transient popup feel
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'neotest-output',
      callback = function(args)
        local function close()
          pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
        end
        for _, key in ipairs { '<Esc>', '<CR>', 'q' } do
          vim.keymap.set('n', key, close, { buffer = args.buf, nowait = true })
        end
      end,
    })
  end,
}
