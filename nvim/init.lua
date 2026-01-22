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

-- Load dotfiles theme integration (after plugins are loaded)
vim.api.nvim_create_autocmd('User', {
  pattern = 'VeryLazy',
  callback = function()
    require('custom.core.theme').setup()
  end,
})
