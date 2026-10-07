-- noice: LSP hover and signature help rendering

return {
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = { 'MunifTanjim/nui.nvim' },
    opts = {
      cmdline = { enabled = false },
      messages = { enabled = false },
      popupmenu = { enabled = false },
      notify = { enabled = false },
      lsp = {
        hover = { enabled = true, silent = true },
        -- signature help uses the hover view, whose default size covers the code being typed
        signature = {
          enabled = true,
          opts = {
            size = { max_width = 80, max_height = 5 },
            position = { row = 2, col = 0 },
          },
        },
        progress = { enabled = false },
        message = { enabled = false },
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
        },
      },
      presets = {
        lsp_doc_border = true,
        bottom_search = true,
        long_message_to_split = true,
      },
    },
  },
}
