-- Test runner with neotest
-- https://github.com/nvim-neotest/neotest
-- .NET tests handled by easy-dotnet.nvim (see dotnet.lua)

--- Find the nearest directory containing node_modules/.bin/<bin>.
--- Walks up from the path, then checks immediate subdirectories as fallback (monorepo root).
--- Results are cached per (path, bin) since binary locations don't change in a session.
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
  -- Walk-up failed (e.g. monorepo root) — check immediate subdirectories
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

--- Wrap a neotest function to skip .cs files (handled by easy-dotnet).
local function neotest_fn(fn)
  return function()
    if vim.bo.filetype ~= 'cs' then
      fn()
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
    -- Adapters
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
    {
      '[t',
      function()
        require('neotest').jump.prev { status = 'failed' }
      end,
      desc = 'Test: Prev failed',
    },
    {
      ']t',
      function()
        require('neotest').jump.next { status = 'failed' }
      end,
      desc = 'Test: Next failed',
    },
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-golang' {
          go_test_args = { '-v', '-count=1' },
        },
        require 'neotest-vitest' {
          vitestCommand = function(path)
            local dir = find_vitest_root(path)
            if not dir then
              return 'vitest'
            end
            -- Return `node <vitest.mjs>` rather than the .bin/vitest wrapper:
            -- neotest-vitest passes command[1] as DAP's `runtimeExecutable`,
            -- which must be a node-equivalent runtime. Using `.bin/vitest`
            -- directly breaks package.json resolution under js-debug-adapter.
            local vitest_mjs = dir .. '/node_modules/vitest/vitest.mjs'
            if vim.uv.fs_stat(vitest_mjs) then
              return 'node ' .. vitest_mjs
            end
            return dir .. '/node_modules/.bin/vitest'
          end,
          -- Don't override cwd: neotest-vitest defaults to the dir of the
          -- nearest vitest.config.*, which is the per-project root in a
          -- monorepo. Forcing the hoisted-node_modules root here causes
          -- vitest's per-project `include` globs to miss the test file.
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
          -- Only claim files when a jest binary is reachable, so this adapter stays
          -- out of vitest projects (which use the same .test./.spec. naming).
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
          expand = { 'o', '<2-LeftMouse>' },
          output = 'p',
        },
      },
      output = {
        open_on_run = false,
      },
      floating = {
        border = 'rounded',
        max_height = 0.7,
        max_width = 0.7,
      },
      status = {
        virtual_text = true,
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

    -- Close output preview on any keypress for a transient popup feel
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
