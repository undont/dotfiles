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
          statuses = {
            { name = 'not_started', marker = ' ' },
            { name = 'complete', marker = 'x' },
          },
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

      -- Markdown display: wrap text, conceal syntax, softwrap navigation
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'markdown',
        callback = function(ev)
          local o = vim.bo[ev.buf]
          o.textwidth = 0

          local wo = vim.wo[vim.api.nvim_get_current_win()]
          wo.wrap = true
          wo.linebreak = true
          wo.conceallevel = 2
          wo.list = false -- listchars conflict with linebreak

          -- j/k move by visual line in markdown buffers
          local map = vim.keymap.set
          local bopts = { buffer = ev.buf, silent = true }
          map('n', 'j', 'gj', bopts)
          map('n', 'k', 'gk', bopts)

          -- Renumber ordered lists on cursor idle (debounced via updatetime)
          vim.api.nvim_create_autocmd('CursorHold', {
            buffer = ev.buf,
            callback = function()
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
