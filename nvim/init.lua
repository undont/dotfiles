--[[
  nvim configuration

  structure:
    lua/core/      - core settings (options, keymaps, autocmds)
    lua/features/  - bespoke features, each owning its keymaps
    lua/plugins/   - lazy plugin specs

  <leader>? opens cheatsheet.txt
--]]

require('core.options').setup()
require('core.keymaps').setup()
require('core.autocmds').setup()
require('features.tag-rename').setup()

require('lazy-bootstrap').setup()

-- before lazy.setup: plugins read highlight groups during their own setup
require('core.theme').setup()

-- user-owned overrides. loaded before lazy.setup so plugin specs can read
-- `vim.g.*` set there (e.g. `vim.g.obsidian_vault_root`)
local local_config = vim.fn.stdpath 'config' .. '/local.lua'
if vim.uv.fs_stat(local_config) then
  dofile(local_config)
end

require('lazy').setup({
  { import = 'plugins' },
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})
