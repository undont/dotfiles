-- .NET development: roslyn.nvim for LSP, easy-dotnet.nvim for build/run/debug
-- https://github.com/seblyng/roslyn.nvim
-- https://github.com/GustavEikaas/easy-dotnet.nvim

--- @param path string
--- @return boolean
local function is_build_variant(path)
  return vim.fs.basename(path):match '%.[%l][%w]*%.slnx?$' ~= nil
end

return {
  -- Roslyn LSP via roslyn.nvim (diagnostics, go-to-def, hover, completions)
  {
    'seblyng/roslyn.nvim',
    ft = { 'cs' },
    dependencies = { 'mason-org/mason.nvim' },
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      -- Exclude build-variant solutions (.ci.slnx, .build.sln, .test.sln, etc.)
      -- from target discovery so only the primary solution remains.
      ignore_target = function(target)
        return is_build_variant(target)
      end,
      broad_search = true,
      lock_target = true,
    },
    init = function()
      -- Prevent plugin/roslyn.lua from running during load. It calls
      -- vim.lsp.enable("roslyn") which triggers root_dir BEFORE our config
      -- function applies lock_target + ignore_target, causing the
      -- "Multiple potential target files found" message. We source it
      -- ourselves in config after setup is applied.
      vim.g.loaded_roslyn_plugin = true
    end,
    config = function(_, opts)
      -- Pre-resolve the target solution. With lock_target enabled,
      -- roslyn.nvim's root_dir checks this global first, bypassing
      -- the multi-target picker entirely.
      if not vim.g.roslyn_nvim_selected_solution then
        local buf_path = vim.api.nvim_buf_get_name(0)
        if buf_path ~= '' then
          local sln_files = vim.fs.find(function(name)
            return (name:match '%.sln$' or name:match '%.slnx$') and not is_build_variant(name)
          end, { upward = true, path = vim.fs.dirname(buf_path), limit = math.huge })
          if #sln_files > 0 then
            table.sort(sln_files, function(a, b)
              return #vim.fs.basename(a) < #vim.fs.basename(b)
            end)
            vim.g.roslyn_nvim_selected_solution = sln_files[1]
          end
        end
      end

      -- Filter known Roslyn false positives from C# diagnostics.
      -- IDE0005: false-positives on usings consumed by source generators or test frameworks
      -- IDE0079: false-positives on pragmas for third-party analysers (SonarAnalyzer, etc.)
      -- CA1825: false-positives on C# 12 collection expressions (misidentified as zero-length arrays)
      -- Wraps vim.diagnostic.set to intercept diagnostics before display.
      local orig_diag_set = vim.diagnostic.set
      local roslyn_false_positives = { IDE0005 = true, IDE0079 = true, CA1825 = true }

      -- Track diagnostic keys per buffer to deduplicate across namespaces.
      -- Roslyn reports the same file from multiple .csproj contexts, each with
      -- its own diagnostic namespace. Without cross-namespace dedup, identical
      -- diagnostics appear twice in Trouble/quickfix.
      local buf_diag_owners = {} ---@type table<integer, table<string, integer>>

      vim.diagnostic.set = function(namespace, bufnr, diagnostics, diag_opts)
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'cs' then
          -- Suppress diagnostics on decompiled metadata source (read-only library code)
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          if bufname:match 'MetadataAsSource' then
            return orig_diag_set(namespace, bufnr, {}, diag_opts)
          end

          -- Clear this namespace's previous ownership claims so stale entries
          -- don't block diagnostics that moved between namespaces.
          if not buf_diag_owners[bufnr] then
            buf_diag_owners[bufnr] = {}
          end
          for key, ns in pairs(buf_diag_owners[bufnr]) do
            if ns == namespace then
              buf_diag_owners[bufnr][key] = nil
            end
          end

          -- Filter false positives and deduplicate across namespaces.
          local deduped = {}
          for _, d in ipairs(diagnostics) do
            if not roslyn_false_positives[d.code] then
              local key = d.lnum .. ':' .. d.col .. ':' .. (d.code or '') .. ':' .. d.message
              if not buf_diag_owners[bufnr][key] then
                buf_diag_owners[bufnr][key] = namespace
                table.insert(deduped, d)
              end
            end
          end
          diagnostics = deduped
        end
        return orig_diag_set(namespace, bufnr, diagnostics, diag_opts)
      end

      vim.api.nvim_create_autocmd('BufWipeout', {
        callback = function(ev)
          buf_diag_owners[ev.buf] = nil
        end,
      })

      -- Fix misclassified semantic tokens on using directives.
      -- Roslyn marks unresolved identifiers (e.g. FastEndpoints) as "variable"
      -- instead of "namespace", making them appear unstyled. Override to @type.
      vim.api.nvim_create_autocmd('LspTokenUpdate', {
        callback = function(ev)
          local token = ev.data.token
          if token.type ~= 'variable' then
            return
          end
          local line = vim.api.nvim_buf_get_lines(ev.buf, token.line, token.line + 1, false)[1]
          if not line or not line:match '^%s*using%s' or line:match '[%(=]' then
            return
          end
          vim.lsp.semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, '@type')
        end,
      })

      -- Configure Roslyn LSP settings (background analysis, completions)
      vim.lsp.config('roslyn', {
        settings = {
          ['csharp|background_analysis'] = {
            dotnet_analyzer_diagnostics_scope = 'openFiles',
            dotnet_compiler_diagnostics_scope = 'openFiles',
          },
          ['csharp|completion'] = {
            dotnet_show_completion_items_from_unimported_namespaces = true,
            dotnet_show_name_completion_suggestions = true,
          },
          ['csharp|code_lens'] = {
            dotnet_enable_references_code_lens = true,
            dotnet_enable_tests_code_lens = true,
          },
        },
      })

      -- Apply roslyn.nvim config BEFORE enabling the LSP, so that
      -- lock_target + ignore_target are set when root_dir runs.
      require('roslyn').setup(opts)

      -- Now source the plugin file we deferred in init. This calls
      -- vim.lsp.enable("roslyn") and registers roslyn.nvim's autocmds
      -- (diagnostic refresh, source-generated file handler, commands).
      vim.g.loaded_roslyn_plugin = nil
      local plugin_file = vim.api.nvim_get_runtime_file('plugin/roslyn.lua', false)[1]
      if plugin_file then
        dofile(plugin_file)
      end
    end,
  },

  -- easy-dotnet.nvim for build, run, debug, test (LSP handled by roslyn.nvim)
  {
    'GustavEikaas/easy-dotnet.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'mfussenegger/nvim-dap',
    },
    ft = { 'cs', 'fsharp', 'vb' },
    config = function()
      require('easy-dotnet').setup {
        -- Debugger: auto-registers coreclr adapter with nvim-dap
        debugger = {
          auto_register_dap = true,
          console = 'integratedTerminal',
        },
        -- LSP handled by roslyn.nvim
        lsp = {
          enabled = false,
        },
        -- Test runner: gutter signs, buffer test execution, explorer UI
        test_runner = {
          enable_buffer_test_execution = true,
          auto_start_testrunner = true,
          viewmode = 'float',
          mappings = {
            run_test_from_buffer = { lhs = '<leader>tr', desc = '[R]un test' },
            debug_test_from_buffer = { lhs = '<leader>td', desc = '[D]ebug test' },
            peek_stack_trace_from_buffer = { lhs = '<leader>tp', desc = '[P]eek stacktrace' },
            run = { lhs = '<leader>r', desc = 'run test' },
            run_all = { lhs = '<leader>R', desc = 'run all tests' },
            debug_test = { lhs = '<leader>d', desc = 'debug test' },
            peek_stacktrace = { lhs = '<leader>p', desc = 'peek stacktrace' },
            go_to_file = { lhs = '<leader>g', desc = 'go to file' },
            get_build_errors = { lhs = '<leader>e', desc = 'build errors' },
            refresh_testrunner = { lhs = '<C-r>', desc = 'refresh' },
            cancel = { lhs = '<C-c>', desc = 'cancel' },
            close = { lhs = 'q', desc = 'close' },
            expand = { lhs = 'o', desc = 'expand' },
            expand_node = { lhs = 'E', desc = 'expand all' },
            collapse_all = { lhs = 'W', desc = 'collapse all' },
          },
        },
        -- Custom terminal: open on right side with 40 column width (same as fugitive)
        terminal = function(path, action, args)
          args = args or ''
          local commands = {
            run = function()
              return string.format('dotnet run --project %s %s', path, args)
            end,
            test = function()
              return string.format('dotnet test %s %s', path, args)
            end,
            restore = function()
              return string.format('dotnet restore %s %s', path, args)
            end,
            build = function()
              return string.format('dotnet build %s %s', path, args)
            end,
            watch = function()
              return string.format('dotnet watch --project %s %s', path, args)
            end,
          }
          local command = commands[action]()
          -- Open vertical split on the right with 40 columns (same width as fugitive)
          vim.cmd 'botright vsplit'
          vim.cmd 'vertical resize 40'
          vim.cmd('term ' .. command)
        end,
      }

      -- Project commands
      vim.keymap.set('n', '<leader>nd', '<cmd>Dotnet debug<cr>', { desc = '[D]ebug project' })
      vim.keymap.set('n', '<leader>nr', '<cmd>Dotnet run<cr>', { desc = '[R]un project' })
      vim.keymap.set('n', '<leader>nb', '<cmd>Dotnet build<cr>', { desc = '[B]uild project' })
      vim.keymap.set('n', '<leader>nc', '<cmd>Dotnet clean<cr>', { desc = '[C]lean project' })
      vim.keymap.set('n', '<leader>ns', '<cmd>Dotnet secrets<cr>', { desc = 'Manage [S]ecrets' })
      vim.keymap.set('n', '<leader>nw', '<cmd>Dotnet watch<cr>', { desc = '[W]atch project' })
      vim.keymap.set('n', '<leader>nn', '<cmd>Dotnet new<cr>', { desc = '[N]ew item' })
      vim.keymap.set('n', '<leader>no', '<cmd>Dotnet outdated<cr>', { desc = '[O]utdated packages' })

      -- Test runner (easy-dotnet's built-in test explorer)
      vim.keymap.set('n', '<leader>te', function()
        require('easy-dotnet.test-runner').open()
      end, { desc = 'Test [E]xplorer (.NET)' })
    end,
  },
}
