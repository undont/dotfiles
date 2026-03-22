-- Test runner with neotest
-- https://github.com/nvim-neotest/neotest

return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    -- Adapters
    'Issafalcon/neotest-dotnet', -- .NET (xUnit, NUnit, MSTest)
    { 'fredrikaverpil/neotest-golang', tag = 'v1.15.1' }, -- Go (v2+ needs statement_list, not yet in nvim-treesitter's parser)
    'marilari88/neotest-vitest', -- Vitest/Bun test runner
  },
  keys = {
    {
      '<leader>tt',
      function()
        require('neotest').run.run()
      end,
      desc = 'Run neares[T]',
    },
    {
      '<leader>tf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = 'Run [F]ile',
    },
    {
      '<leader>ta',
      function()
        require('neotest').run.run { suite = true }
      end,
      desc = 'Run [A]ll',
    },
    {
      '<leader>tl',
      function()
        require('neotest').run.run_last()
      end,
      desc = 'Run [L]ast',
    },
    {
      '<leader>ts',
      function()
        require('neotest').summary.toggle()
      end,
      desc = 'Toggle [S]ummary',
    },
    {
      '<leader>to',
      function()
        require('neotest').output.open { enter = true, auto_close = true }
      end,
      desc = 'Show [O]utput',
    },
    {
      '<leader>tO',
      function()
        require('neotest').output_panel.toggle()
      end,
      desc = 'Toggle [O]utput panel',
    },
    {
      '<leader>tS',
      function()
        require('neotest').run.stop()
      end,
      desc = '[S]top',
    },
    {
      '<leader>tw',
      function()
        require('neotest').watch.toggle(vim.fn.expand '%')
      end,
      desc = 'Toggle [W]atch',
    },
    {
      '<leader>td',
      function()
        require('neotest').run.run { strategy = 'dap' }
      end,
      desc = '[D]ebug nearest',
    },
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
    local dotnet_adapter = require 'neotest-dotnet' {
      discovery_root = 'project',
      dap = { adapter_name = 'coreclr' },
    }

    -- Monkey-patch: force main-process parsing for dotnet tests.
    -- neotest-dotnet's NUnit build_position calls get_node_text(node, string_source)
    -- which crashes in Neovim 0.11 subprocess with ":start() nil". The subprocess
    -- error propagates through nio as a throw (not a return), so neotest's built-in
    -- fallback never runs. We disable subprocess for dotnet discovery only.
    local orig_discover = dotnet_adapter.discover_positions
    dotnet_adapter.discover_positions = function(path)
      local lib = require 'neotest.lib'
      local orig_enabled = lib.subprocess.enabled
      lib.subprocess.enabled = function()
        return false
      end
      local ok, result = pcall(orig_discover, path)
      lib.subprocess.enabled = orig_enabled
      if not ok then
        local logger = require 'neotest.logging'
        logger.warn('neotest-dotnet: discovery failed for ' .. path .. ': ' .. tostring(result))
        local Tree = require 'neotest.types.tree'
        return Tree.from_list({ { id = path, path = path, name = vim.fn.fnamemodify(path, ':t'), type = 'file' } }, function(pos)
          return pos.id
        end)
      end
      return result
    end

    require('neotest').setup {
      adapters = {
        dotnet_adapter,
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
