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

  --- Suppress Roslyn style/suggestion diagnostics whose span lands inside
  --- XML doc comments. Roslyn can report simplification-style IDE hints on
  --- `<see cref="...">` targets, which is technically analyzable but noisy.
  --- Keep warnings/errors so malformed XML docs and compiler diagnostics still
  --- surface normally.
  ---@param bufnr integer
  ---@param d vim.Diagnostic
  ---@return boolean
  local function is_doc_comment_style_hint(bufnr, d)
    if d.severity ~= vim.diagnostic.severity.HINT and d.severity ~= vim.diagnostic.severity.INFO then
      return false
    end
    if type(d.lnum) ~= 'number' then
      return false
    end

    local line = vim.api.nvim_buf_get_lines(bufnr, d.lnum, d.lnum + 1, false)[1]
    if not line or not line:match '^%s*///' then
      return false
    end

    local code = d.code and tostring(d.code) or ''
    return code:match '^IDE' or (d.source == 'Style') or ((d.message or ''):match 'simplif')
  end

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
      if not false_positives[d.code] and not is_doc_comment_style_hint(bufnr, d) then
        -- Use lnum:col:code when code is present (ignores message variations
        -- between push/pull channels or multi-project contexts).
        -- Fall back to message when code is absent.
        local key = d.code and (d.lnum .. ':' .. d.col .. ':' .. d.code) or (d.lnum .. ':' .. d.col .. ':' .. d.message)
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
  local builtin_types = {
    bool = true,
    byte = true,
    char = true,
    decimal = true,
    double = true,
    dynamic = true,
    float = true,
    int = true,
    long = true,
    nint = true,
    nuint = true,
    object = true,
    sbyte = true,
    short = true,
    string = true,
    uint = true,
    ulong = true,
    ushort = true,
    void = true,
  }

  local function in_attribute_context(line, start_col)
    local before = line:sub(1, start_col)
    local last_open = before:match '.*()%['
    if not last_open then
      return false
    end
    local last_close = before:match '.*()%]'
    return not last_close or last_open > last_close
  end

  -- Disable Neovim 0.12's viewport-only semantic token range requests.
  -- Roslyn 5.8.0 declares semanticTokensProvider.range statically in
  -- the initialize response, so STHighlighter:on_attach caches
  -- supports_range = true before our config runs. Range responses arrive
  -- with stale/partial classifications during Roslyn warmup and replace
  -- the full-document tokens, causing visible flicker on .cs open.
  --
  -- Neovim's Client:on_attach schedules STHighlighter:on_attach after
  -- LspAttach callbacks finish (client.lua:1159) precisely so we can
  -- mutate server_capabilities here as an opt-out hook.
  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not (client and client.name == 'roslyn') then
        return
      end
      local stp = client.server_capabilities and client.server_capabilities.semanticTokensProvider
      if stp then
        stp.range = false
      end
    end,
  })

  vim.api.nvim_create_autocmd('LspTokenUpdate', {
    callback = function(ev)
      local token = ev.data.token
      local line = vim.api.nvim_buf_get_lines(ev.buf, token.line, token.line + 1, false)[1]
      if not line then
        return
      end
      if vim.bo[ev.buf].filetype ~= 'cs' then
        return
      end

      if token.type == 'variable' then
        if not line:match '^%s*using%s' or line:match '[%(=]' then
          return
        end
        vim.lsp.semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, '@type')
        return
      end

      if token.type == 'class' then
        if in_attribute_context(line, token.start_col) then
          vim.lsp.semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, '@attribute')
        end
        return
      end

      if token.type ~= 'keyword' then
        return
      end

      local text = line:sub(token.start_col + 1, token.end_col)
      if builtin_types[text] then
        vim.lsp.semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, '@type.builtin')
      end
    end,
  })

  -- Refresh semantic tokens whenever Roslyn finishes a background task.
  -- workspace/projectInitializationComplete (RoslynInitialized) fires *before*
  -- per-file semantic analysis is done, so a single refresh there lands stale
  -- (requiring a manual <leader>lt ~1s later to settle). Roslyn emits LSP
  -- progress 'end' notifications when its background analysis chunks finish;
  -- a debounced refresh on those catches the moment fresh tokens are ready.
  -- Debounce keeps cost bounded during warmup (many 'end' events fire close
  -- together) while still picking up post-warmup analyses (branch switches,
  -- dep restores, etc.).
  local refresh_pending = false
  vim.api.nvim_create_autocmd('LspProgress', {
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not (client and client.name == 'roslyn') then
        return
      end
      local val = ev.data.params and ev.data.params.value
      if not (val and val.kind == 'end') then
        return
      end
      if refresh_pending then
        return
      end
      refresh_pending = true
      vim.defer_fn(function()
        refresh_pending = false
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'cs' then
            vim.lsp.semantic_tokens.force_refresh(buf)
          end
        end
      end, 300)
    end,
  })
end

-- Roslyn during diff/review contexts (Diffview, Octo).
-- Strategy: do NOTHING to the LSP client. Neovim's `lsp_enable_callback`
-- skips buffers with `buftype` other than '' or 'help', and diff buffers
-- have buftype=nofile (octo, diffview file_history) or buftype=nowrite
-- (diffview file diffs) -- so roslyn never auto-attaches to them anyway.
-- We previously called `vim.lsp.enable('roslyn', false)` to "block new
-- attaches", but that ALSO stops every running roslyn client (per the
-- vim.lsp.enable contract: "stops related LSP clients and servers"),
-- which paid a multi-second cold-restart on every review entry/exit cycle.
--
-- vim.g.roslyn_suppressed remains as a flag so the notify wrap in ui.lua
-- and fidget's progress.ignore can still drop residual chatter while in
-- review (e.g. messages emitted by an unrelated client startup).
vim.g.roslyn_suppressed = false

