-- image.nvim: inline image rendering via kitty graphics (ghostty + tmux)
-- uses the magick_cli processor so it needs only imagemagick, no luarock

return {
  '3rd/image.nvim',
  build = false, -- the cli processor needs no rock
  ft = { 'markdown' },
  opts = {
    backend = 'kitty',
    processor = 'magick_cli',
    -- tmux passes kitty graphics through without tracking them, so an image
    -- stays drawn over other windows and sessions. needs tmux focus-events on
    -- and visual-activity off
    tmux_show_only_in_active_window = true,
    integrations = {
      markdown = {
        enabled = true,
        only_render_image_at_cursor = false,
        -- remote images are mostly svg badges, which render poorly inline
        download_remote_images = false,
        filetypes = { 'markdown' },
      },
    },
    max_height_window_percentage = 50,
  },
}
