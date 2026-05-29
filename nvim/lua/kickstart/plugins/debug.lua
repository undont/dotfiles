-- debug.lua
--
-- Debug Adapter Protocol client with UI and inline variable display.
-- Go debugging via Delve, extensible to other languages.

return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'igorlfs/nvim-dap-view',
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',
    'leoluz/nvim-dap-go',
    'mfussenegger/nvim-dap-python',
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
        require('dap-view').toggle()
      end,
      desc = 'Debug: Toggle UI',
    },
    {
      '<leader>bb',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Toggle [B]reakpoint',
    },
    {
      '<leader>bc',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = '[C]onditional breakpoint',
    },
    {
      '<leader>bL',
      function()
        require('dap').set_breakpoint(nil, nil, vim.fn.input 'Log message: ')
      end,
      desc = 'Breakpoint [L]ogpoint',
    },
    {
      '<leader>bl',
      function()
        local bp_mod = require 'dap.breakpoints'
        local bps = bp_mod.get()
        local lines = {}
        local entries = {}
        for bufnr, buf_bps in pairs(bps) do
          local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':~:.')
          for _, bp in ipairs(buf_bps) do
            local suffix = bp.condition and ('  [if: ' .. bp.condition .. ']') or bp.logMessage and ('  [log: ' .. bp.logMessage .. ']') or ''
            table.insert(lines, string.format('%s:%d%s', name, bp.line, suffix))
            table.insert(entries, { bufnr = bufnr, line = bp.line })
          end
        end
        if #lines == 0 then
          vim.notify('No breakpoints set', vim.log.levels.INFO)
          return
        end

        -- Editable scratch buffer — delete lines to remove breakpoints
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].filetype = 'dap-breakpoints'

        local max_line = 0
        for _, l in ipairs(lines) do
          max_line = math.max(max_line, #l)
        end
        local width = math.min(math.max(max_line + 4, 60), math.floor(vim.o.columns * 0.8))
        local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.4))
        vim.api.nvim_open_win(buf, true, {
          relative = 'editor',
          width = width,
          height = height,
          col = math.floor((vim.o.columns - width) / 2),
          row = math.floor((vim.o.lines - height) / 2),
          style = 'minimal',
          border = 'rounded',
          title = ' Breakpoints ',
          title_pos = 'center',
        })

        local function sync_and_close()
          local remaining = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          local keep = {}
          for _, line in ipairs(remaining) do
            keep[line] = true
          end
          local removed = 0
          for i, original_line in ipairs(lines) do
            if not keep[original_line] then
              local entry = entries[i]
              bp_mod.remove(entry.bufnr, entry.line)
              removed = removed + 1
            end
          end
          vim.bo[buf].modified = false
          vim.api.nvim_win_close(0, true)
          if removed > 0 then
            vim.notify(string.format('Removed %d breakpoint%s', removed, removed == 1 and '' or 's'), vim.log.levels.INFO)
          end
        end

        vim.keymap.set('n', 'q', sync_and_close, { buffer = buf })
        vim.keymap.set('n', '<Esc>', sync_and_close, { buffer = buf })
        vim.keymap.set('n', '<CR>', function()
          local row = vim.api.nvim_win_get_cursor(0)[1]
          local entry = entries[row]
          if entry then
            vim.bo[buf].modified = false
            vim.api.nvim_win_close(0, true)
            vim.api.nvim_set_current_buf(entry.bufnr)
            vim.api.nvim_win_set_cursor(0, { entry.line, 0 })
          end
        end, { buffer = buf })
      end,
      desc = '[B]reakpoint [L]ist',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapview = require 'dap-view'

    require('mason-nvim-dap').setup {
      -- ensure_installed handles upfront install; automatic_installation races
      -- with it whenever an adapter is registered via dap.adapters[...] in the
      -- same session, leaving installs stuck mid-flight (lockfile collision).
      automatic_installation = false,
      handlers = {},
      ensure_installed = { 'delve', 'coreclr', 'debugpy', 'js', 'codelldb' },
    }

    -- Single bottom panel with a winbar to switch sections (scopes is the
    -- landing view, matching the old scopes-heavy sidebar). The debuggee
    -- terminal/console sits in its own split alongside. `auto_toggle` opens
    -- the panel on session start and closes it when all sessions finish,
    -- replacing the manual event listeners dap-ui needed.
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
          -- Go's delve uses an external terminal; no point reserving a split.
          hide = { 'go' },
        },
      },
      -- Inline variable values next to code (like Rider/GoLand). dap-view's
      -- own implementation, registered against dap's `variables` event, so it
      -- replaces the separate nvim-dap-virtual-text plugin. Requires nvim 0.12+
      -- and auto-clears when the session terminates.
      virtual_text = {
        enabled = true,
      },
      auto_toggle = true,
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

    require('dap-go').setup {
      delve = {
        detached = vim.fn.has 'win32' == 0,
      },
    }

    -- Attach to an already-running process via a headless delve. Start it
    -- yourself with one of:
    --   dlv attach <pid> --headless --listen=127.0.0.1:38697 --api-version=2
    --   dlv exec ./binary --headless --listen=127.0.0.1:38697 --api-version=2
    -- This is the only working path for TUI binaries — delve's DAP server
    -- ignores `console: integratedTerminal` when actually debugging (only
    -- honoured for noDebug runs), and `dlv dap` has no `--tty` flag, so a
    -- pure-launch flow always gives the debuggee pipe-based stdio. Using
    -- `dlv debug --tty=<pty>` in headless mode + this attach config is the
    -- workaround if you want delve to launch the binary against a real PTY.
    dap.configurations.go = dap.configurations.go or {}
    table.insert(dap.configurations.go, {
      type = 'go',
      name = 'Attach (remote dlv)',
      request = 'attach',
      mode = 'remote',
      host = '127.0.0.1',
      port = function()
        return tonumber(vim.fn.input 'dlv headless port: ' or '') or 38697
      end,
    })

    -- Point dap-python at Mason's debugpy venv so it doesn't depend on a
    -- project-local venv being active. nvim-dap-python falls back to the
    -- project venv automatically when one is detected.
    require('dap-python').setup(vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python')

    -- JS/TS debugger (vscode-js-debug via Mason). `${port}` makes nvim-dap
    -- pick a free port per session and spawn the adapter as a child — so a
    -- crashed session can't leave an orphan squatting on a fixed port.
    -- neotest-vitest's `strategy = 'dap'` picks this up automatically.
    local js_debug_server = vim.fn.stdpath 'data' .. '/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js'
    for _, adapter in ipairs { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost' } do
      dap.adapters[adapter] = {
        type = 'server',
        host = 'localhost',
        port = '${port}',
        executable = {
          command = 'node',
          args = { js_debug_server, '${port}' },
        },
      }
    end

    -- codelldb (via Mason) debugs the native C family and Swift. `${port}` lets
    -- nvim-dap pick a free port per session and spawn the adapter as a child, so
    -- a crashed session can't leave an orphan squatting on a fixed port (same
    -- pattern as the JS adapters above).
    dap.adapters.codelldb = {
      type = 'server',
      port = '${port}',
      executable = {
        command = vim.fn.stdpath 'data' .. '/mason/packages/codelldb/extension/adapter/codelldb',
        args = { '--port', '${port}' },
      },
    }

    -- Shared launch config: prompt for the compiled binary. Point this at the
    -- product of your build (e.g. `.build/debug/<target>` for SwiftPM, or the
    -- binary clang/cmake emits). Compile with debug symbols (`-g`).
    local codelldb_launch = {
      {
        name = 'Launch (codelldb)',
        type = 'codelldb',
        request = 'launch',
        program = function()
          return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        args = {},
      },
    }
    dap.configurations.c = codelldb_launch
    dap.configurations.cpp = codelldb_launch
    dap.configurations.objc = codelldb_launch
    dap.configurations.swift = codelldb_launch
  end,
}