--- Source roslyn.nvim's plugin file after our config is applied. We block
--- it in init (vim.g.loaded_roslyn_plugin) to prevent vim.lsp.enable
--- firing before lock_target + ignore_target are set.
local function source_deferred_plugin()
  vim.g.loaded_roslyn_plugin = nil
  local plugin_file = vim.api.nvim_get_runtime_file('plugin/roslyn.lua', false)[1]
  if plugin_file then
    dofile(plugin_file)
  end
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'octo', 'DiffviewFiles', 'DiffviewFileHistory' },
  callback = function()
    vim.g.roslyn_suppressed = true
  end,
})

-- Clear the flag once the review context is fully torn down. Diffview
-- buffers can linger after close, so check the active view (not buffer
-- filetypes) plus any remaining octo buffers.
local function maybe_clear_roslyn_flag()
  if not vim.g.roslyn_suppressed then
    return
  end
  local dv_ok, dv_lib = pcall(require, 'diffview.lib')
  if dv_ok and dv_lib.get_current_view() then
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'octo' then
      return
    end
  end
  vim.g.roslyn_suppressed = false
end

vim.api.nvim_create_autocmd('BufEnter', {
  pattern = '*.cs',
  callback = function()
    if vim.g.roslyn_suppressed then
      vim.defer_fn(maybe_clear_roslyn_flag, 500)
    end
  end,
})

return {
  -- Roslyn LSP via roslyn.nvim (diagnostics, go-to-def, hover, completions)
  -- Loads on `User RealDotnetFile` (fired by core/autocmds.lua only for
  -- buftype='' cs/razor buffers). Diff buffers in diffview/octo have
  -- buftype=nowrite/nofile, so they don't trigger this and roslyn.nvim's
  -- ~1.8s config cost stays off the cold-`<leader>do` critical path.
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
      -- Roslyn 5.8.0-1.26262.10 (Mason 2026-05-14) bundles Razor natively and
      -- no longer accepts roslyn.nvim's --razorSourceGenerator /
      -- --razorDesignTimePath flags, which causes the server to exit on
      -- startup. See seblyng/roslyn.nvim#360.
      extensions = {
        razor = { enabled = false },
      },
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
            dotnet_enable_references_code_lens = false,
            dotnet_enable_tests_code_lens = false,
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
      -- if the cached solution is a build variant (e.g. .ci.slnx).
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
            -- run_all_tests_from_buffer overridden below (upstream runs whole project)
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

      -- Trap window-navigation keys in test explorer and peek stacktrace floats.
      -- Without this, <C-h/j/k/l> escapes to the main buffer and the float
      -- becomes unreachable.
      local nav_block_group = vim.api.nvim_create_augroup('dotnet-float-nav-block', { clear = true })
      local nav_keys = { '<C-h>', '<C-j>', '<C-k>', '<C-l>' }

      local function block_nav(buf)
        for _, key in ipairs(nav_keys) do
          vim.keymap.set('n', key, '<Nop>', { buffer = buf })
        end
      end

      -- Test explorer (easy-dotnet filetype)
      vim.api.nvim_create_autocmd('FileType', {
        group = nav_block_group,
        pattern = 'easy-dotnet',
        callback = function(args)
          block_nav(args.buf)
        end,
      })

      -- Peek stacktrace floats (winfixbuf scratch buffers created by easy-dotnet).
      -- Deferred via vim.schedule so winfixbuf is set by window.lua before we check.
      vim.api.nvim_create_autocmd('WinEnter', {
        group = nav_block_group,
        callback = function()
          vim.schedule(function()
            local win = vim.api.nvim_get_current_win()
            if not vim.api.nvim_win_is_valid(win) then
              return
            end
            local cfg = vim.api.nvim_win_get_config(win)
            if cfg.relative == '' then
              return
            end
            if not vim.wo[win].winfixbuf then
              return
            end
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == 'easy-dotnet' then
              return
            end
            block_nav(buf)
            vim.keymap.set('n', '<Esc>', function()
              if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
              end
            end, { buffer = buf, nowait = true })
          end)
        end,
      })

      -- Run only tests in the current file (not the whole project).
      -- Upstream run_all_tests_from_buffer runs by projectId which is too broad.
      -- This finds TestClass nodes matching the current file and runs each one.
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'cs',
        callback = function(args)
          vim.keymap.set('n', '<leader>tf', function()
            local state = require 'easy-dotnet.test-runner.state'
            local client = require('easy-dotnet.rpc.rpc').global_rpc_client
            local filepath = vim.fs.normalize(vim.api.nvim_buf_get_name(args.buf))
            -- Collect test nodes belonging to this file. Run at class level
            -- to avoid running individual methods separately.
            local run_ids = {}
            local seen_ids = {}
            state.traverse_all(function(node)
              if not node.filePath or vim.fs.normalize(node.filePath) ~= filepath then
                return
              end
              -- Find the highest runnable ancestor for this file (class > method)
              local target = node
              if node.type and node.type.type and node.parentId then
                local parent = state.nodes[node.parentId]
                if parent and parent.filePath and vim.fs.normalize(parent.filePath) == filepath then
                  target = parent
                end
              end
              if not seen_ids[target.id] then
                seen_ids[target.id] = true
                table.insert(run_ids, target.id)
              end
            end)
            if #run_ids == 0 then
              vim.notify('No tests found in this file', vim.log.levels.INFO)
              return
            end
            for _, id in ipairs(run_ids) do
              client.testrunner:run(id, function() end, 'buffer')
            end
          end, { buffer = args.buf, desc = 'Run [F]ile tests (.NET)' })
        end,
      })
    end,
  },
}
