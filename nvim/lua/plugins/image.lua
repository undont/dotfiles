-- image.nvim: inline image rendering via kitty graphics (ghostty + tmux)
-- uses the magick_cli processor so it needs only imagemagick, no luarock

local vault_hits = {}

-- obsidian resolves an embed by name anywhere in the vault, not beside the note
local function resolve_image_path(document_path, image_path, fallback)
  local path = fallback(document_path, image_path)
  if vim.uv.fs_stat(path) then
    return path
  end

  local vault = vim.fs.root(document_path, '.obsidian')
  if not vault then
    return path
  end

  local key = vault .. '\0' .. image_path
  if vault_hits[key] == nil then
    local found = vim.fs.find(vim.fs.basename(image_path), { path = vault, type = 'file', limit = 1 })
    vault_hits[key] = found[1] or false
  end
  return vault_hits[key] or path
end

return {
  '3rd/image.nvim',
  build = false, -- the cli processor needs no rock
  ft = { 'markdown' },
  opts = {
    backend = 'kitty',
    processor = 'magick_cli',
    -- hide an image while a float (lazygit, pickers) covers its window
    window_overlap_clear_enabled = true,
    -- ui2's msg and cmd floats stay open with hide set, and image.nvim masks
    -- against hidden floats too, so the image would never redraw
    window_overlap_clear_ft_ignore = { 'cmp_menu', 'cmp_docs', 'snacks_notif', 'scrollview', 'scrollview_sign', 'msg', 'cmd' },
    integrations = {
      markdown = {
        enabled = true,
        only_render_image_at_cursor = false,
        -- remote images are mostly svg badges, which render poorly inline
        download_remote_images = false,
        filetypes = { 'markdown' },
        resolve_image_path = resolve_image_path,
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
