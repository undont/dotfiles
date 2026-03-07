-- .NET development with easy-dotnet.nvim
-- https://github.com/GustavEikaas/easy-dotnet.nvim

return {
  'GustavEikaas/easy-dotnet.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  },
  ft = { 'cs', 'fsharp', 'vb' },
  config = function()
    -- Filter known Roslyn false positives from C# diagnostics.
    -- IDE0079: false-positives on pragmas for third-party analysers (SonarAnalyzer, etc.)
    -- CA1825: false-positives on C# 12 collection expressions (misidentified as zero-length arrays)
    -- Wraps vim.diagnostic.set to intercept both push and pull diagnostics.
    local orig_diag_set = vim.diagnostic.set
    local roslyn_false_positives = { IDE0079 = true, CA1825 = true }
    vim.diagnostic.set = function(namespace, bufnr, diagnostics, opts)
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == 'cs' then
        -- Suppress diagnostics on decompiled metadata source (read-only library code)
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if bufname:match 'MetadataAsSource' then
          return orig_diag_set(namespace, bufnr, {}, opts)
        end

        -- Deduplicate diagnostics reported from multiple .csproj contexts
        local seen = {}
        local deduped = {}
        for _, d in ipairs(diagnostics) do
          if not roslyn_false_positives[d.code] then
            local key = d.lnum .. ':' .. d.col .. ':' .. (d.end_lnum or '') .. ':' .. (d.end_col or '') .. ':' .. d.message
            if not seen[key] then
              seen[key] = true
              table.insert(deduped, d)
            end
          end
        end
        diagnostics = deduped
      end
      return orig_diag_set(namespace, bufnr, diagnostics, opts)
    end

    -- Filter build-variant solutions (.ci.slnx, .build.sln, .test.sln, etc.)
    -- from Roslyn's solution discovery. Without this, the "Pick solution file
    -- to start Roslyn from" picker appears every time a cs file is opened in a
    -- project with both Dana.slnx and Dana.ci.slnx.
    --
    -- Patches root_finder.find_solutions_from_file which walks up from .csproj
    -- files collecting .sln/.slnx matches. The picker in roslyn/lsp.lua uses
    -- the unfiltered results, so we filter at the source.

    --- @param path string
    --- @return boolean
    local function is_build_variant(path)
      return vim.fs.basename(path):match '%.[%l][%w]*%.slnx?$' ~= nil
    end

    local root_finder = require 'easy-dotnet.roslyn.root_finder'
    local orig_find_solutions = root_finder.find_solutions_from_file
    root_finder.find_solutions_from_file = function(...)
      local results = orig_find_solutions(...)
      return vim.tbl_filter(function(path)
        return not is_build_variant(path)
      end, results)
    end

    -- Also clear any previously cached build-variant solution
    local current_solution = require 'easy-dotnet.current_solution'
    local cached = current_solution.try_get_selected_solution()
    if cached and is_build_variant(cached) then
      current_solution.clear_selected_solution()
    end

    -- Add missing imports across .cs files that have missing-type errors
    local add_missing_imports_solution = require 'custom.plugins.dotnet.add_missing_imports'

    require('easy-dotnet').setup {
      -- Use built-in Roslyn LSP (replaces OmniSharp)
      -- Requires Neovim 0.11+
      lsp = {
        enabled = true,
        roslynator_enabled = true,
        auto_refresh_codelens = false,
      },
      -- Keep test_runner for buffer signs (test indicators in gutter)
      test_runner = {
        enable_buffer_test_execution = true,
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

    -- Project commands only (tests handled by neotest)
    vim.keymap.set('n', '<leader>nr', '<cmd>Dotnet run<cr>', { desc = '[R]un project' })
    vim.keymap.set('n', '<leader>nb', '<cmd>Dotnet build<cr>', { desc = '[B]uild project' })
    vim.keymap.set('n', '<leader>nc', '<cmd>Dotnet clean<cr>', { desc = '[C]lean project' })
    vim.keymap.set('n', '<leader>ns', '<cmd>Dotnet secrets<cr>', { desc = 'Manage [S]ecrets' })
    vim.keymap.set('n', '<leader>nw', '<cmd>Dotnet watch<cr>', { desc = '[W]atch project' })
    vim.keymap.set('n', '<leader>nn', '<cmd>Dotnet new<cr>', { desc = '[N]ew item' })
    vim.keymap.set('n', '<leader>no', '<cmd>Dotnet outdated<cr>', { desc = '[O]utdated packages' })
    vim.keymap.set('n', '<leader>ni', add_missing_imports_solution, { desc = 'Add missing [I]mports (solution) (beta)' })
  end,
}
