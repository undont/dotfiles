-- Markdown editing: Obsidian-like rendering and interactive list/link management

return {
  -- Interactive editing: list continuation, auto-renumbering, link following, table formatting
  {
    'jakewvincent/mkdnflow.nvim',
    ft = { 'markdown' },
    config = function()
      require('mkdnflow').setup {
        modules = {
          bib = false,
          yaml = false,
          cmp = false,
        },
        lists = {
          enable = true,
        },
        to_do = {
          enable = true,
          statuses = { ' ', 'x' },
        },
        tables = {
          enable = true,
          auto_extend = true,
          format_on_move = true,
        },
        mappings = {
          -- Disable mappings that conflict with copilot/blink.cmp
          MkdnTableNextCell = false, -- frees <Tab> for copilot/snippets
          MkdnTablePrevCell = false, -- frees <S-Tab> for snippets
          MkdnToggleToDo = { 'n', '<leader>mt' }, -- moved from <C-Space> (blink conflict)
          -- List / navigation (defaults are fine)
          MkdnEnter = { { 'n', 'v' }, '<CR>' },
          MkdnNewListItem = { 'i', '<CR>' }, -- auto-continues lists in insert mode
          MkdnGoBack = { 'n', '<BS>' },
          MkdnGoForward = { 'n', '<Del>' },
          MkdnNextHeading = { 'n', ']]' },
          MkdnPrevHeading = { 'n', '[[' },
          MkdnFoldSection = { 'n', '<leader>mf' },
          MkdnUnfoldSection = { 'n', '<leader>mu' },
          MkdnUpdateNumbering = { 'n', '<leader>mn' }, -- renumber ordered list
        },
      }

      -- Renumber ordered lists automatically after deleting lines
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'markdown',
        callback = function(ev)
          vim.api.nvim_create_autocmd('TextChanged', {
            buffer = ev.buf,
            callback = function()
              -- Only renumber if cursor is on/near a numbered list
              local line = vim.api.nvim_get_current_line()
              if line:match '^%s*%d+[%.%)%)]%s' then
                pcall(vim.cmd, 'MkdnUpdateNumbering')
              end
            end,
          })
        end,
      })
    end,
  },
}
