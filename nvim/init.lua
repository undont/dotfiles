--[[
  Neovim Configuration

  Structure:
    lua/custom/core/      - Core settings (options, keymaps, autocmds)
    lua/custom/plugins/   - Plugin configurations
    lua/kickstart/        - Kickstart-provided plugins

  See lua/custom/core/keymaps.lua for keybindings
  Press <Space>h for quick reference
--]]

-- Load core configuration
require('custom.core.options').setup()
require('custom.core.keymaps').setup()
require('custom.core.autocmds').setup()

-- Bootstrap and load plugins
require('custom.lazy-bootstrap').setup()

-- Apply colourscheme before plugins load so gitsigns, diffview, etc.
-- pick up the correct highlight groups during their own setup.
require('custom.core.theme').setup()

require('lazy').setup({
  -- Custom plugins
  { import = 'custom.plugins' },

  -- Kickstart plugins (neo-tree, autopairs, gitsigns, indent guides)
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

-- User overrides (not managed by dotfiles — survives dotfiles update)
-- Edit ~/.config/nvim/local.lua to personalise options, keymaps, etc.
local local_config = vim.fn.stdpath 'config' .. '/local.lua'
if vim.uv.fs_stat(local_config) then
  dofile(local_config)
end
