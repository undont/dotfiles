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
    }

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
