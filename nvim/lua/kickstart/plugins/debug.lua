-- debug.lua
--
-- Debug Adapter Protocol client with UI and inline variable display.
-- Go debugging via Delve, extensible to other languages.

return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',
    'leoluz/nvim-dap-go',
    'theHamsta/nvim-dap-virtual-text',
  },
  keys = {
    {
      '<F5>',
      function()
        require('dap').continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F1>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<F7>',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: Toggle UI',
    },
    {
      '<leader>Bt',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>Bc',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Debug: Conditional Breakpoint',
    },
    {
      '<leader>Bl',
      function()
        require('dap').set_breakpoint(nil, nil, vim.fn.input 'Log message: ')
      end,
      desc = 'Debug: Logpoint',
    },
    {
      '<leader>BB',
      function()
        require('dap').list_breakpoints(true)
      end,
      desc = 'Debug: List all Breakpoints',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      automatic_installation = true,
      handlers = {},
      ensure_installed = { 'delve', 'coreclr' },
    }

    -- Inline variable values next to code (like Rider/GoLand)
    require('nvim-dap-virtual-text').setup {
      commented = true,
    }

    -- UI layout: scopes-heavy sidebar + REPL-focused bottom
    dapui.setup {
      icons = { expanded = '▾', collapsed = '▸', current_frame = '' },
      layouts = {
        {
          elements = {
            { id = 'scopes', size = 0.50 },
            { id = 'stacks', size = 0.20 },
            { id = 'breakpoints', size = 0.15 },
            { id = 'watches', size = 0.15 },
          },
          position = 'left',
          size = 50,
        },
        {
          elements = {
            { id = 'repl', size = 0.65 },
            { id = 'console', size = 0.35 },
          },
          position = 'bottom',
          size = 12,
        },
      },
    }

    -- Breakpoint icons
    vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    local breakpoint_icons = vim.g.have_nerd_font and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
      or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    for type, icon in pairs(breakpoint_icons) do
      local tp = 'Dap' .. type
      local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
      vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    require('dap-go').setup {
      delve = {
        detached = vim.fn.has 'win32' == 0,
      },
    }
  end,
}
