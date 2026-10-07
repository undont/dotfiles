-- .NET development: roslyn.nvim for LSP, easy-dotnet.nvim for build/run/debug
-- https://github.com/seblyng/roslyn.nvim
-- https://github.com/GustavEikaas/easy-dotnet.nvim

--- @param path string
--- @return boolean
local function is_build_variant(path)
  return vim.fs.basename(path):match '%.[%l][%w]*%.slnx?$' ~= nil
end

--- sets the target solution before roslyn.nvim loads, so lock_target skips the multi-target picker
local function resolve_solution_target()
  if vim.g.roslyn_nvim_selected_solution then
    return
  end
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == '' then
    return
  end
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

--- roslyn.nvim's plugin file is blocked in init (vim.g.loaded_roslyn_plugin)
--- and sourced here, after lock_target and ignore_target are set
local function source_deferred_plugin()
  vim.g.loaded_roslyn_plugin = nil
  local plugin_file = vim.api.nvim_get_runtime_file('plugin/roslyn.lua', false)[1]
  if plugin_file then
    dofile(plugin_file)
  end
end

return {
  -- roslyn.nvim loads on `User RealDotnetFile`, which core/autocmds.lua fires
  -- only for buftype='' cs/razor buffers, so differ diff buffers don't load it
  {
    'seblyng/roslyn.nvim',
    event = 'User RealDotnetFile',
    dependencies = { 'mason-org/mason.nvim' },
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      ignore_target = function(target)
        return is_build_variant(target)
      end,
      broad_search = true,
      lock_target = true,
      -- the server watches files, not nvim. on `auto` roslyn registers a
      -- didChangeWatchedFiles watcher per project dir, each an FSEvents handle
      -- on macOS that `Client:stop` cancels before exit, which delays `:q`.
      -- `roslyn` advertises dynamicRegistration=false; `off` watches nothing
      filewatching = 'roslyn',
    },
    init = function()
      vim.g.loaded_roslyn_plugin = true
    end,
    config = function(_, opts)
      resolve_solution_target()
      require('features.roslyn-diagnostics').patch_diagnostic_set()
      require('features.roslyn-semantic-tokens').setup()

      vim.lsp.config('roslyn', {
        -- roslyn's runtimeconfig.json sets System.GC.Server=true, one GC
        -- heap per core. on .NET 9+ environment variables override
        -- runtimeconfig, so DOTNET_gcServer=0 selects workstation GC. cmd_env
        -- merges onto the parent env, so easy-dotnet's processes are
        -- unaffected. under `--daemon-mode` the shared server inherits this
        -- only from the nvim that starts it
        cmd_env = {
          DOTNET_gcServer = '0',
        },
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
            dotnet_enable_references_code_lens = false,
            dotnet_enable_tests_code_lens = false,
          },
        },
      })

      require('roslyn').setup(opts)
      source_deferred_plugin()
    end,
  },

  -- easy-dotnet.nvim: build, run, debug, test
  {
    'GustavEikaas/easy-dotnet.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'mfussenegger/nvim-dap',
    },
    ft = { 'cs', 'fsharp', 'vb' },
    config = function()
      -- copy roslyn.nvim's solution target into easy-dotnet's cache,
      -- overwriting a cached build variant (e.g. .ci.slnx)
      local roslyn_sln = vim.g.roslyn_nvim_selected_solution
      if roslyn_sln then
        local current_solution = require 'easy-dotnet.current_solution'
        local cached = current_solution.try_get_selected_solution()
        if not cached or is_build_variant(cached) then
          current_solution.set_solution(roslyn_sln)
        end
      end

      require('easy-dotnet').setup {
        debugger = {
          auto_register_dap = true,
          console = 'integratedTerminal',
        },
        lsp = {
          enabled = false,
        },
        test_runner = {
          auto_start_testrunner = false,
          viewmode = 'float',
          mappings = {
            -- buffer keymaps in .cs files with tests
            run_test_from_buffer = { lhs = '<leader>tr', desc = '[R]un test' },
            -- run_all_tests_from_buffer is overridden below (upstream runs the whole project)
            debug_test_from_buffer = { lhs = '<leader>td', desc = '[D]ebug test' },
            peek_stack_trace_from_buffer = { lhs = '<leader>tp', desc = '[P]eek stacktrace' },
            -- explorer window keymaps
            run = { lhs = 'r', desc = 'run test' },
            run_all = { lhs = 'R', desc = 'run all tests' },
            debug_test = { lhs = 'd', desc = 'debug test' },
            peek_stacktrace = { lhs = 'p', desc = 'peek stacktrace' },
            go_to_file = { lhs = 'gf', desc = 'go to file' },
            get_build_errors = { lhs = 'ge', desc = 'build errors' },
            refresh_testrunner = { lhs = '<C-r>', desc = 'refresh' },
            cancel = { lhs = '<C-c>', desc = 'cancel' },
            close = { lhs = 'q', desc = 'close' },
            expand = { lhs = 'o', desc = 'expand' },
            expand_node = { lhs = 'E', desc = 'expand all' },
            collapse_all = { lhs = 'W', desc = 'collapse all' },
          },
        },
      }

      vim.keymap.set('n', '<leader>nd', '<cmd>Dotnet debug<cr>', { desc = '[D]ebug project' })
      vim.keymap.set('n', '<leader>na', '<cmd>Dotnet debug attach<cr>', { desc = '[A]ttach to running .NET process' })
      vim.keymap.set('n', '<leader>nr', '<cmd>Dotnet run<cr>', { desc = '[R]un project' })
      vim.keymap.set('n', '<leader>nb', '<cmd>Dotnet build<cr>', { desc = '[B]uild project' })
      vim.keymap.set('n', '<leader>nc', '<cmd>Dotnet clean<cr>', { desc = '[C]lean project' })
      vim.keymap.set('n', '<leader>ns', '<cmd>Dotnet secrets<cr>', { desc = 'Manage [S]ecrets' })
      vim.keymap.set('n', '<leader>nw', '<cmd>Dotnet watch<cr>', { desc = '[W]atch project' })
      vim.keymap.set('n', '<leader>nn', '<cmd>Dotnet new<cr>', { desc = '[N]ew item' })
      vim.keymap.set('n', '<leader>no', '<cmd>Dotnet outdated<cr>', { desc = '[O]utdated packages' })

      vim.keymap.set('n', '<leader>te', function()
        require('easy-dotnet.test-runner').open()
      end, { desc = 'Test [E]xplorer (.NET)' })

      require('features.dotnet-test').setup()
    end,
  },
}
