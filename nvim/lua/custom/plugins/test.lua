-- Test runner with neotest
-- https://github.com/nvim-neotest/neotest
-- .NET tests handled by easy-dotnet.nvim (see dotnet.lua)

--- Find the nearest directory containing node_modules/.bin/vitest.
--- Walks up from the path, then checks immediate subdirectories as fallback (monorepo root).
--- Results are cached per session since vitest root doesn't change.
local vitest_root_cache = {} ---@type table<string, string|false>
local function find_vitest_root(path)
  local key = vim.fn.isdirectory(path) == 1 and path or vim.fn.fnamemodify(path, ':h')
  if vitest_root_cache[key] ~= nil then
    return vitest_root_cache[key] or nil
  end
  local dir = key
  while dir and dir ~= '/' do
    if vim.uv.fs_stat(dir .. '/node_modules/.bin/vitest') then
      vitest_root_cache[key] = dir
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end
  -- Walk-up failed (e.g. monorepo root) — check immediate subdirectories
  for name, type in vim.fs.dir(key) do
    if type == 'directory' and name ~= 'node_modules' then
      if vim.uv.fs_stat(key .. '/' .. name .. '/node_modules/.bin/vitest') then
        vitest_root_cache[key] = key .. '/' .. name
        return vitest_root_cache[key]
      end
    end
  end
  vitest_root_cache[key] = false
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
            return dir and (dir .. '/node_modules/.bin/vitest') or 'vitest'
          end,
          cwd = find_vitest_root,
          filter_dir = function(name)
            return name ~= 'node_modules' and name ~= 'dist' and name ~= '.git' and name ~= 'coverage'
          end,
        },
      },
      summary = {
        animated = true,
        open = 'botright vsplit | vertical resize 50',
      },
      output = {
        open_on_run = false,
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
  end,
}
