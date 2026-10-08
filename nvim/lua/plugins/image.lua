-- image.nvim: inline image rendering via kitty graphics (ghostty + tmux)
-- uses the magick_cli processor so it needs only imagemagick, no luarock

return {
  '3rd/image.nvim',
  build = false, -- the cli processor needs no rock
  ft = { 'markdown' },
  opts = {
    backend = 'kitty',
    processor = 'magick_cli',
    -- hide an image while a float (lazygit, pickers) covers its window
    window_overlap_clear_enabled = true,
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
  config = function(_, opts)
    local image = require 'image'
    image.setup(opts)

    -- tmux passes kitty graphics through without tracking them, so an image
    -- stays drawn over other panes, windows and popups. a popup opening sends
    -- the pane a focus-out. editor_only_render_when_focused still renders on
    -- text changes and resizes while unfocused; disable() stops every path.
    -- needs tmux focus-events on
    local group = vim.api.nvim_create_augroup('image-focus', { clear = true })
    vim.api.nvim_create_autocmd('FocusLost', { group = group, callback = image.disable })
    vim.api.nvim_create_autocmd('FocusGained', { group = group, callback = image.enable })
  end,
}
