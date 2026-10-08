-- mkdnflow: list continuation, table editing, link follow. the FileType
-- autocmd below sets conceallevel=2 and wrap for markdown buffers

return {
  {
    'jakewvincent/mkdnflow.nvim',
    ft = { 'markdown' },
    config = function()
      require('mkdnflow').setup {
        modules = {
          bib = false,
          yaml = false,
          completion = false,
        },
        to_do = {
          statuses = {
            not_started = { marker = ' ' },
            complete = { marker = 'x' },
          },
          status_order = { 'not_started', 'complete' },
        },
        tables = {
          auto_extend_rows = true,
          auto_extend_cols = true,
          format_on_move = true,
        },
        mappings = {
          -- these defaults conflict with the C-i jumplist and blink.cmp's Tab
          MkdnNextLink = false,
          MkdnPrevLink = false,
          MkdnTableNextCell = false,
          MkdnTablePrevCell = false,
          MkdnToggleToDo = { 'n', '<leader>mt' }, -- the default <C-Space> is blink's
          MkdnEnter = false, -- mangles numbered lists on <CR>
          MkdnNewListItem = false, -- mangles links on <CR> in insert mode
          MkdnFollowLink = { 'n', '<C-]>' },
          MkdnGoBack = { 'n', '<BS>' },
          MkdnGoForward = { 'n', '<Del>' },
          MkdnNextHeading = { 'n', ']]' },
          MkdnPrevHeading = { 'n', '[[' },
          -- the defaults ][ and [] shadow vim's section-end motions
          MkdnNextHeadingSame = false,
          MkdnPrevHeadingSame = false,
          -- zc/zr fold by section in markdown buffers
          MkdnFoldSection = { 'n', 'zc' },
          MkdnUnfoldSection = { 'n', 'zr' },
          MkdnUpdateNumbering = { 'n', '<leader>mn' },
          -- `-` would shadow oil's parent-dir keymap
          MkdnIncreaseHeading = false,
          MkdnDecreaseHeading = false,
          -- the defaults below sit in other groups (<leader>p, i, d, a)
          MkdnCreateLinkFromClipboard = { { 'n', 'v' }, '<leader>ml' },
          MkdnTableNewRowBelow = { 'n', '<leader>mir' },
          MkdnTableNewRowAbove = { 'n', '<leader>miR' },
          MkdnTableNewColAfter = { 'n', '<leader>mic' },
          MkdnTableNewColBefore = { 'n', '<leader>miC' },
          MkdnTableDeleteRow = { 'n', '<leader>mdr' },
          MkdnTableDeleteCol = { 'n', '<leader>mdc' },
          MkdnTableAlignCenter = { 'n', '<leader>mAc' },
          MkdnTableAlignLeft = { 'n', '<leader>mAl' },
          MkdnTableAlignRight = { 'n', '<leader>mAr' },
          MkdnTableAlignDefault = { 'n', '<leader>mAx' },
        },
      }

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

          local map = vim.keymap.set
          local bopts = { buffer = ev.buf, silent = true }
          map('n', 'j', 'gj', bopts)
          map('n', 'k', 'gk', bopts)

          vim.api.nvim_create_autocmd('TextChanged', {
            buffer = ev.buf,
            callback = function()
              local line = vim.api.nvim_get_current_line()
              if line:match '^%s*%d+[%.%)%)]%s' then
                pcall(function()
                  vim.cmd 'undojoin'
                end)
                pcall(function()
                  vim.cmd 'MkdnUpdateNumbering'
                end)
              end
            end,
          })
        end,
      })
    end,
  },
}
