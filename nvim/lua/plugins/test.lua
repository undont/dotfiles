-- neotest. .NET tests run through easy-dotnet.nvim (see dotnet.lua)

--- nearest directory containing node_modules/.bin/<bin>: walks up from the
--- path, then checks immediate subdirectories (monorepo root)
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

--- skips .cs files, which easy-dotnet handles
local function neotest_fn(fn)
  return function()
    if vim.bo.filetype ~= 'cs' then
      fn()
    end
  end
end

--- a .rs buffer outside every known root becomes a new root at its own
--- directory once is_test_file accepts it (client _update_adapters). stdlib and
--- dependency sources, opened by go-to-definition or stepping, would each start
--- a discovery that sends every file in them through rust-analyzer
local function rust_adapter()
  local adapter = require 'rustaceanvim.neotest'
  local is_test_file = adapter.is_test_file
  local toolchain_dirs = {
    (vim.env.RUSTUP_HOME or vim.fs.joinpath(vim.env.HOME, '.rustup')) .. '/',
    (vim.env.CARGO_HOME or vim.fs.joinpath(vim.env.HOME, '.cargo')) .. '/',
  }
  adapter.is_test_file = function(path)
    for _, dir in ipairs(toolchain_dirs) do
      if vim.startswith(path, dir) then
        return false
      end
    end
    return is_test_file(path)
  end
  return adapter
end

--- the summary's expanded set lives on each adapter's SummaryComponent with no
--- public function to clear it. the constructor is wrapped to collect the
--- instances, before neotest.setup requires the consumer
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

--- rows of `position_type`, found by the highlight the name carries, which is independent of run status
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

--- steps the cursor between those rows, wrapping with a notification
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
    'nvim-treesitter/nvim-treesitter',
    'fredrikaverpil/neotest-golang',
    'marilari88/neotest-vitest',
    'haydenmeade/neotest-jest',
    'nvim-neotest/neotest-python',
    'MisanthropicBit/neotest-busted',
    'mrcjkb/rustaceanvim',
    -- upstream lawrence-laz/neotest-zig stops at zig 0.14; this fork's runner
    -- builds on 0.17. pinned to the reviewed commit
    { 'ahmedalhulaibi/neotest-zig', commit = '8e826dbb770a1fffa4c8b184e3cbaefa372f7991' },
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
    { '<leader>td', neotest_fn(function()
      require('neotest').run.run { strategy = 'dap' }
    end), desc = '[D]ebug nearest' },
    -- watch is a `test:` entry in the <leader>q picker
    -- (features/run.lua)
  },
  config = function()
    require('features.neotest-patches').apply()
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
            -- `node <vitest.mjs>`, not the .bin/vitest wrapper: neotest-vitest
            -- passes command[1] as DAP's `runtimeExecutable`, which must be a
            -- node runtime
            local vitest_mjs = dir .. '/node_modules/vitest/vitest.mjs'
            if vim.uv.fs_stat(vitest_mjs) then
              return 'node ' .. vitest_mjs
            end
            return dir .. '/node_modules/.bin/vitest'
          end,
          -- cwd stays at neotest-vitest's default, the dir of the nearest
          -- vitest.config.*; from the hoisted-node_modules root vitest's
          -- per-project `include` globs miss the test file
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
          -- vitest projects use the same .test./.spec. naming, so a jest binary must be reachable
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
        require 'neotest-busted' {
          local_luarocks_only = false,
          -- its package.path drops lua's default ./?.lua, which plain busted
          -- resolves spec helpers like require('test.fixtures') through
          busted_paths = { './?.lua', './?/init.lua' },
        },
        -- test discovery and commands come from rust-analyzer; the dap strategy reuses :RustLsp debuggables
        rust_adapter(),
        require 'neotest-zig' {
          dap = { adapter = 'codelldb' },
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
          -- buffer-local, shadowing the global ]t/[t with the summary's tree walk
          next_failed = { 'J', ']t' },
          prev_failed = { 'K', '[t' },
        },
      },
      output = {
        open_on_run = false,
      },
      -- neotest's quickfix consumer pushes an untitled list on every failing
      -- run, which drops the forward half of the qf stack and pauses the
      -- <leader>xx diagnostics sync (it rebuilds only while the current list
      -- is titled `Diagnostics: all`)
      quickfix = { enabled = false },
      -- test output is a terminal buffer: in a window narrower than the pty
      -- it was written at (vim.o.columns) the scrollback is truncated, not
      -- reflowed. width stays min(content, max_width - 2)
      floating = {
        border = 'rounded',
        max_height = 0.7,
        max_width = 0.95,
      },
      -- ]t/[t read the failed signs (see features/lists.lua)
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

    -- the diagnostic consumer publishes failures as ERROR diagnostics. their
    -- underline and sign are dropped: neotest's status sign has the gutter
    -- cell, and plugins/diagnostics.lua keeps the message out of the inline
    -- renderer. the namespace stays populated for the statusline count and
    -- for ]t/[t (features/statusline.lua, features/lists.lua)
    vim.diagnostic.config({ underline = false, signs = false }, vim.api.nvim_create_namespace 'neotest')

    -- C/O collapse and expand the whole tree; the canvas only rebinds its own action keys on render
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
        -- ]f/[f and ]]/[[ step files and dirs; mini.bracketed's file jump cannot edit a winfixbuf window
        map(']f', summary_row_jump('file', true), 'Next file')
        map('[f', summary_row_jump('file', false), 'Previous file')
        map(']]', summary_row_jump('dir', true), 'Next directory')
        map('[[', summary_row_jump('dir', false), 'Previous directory')
      end,
    })

    -- any keypress closes the output preview
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
