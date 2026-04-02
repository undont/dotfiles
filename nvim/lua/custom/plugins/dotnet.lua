-- .NET development: roslyn.nvim for LSP, easy-dotnet.nvim for build/run/debug
-- https://github.com/seblyng/roslyn.nvim
-- https://github.com/GustavEikaas/easy-dotnet.nvim

--- @param path string
--- @return boolean
local function is_build_variant(path)
  return vim.fs.basename(path):match '%.[%l][%w]*%.slnx?$' ~= nil
end

--- Find and set the target solution before roslyn.nvim loads, so that
--- lock_target can skip the multi-target picker entirely.
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

--- Wrap vim.diagnostic.set to filter Roslyn false positives and deduplicate
--- diagnostics reported from multiple .csproj contexts (cross-namespace).
local function patch_diagnostic_set()
  local orig = vim.diagnostic.set
  local false_positives = { IDE0005 = true, IDE0079 = true, CA1825 = true }
  local buf_owners = {} ---@type table<integer, table<string, integer>>

  vim.diagnostic.set = function(namespace, bufnr, diagnostics, diag_opts)
    if not (bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'cs') then
      return orig(namespace, bufnr, diagnostics, diag_opts)
    end

    -- Suppress diagnostics on decompiled metadata source (read-only library code)
    if vim.api.nvim_buf_get_name(bufnr):match 'MetadataAsSource' then
      return orig(namespace, bufnr, {}, diag_opts)
    end

    -- Clear this namespace's previous ownership claims
    if not buf_owners[bufnr] then
      buf_owners[bufnr] = {}
    end
    for key, ns in pairs(buf_owners[bufnr]) do
      if ns == namespace then
        buf_owners[bufnr][key] = nil
      end
    end

    -- Filter false positives and deduplicate across namespaces
    local deduped = {}
    for _, d in ipairs(diagnostics) do
      if not false_positives[d.code] then
        local key = d.lnum .. ':' .. d.col .. ':' .. (d.code or '') .. ':' .. d.message
        if not buf_owners[bufnr][key] then
          buf_owners[bufnr][key] = namespace
          table.insert(deduped, d)
        end
      end
    end

    return orig(namespace, bufnr, deduped, diag_opts)
  end

  vim.api.nvim_create_autocmd('BufWipeout', {
    callback = function(ev)
      buf_owners[ev.buf] = nil
    end,
  })
end

--- Fix Roslyn misclassifying unresolved identifiers on using directives as
--- "variable" instead of "namespace". Override to @type for proper styling.
local function setup_semantic_token_fix()
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
end

-- Roslyn suppression for Octo PR review. Roslyn's solution analysis
-- freezes navigation on large PRs with hundreds of .cs diff buffers.
local roslyn_suppressed = false

--- Source roslyn.nvim's plugin file after our config is applied. We block
--- it in init (vim.g.loaded_roslyn_plugin) to prevent vim.lsp.enable
--- firing before lock_target + ignore_target are set.
--- Skips enabling entirely if roslyn_suppressed is set (Octo PR review).
local function source_deferred_plugin()
  if roslyn_suppressed then
    vim.notify('Roslyn skipped (PR review active) — opens automatically after review', vim.log.levels.INFO)
    return
  end

  vim.g.loaded_roslyn_plugin = nil
  local plugin_file = vim.api.nvim_get_runtime_file('plugin/roslyn.lua', false)[1]
  if plugin_file then
    dofile(plugin_file)
  end
end

-- Suppress roslyn when Octo opens (before any .cs diff buffer loads).
-- Not once = true — user may leave review, edit a file (re-enables roslyn),
-- then resume review (needs to suppress again).
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'octo',
  callback = function()
    if roslyn_suppressed then
      return
    end
    roslyn_suppressed = true
    vim.lsp.enable('roslyn', false)
    for _, client in ipairs(vim.lsp.get_clients { name = 'roslyn' }) do
      client:stop(true)
    end
  end,
})

-- Re-enable roslyn when opening a real .cs project file after review.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'cs',
  callback = function(args)
    if not roslyn_suppressed then
      return
    end
    local name = vim.api.nvim_buf_get_name(args.buf)
    if name ~= '' and vim.bo[args.buf].buftype == '' and not pcall(vim.api.nvim_buf_get_var, args.buf, 'octo_diff_props') then
      roslyn_suppressed = false
      source_deferred_plugin()
    end
  end,
})

return {
  -- Roslyn LSP via roslyn.nvim (diagnostics, go-to-def, hover, completions)
  {
    'seblyng/roslyn.nvim',
    ft = { 'cs' },
    dependencies = { 'mason-org/mason.nvim' },
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      ignore_target = function(target)
        return is_build_variant(target)
      end,
      broad_search = true,
      lock_target = true,
    },
    init = function()
      vim.g.loaded_roslyn_plugin = true
    end,
    config = function(_, opts)
      resolve_solution_target()
      patch_diagnostic_set()
      setup_semantic_token_fix()

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

      require('roslyn').setup(opts)
      source_deferred_plugin()
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
      -- Sync roslyn.nvim's solution target into easy-dotnet's cache so the
      -- test runner and build commands use the same solution. Force-overwrite
      -- if the cached solution is a build variant (e.g. Dana.ci.slnx).
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
          enable_buffer_test_execution = true,
          auto_start_testrunner = true,
          viewmode = 'float',
          mappings = {
            -- Buffer keymaps (active in .cs files with tests)
            run_test_from_buffer = { lhs = '<leader>tr', desc = '[R]un test' },
            debug_test_from_buffer = { lhs = '<leader>td', desc = '[D]ebug test' },
            peek_stack_trace_from_buffer = { lhs = '<leader>tp', desc = '[P]eek stacktrace' },
            -- Explorer window keymaps (single keys — non-editable buffer)
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
          vim.cmd 'botright vsplit'
          vim.cmd 'vertical resize 40'
          vim.cmd('term ' .. command)
        end,
      }

      vim.keymap.set('n', '<leader>nd', '<cmd>Dotnet debug<cr>', { desc = '[D]ebug project' })
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
    end,
  },
}
