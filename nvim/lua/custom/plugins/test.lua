-- Test runner with neotest
-- https://github.com/nvim-neotest/neotest
-- .NET tests handled by easy-dotnet.nvim (see dotnet.lua)

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
    { 'fredrikaverpil/neotest-golang', tag = 'v1.15.1' }, -- Go (v2+ needs statement_list, not yet in nvim-treesitter's parser)
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
          runner = 'gotestsum',
          go_test_args = { '-v', '-count=1' },
        },
        require 'neotest-vitest' {
          vitestCommand = 'bun run test',
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
