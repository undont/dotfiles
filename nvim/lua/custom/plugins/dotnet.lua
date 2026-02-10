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
    require('easy-dotnet').setup {
      -- Use built-in Roslyn LSP (replaces OmniSharp)
      -- Requires Neovim 0.11+
      lsp = {
        enabled = true,
        roslynator_enabled = true,
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

    -- Auto-select solution file: skip build variant solutions (.ci.sln, .build.slnx, etc.)
    -- Only keeps files where the segment before .sln/.slnx is PascalCase (starts uppercase)
    -- Runs synchronously before Roslyn's root_dir callback fires
    local current_solution = require 'easy-dotnet.current_solution'
    if not current_solution.try_get_selected_solution() then
      local solutions = vim.fn.glob('**/*.slnx', false, true)
      vim.list_extend(solutions, vim.fn.glob('**/*.sln', false, true))
      local filtered = vim.tbl_filter(function(path)
        -- Filter out compound extensions where the segment before .sln/.slnx starts
        -- with a lowercase letter (e.g., .ci.sln, .build.slnx, .test.sln)
        -- Keeps PascalCase names like Dana.Platform.sln
        return not vim.fs.basename(path):match '%.[%l][%w]*%.slnx?$'
      end, solutions)
      if #filtered == 1 then
        local abs = vim.fs.normalize(vim.fn.fnamemodify(filtered[1], ':p'))
        current_solution.set_solution(abs)
      end
    end

    -- Project commands only (tests handled by neotest)
    vim.keymap.set('n', '<leader>nr', '<cmd>Dotnet run<cr>', { desc = '.NET: Run project' })
    vim.keymap.set('n', '<leader>nb', '<cmd>Dotnet build<cr>', { desc = '.NET: Build project' })
    vim.keymap.set('n', '<leader>nc', '<cmd>Dotnet clean<cr>', { desc = '.NET: Clean project' })
    vim.keymap.set('n', '<leader>ns', '<cmd>Dotnet secrets<cr>', { desc = '.NET: Manage secrets' })
    vim.keymap.set('n', '<leader>nw', '<cmd>Dotnet watch<cr>', { desc = '.NET: Watch project' })
    vim.keymap.set('n', '<leader>nn', '<cmd>Dotnet new<cr>', { desc = '.NET: New item' })
    vim.keymap.set('n', '<leader>no', '<cmd>Dotnet outdated<cr>', { desc = '.NET: Outdated packages' })
  end,
}
