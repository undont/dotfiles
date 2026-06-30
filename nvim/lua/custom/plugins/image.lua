-- image.nvim: inline image rendering via kitty graphics (ghostty + tmux)
-- uses the magick_cli processor so it needs only imagemagick, no luarock

return {
  '3rd/image.nvim',
  build = false, -- skip the rock build; cli processor doesn't need it
  ft = { 'markdown' },
  opts = {
    backend = 'kitty',
    processor = 'magick_cli',
    integrations = {
      markdown = {
        enabled = true,
        only_render_image_at_cursor = false,
        filetypes = { 'markdown' },
      },
    },
    max_height_window_percentage = 50,
  },
}
