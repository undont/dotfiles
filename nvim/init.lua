--[[
  nvim configuration

  structure:
    lua/custom/core/      - core settings (options, keymaps, autocmds)
    lua/custom/features/  - bespoke features, each owning its keymaps
    lua/custom/plugins/   - lazy plugin specs
    lua/kickstart/        - kickstart-provided plugins

  <leader>? opens cheatsheet.txt
--]]

require('custom.core.options').setup()
require('custom.core.keymaps').setup()
require('custom.core.autocmds').setup()
require('custom.features.tag-rename').setup()

require('custom.lazy-bootstrap').setup()

-- before lazy.setup: plugins read highlight groups during their own setup
require('custom.core.theme').setup()

-- user-owned overrides. loaded before lazy.setup so plugin specs can read
-- `vim.g.*` set there (e.g. `vim.g.obsidian_vault_root`)
local local_config = vim.fn.stdpath 'config' .. '/local.lua'
if vim.uv.fs_stat(local_config) then
  dofile(local_config)
end

require('lazy').setup({
  { import = 'custom.plugins' },
  { import = 'kickstart.plugins' },
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
