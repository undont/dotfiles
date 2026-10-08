-- mugshot.nvim: blame card for the current line (avatar, time, message, sha,
-- github actions). `gb` opens it, q/<Esc> dismisses; inside the card o opens
-- the commit, y copies the sha, p opens the pr

-- image.lua loads image.nvim on `ft=markdown` only; as a dependency here it
-- also loads with mugshot, so the avatar renders in any filetype

-- true runs mugshot from the ~/playground/mugshot.nvim checkout (restart
-- nvim). falls back to the release when the checkout has no entry module
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
