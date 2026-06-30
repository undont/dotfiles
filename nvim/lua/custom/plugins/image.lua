-- image.nvim: inline image rendering via kitty graphics (ghostty + tmux)
-- uses the magick_cli processor so it needs only imagemagick, no luarock

return {
  '3rd/image.nvim',
  build = false, -- skip the rock build; cli processor doesn't need it
  ft = { 'markdown' },
  opts = {
    backend = 'kitty',
    processor = 'magick_cli',
    -- hide images when the nvim pane's tmux window isn't active. tmux doesn't
    -- understand kitty graphics, so without this an image bleeds across windows
    -- and sessions until something redraws over it. needs tmux focus-events on
    -- (already set) and visual-activity off (tmux default)
    tmux_show_only_in_active_window = true,
    integrations = {
      markdown = {
        enabled = true,
        only_render_image_at_cursor = false,
        -- skip remote images: shields.io badges and the like render poorly inline
        -- and pull in remote svgs. local screenshots/diagrams still render
        download_remote_images = false,
        filetypes = { 'markdown' },
      },
    },
    max_height_window_percentage = 50,
  },
}
