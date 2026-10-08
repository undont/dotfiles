-- markdown-preview: browser preview

return {
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
