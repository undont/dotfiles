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
          -- Disable mappings that conflict with C-i jumplist / blink.cmp Tab
          MkdnNextLink = false,
          MkdnPrevLink = false,
          MkdnTableNextCell = false,
          MkdnTablePrevCell = false,
          MkdnToggleToDo = { 'n', '<leader>mt' }, -- moved from <C-Space> (blink conflict)
          -- List / navigation (defaults are fine)
          MkdnEnter = false, -- disabled: was mangling numbered lists on <CR>
          MkdnNewListItem = false, -- disabled: was mangling links on <CR> in insert mode
          MkdnGoBack = { 'n', '<BS>' },
          MkdnGoForward = { 'n', '<Del>' },
          MkdnNextHeading = { 'n', ']]' },
          MkdnPrevHeading = { 'n', '[[' },
          -- Defaults ][ and [] clutter which-key behind [/] and shadow
          -- vim's native section-end motions. Use ]]/[[ instead.
          MkdnNextHeadingSame = false,
          MkdnPrevHeadingSame = false,
          -- Section fold/unfold: override global zc/zr in markdown buffers only
          -- (markdown's natural fold unit is the section, not nested vim folds)
          MkdnFoldSection = { 'n', 'zc' },
          MkdnUnfoldSection = { 'n', 'zr' },
          MkdnUpdateNumbering = { 'n', '<leader>mn' }, -- renumber ordered list
          -- Disable +/- heading bumpers: `-` shadows Oil's global parent-dir
          -- keymap in markdown buffers
          MkdnIncreaseHeading = false,
          MkdnDecreaseHeading = false,
          -- Create link from clipboard: moved from <leader>p (conflicts with PR Review)
          MkdnCreateLinkFromClipboard = { { 'n', 'v' }, '<leader>ml' },
          -- Table insert: moved from <leader>i* (orphaned, no group)
          MkdnTableNewRowBelow = { 'n', '<leader>mir' },
          MkdnTableNewRowAbove = { 'n', '<leader>miR' },
          MkdnTableNewColAfter = { 'n', '<leader>mic' },
          MkdnTableNewColBefore = { 'n', '<leader>miC' },
          -- Table delete: moved from <leader>d* (conflicts with Diff)
          MkdnTableDeleteRow = { 'n', '<leader>mdr' },
          MkdnTableDeleteCol = { 'n', '<leader>mdc' },
          -- Table alignment: moved from <leader>a* (conflicts with codecompanion)
          MkdnTableAlignCenter = { 'n', '<leader>mAc' },
          MkdnTableAlignLeft = { 'n', '<leader>mAl' },
          MkdnTableAlignRight = { 'n', '<leader>mAr' },
          MkdnTableAlignDefault = { 'n', '<leader>mAx' },
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

          -- Renumber ordered lists automatically after deleting lines
          vim.api.nvim_create_autocmd('TextChanged', {
            buffer = ev.buf,
            callback = function()
              -- Only renumber if cursor is on/near a numbered list
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

  -- Browser preview with live sync scrolling, KaTeX, Mermaid, PlantUML
  {
    'iamcco/markdown-preview.nvim',
    cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
    build = 'cd app && npx --yes yarn install',
    config = function()
      if vim.bo.filetype == 'markdown' then
        vim.cmd [[
          command! -buffer MarkdownPreview call mkdp#util#open_preview_page()
          command! -buffer MarkdownPreviewStop call mkdp#util#stop_preview()
          command! -buffer MarkdownPreviewToggle call mkdp#util#toggle_preview()
        ]]
      end
    end,
    keys = {
      { '<leader>mp', '<cmd>MarkdownPreviewToggle<CR>', desc = 'Preview in browser' },
    },
  },
}
