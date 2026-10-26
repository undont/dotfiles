-- nvim-dap with dap-view; adapters and configurations live in features/dap-configs.lua

-- stepping while the top frame is runtime.goexit ends the goroutine mid-step.
-- delve conditions its stepping breakpoints on that goroutine id, so they can
-- never fire again, and every later step fails with "next while nexting" until
-- a halt cancels it. refuse the step and leave continue as the way out
local function step(cmd)
  return function()
    local dap = require 'dap'
    local session = dap.session()
    local frame = session and session.current_frame
    if frame and frame.name == 'runtime.goexit' then
      vim.notify('dap: goroutine has finished, continue (F5) instead of stepping', vim.log.levels.WARN)
      return
    end
    dap[cmd]()
  end
end

return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'igorlfs/nvim-dap-view',
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',
    'leoluz/nvim-dap-go',
    'mfussenegger/nvim-dap-python',
    'jbyuki/one-small-step-for-vimkind',
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
      '<F6>',
      function()
        require('dap').pause()
      end,
      desc = 'Debug: Pause (cancels an interrupted step)',
    },
    {
      '<F1>',
      step 'step_into',
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      step 'step_over',
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      step 'step_out',
      desc = 'Debug: Step Out',
    },
    {
      '<F7>',
      function()
        require('dap-view').toggle()
      end,
      desc = 'Debug: Toggle UI',
    },
    {
      '<F4>',
      function()
        require('features.dap-configs').stop()
      end,
      desc = 'Debug: Stop (detaches from an attached program)',
    },
    {
      '<F8>',
      function()
        require('dap').run_to_cursor()
      end,
      desc = 'Debug: Run to cursor',
    },
    {
      '<F9>',
      function()
        require('dap').run_last()
      end,
      desc = 'Debug: Run last',
    },
    {
      '<leader>rb',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Toggle [B]reakpoint',
    },
    {
      '<leader>rc',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = '[C]onditional breakpoint',
    },
    {
      '<leader>rL',
      function()
        require('dap').set_breakpoint(nil, nil, vim.fn.input 'Log message: ')
      end,
      desc = '[L]ogpoint',
    },
    {
      '<leader>rl',
      function()
        require('features.dap-breakpoints').open()
      end,
      desc = 'Breakpoint [L]ist',
    },
    {
      '<leader>rw',
      '<Cmd>DapViewWatch<CR>',
      desc = '[W]atch expression',
    },
    {
      '<leader>rw',
      ':DapViewWatch<CR>',
      mode = 'v',
      desc = '[W]atch selection',
    },
    {
      '<leader>rh',
      function()
        require('dap.ui.widgets').hover()
      end,
      desc = '[H]over value',
    },
    {
      '<leader>ra',
      function()
        require('features.dap-configs').attach()
      end,
      desc = '[A]ttach',
    },
    {
      '<leader>ro',
      function()
        require('features.dap-configs').osv_toggle()
      end,
      desc = '[O]sv server for this nvim',
    },
  },
  config = function()
    local dapview = require 'dap-view'

    require('features.dap-configs').setup()

    -- one bottom panel with a winbar to switch sections, landing on scopes.
    -- `auto_toggle` opens it on session start and closes it when all sessions finish
    dapview.setup {
      winbar = {
        show = true,
        sections = { 'watches', 'scopes', 'threads', 'breakpoints', 'exceptions', 'repl' },
        default_section = 'scopes',
        controls = {
          enabled = true,
          position = 'right',
        },
      },
      windows = {
        size = 0.3,
        position = 'below',
        terminal = {
          size = 0.5,
          position = 'left',
          -- delve uses an external terminal
          hide = { 'go' },
        },
      },
      -- `o` alongside `<CR>` for expand/jump in every view; threads' default
      -- `o` (invert_filter) moves to `O`
      keymaps = {
        scopes = { toggle = { '<CR>', 'o', '<2-LeftMouse>' } },
        watches = { toggle = { '<CR>', 'o', '<2-LeftMouse>' } },
        hover = { toggle = { '<CR>', 'o', '<2-LeftMouse>' } },
        threads = { invert_filter = 'O', jump_to_frame = { '<CR>', 'o', '<2-LeftMouse>' } },
        exceptions = { toggle_filter = { '<CR>', 'o', '<2-LeftMouse>' } },
        sessions = { switch_session = { '<CR>', 'o', '<2-LeftMouse>' } },
        breakpoints = { jump_to_breakpoint = { '<CR>', 'o', '<2-LeftMouse>' } },
      },
      -- inline variable values next to code. requires nvim 0.12+
      virtual_text = {
        enabled = true,
      },
      auto_toggle = true,
    }

    vim.api.nvim_set_hl(0, 'DapBreak', { link = 'DiagnosticError' })
    vim.api.nvim_set_hl(0, 'DapStop', { link = 'DiagnosticWarn' })
    local breakpoint_icons = vim.g.have_nerd_font and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
      or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    for type, icon in pairs(breakpoint_icons) do
      local tp = 'Dap' .. type
      local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
      vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    end
  end,
}
