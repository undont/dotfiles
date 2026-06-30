-- mugshot.nvim: a gitlens-style rich blame card for the current line. author
-- avatar (real github profile picture), relative + absolute time, full message,
-- sha, and in-card github actions. triggered with `gb`, dismissed with q/<Esc>.
-- in-card gestures (cursor enters the focused card): o open commit, y copy sha,
-- p open pr.
--
-- distinct from the existing blame tools: fugitive's `<leader>Gb` (:Git blame
-- buffer) and gitsigns inline blame both stay. mugshot is the one-line hover card
-- with the face.

-- image.nvim is a hard dependency here on purpose: image.lua loads it `ft=markdown`
-- only, so without this edge it would be absent in code buffers and the card would
-- silently fall back to text. as a dependency it loads with mugshot (reusing
-- image.lua's kitty/magick_cli opts), so the avatar renders in any filetype.

-- local-dev toggle: flip to true (and restart nvim) to run mugshot from the
-- ~/playground/mugshot.nvim checkout instead of the installed release. lazy serves
-- the plugin's modules from `dir`, so this is the only place the swap takes. guarded
-- by the entry module existing, so leaving it true on a machine without the checkout
-- (or with a stale/empty one) falls back to the release rather than pointing lazy at
-- a dir with no modules
local MUGSHOT_DEV = true
local MUGSHOT_LOCAL = vim.fn.expand '~/playground/mugshot.nvim'
local MUGSHOT_USE_DEV = MUGSHOT_DEV and vim.fn.filereadable(MUGSHOT_LOCAL .. '/lua/mugshot/init.lua') == 1

return {
  {
    'undont/mugshot.nvim',
    dir = MUGSHOT_USE_DEV and MUGSHOT_LOCAL or nil,
    dependencies = { '3rd/image.nvim' },
    cmd = 'Mugshot',
    keys = {
      { 'gb', '<cmd>Mugshot<CR>', desc = '[G]it [B]lame card' },
    },
    -- the spec owns `gb` (above) for lazy-loading; keymap = false stops setup()
    -- from binding it a second time
    opts = { keymap = false },
  },
}
