-- UI plugins: colorschemes, which-key, statusline, file explorer

return {
  -- Dracula colorscheme (dark mode)
  {
    'Mofiqul/dracula.nvim',
    priority = 1000,
    config = function()
      require('dracula').setup {
        italic_comment = false,
      }
    end,
  },

  -- Catppuccin colorscheme (light mode - latte variant)
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
  },

  -- Tokyo Night theme
  {
    'folke/tokyonight.nvim',
    lazy = true,
    opts = {
      style = 'night',
      transparent = false,
      terminal_colors = true,
    },
  },

  -- Nord theme
  {
    'shaunsingh/nord.nvim',
    lazy = true,
    config = function()
      vim.g.nord_contrast = true
      vim.g.nord_borders = true
      vim.g.nord_disable_background = false
    end,
  },

  -- Gruvbox theme
  {
    'ellisonleao/gruvbox.nvim',
    lazy = true,
    opts = {
      contrast = 'hard',
      transparent_mode = false,
    },
  },

  -- Solarized Osaka theme (modern solarized)
  {
    'craftzdog/solarized-osaka.nvim',
    lazy = true,
    opts = {
      transparent = false,
    },
  },

  -- One Dark theme
  {
    'navarasu/onedark.nvim',
    lazy = true,
    opts = {
      style = 'dark',
    },
  },

  -- Monokai Pro theme
  {
    'loctvl842/monokai-pro.nvim',
    lazy = true,
    opts = {
      filter = 'pro', -- classic | octagon | pro | machine | ristretto | spectrum
    },
  },

  -- Ayu theme
  {
    'Shatur/neovim-ayu',
    lazy = true,
    config = function()
      require('ayu').setup {
        mirage = false,
        terminal = true,
      }
    end,
  },

  -- Everforest theme
  {
    'neanias/everforest-nvim',
    lazy = true,
    opts = {
      background = 'hard',
      transparent_background_level = 0,
    },
  },

  -- Kanagawa theme
  {
    'rebelot/kanagawa.nvim',
    lazy = true,
    opts = {
      theme = 'wave',
      background = {
        dark = 'wave',
      },
    },
  },

  -- Rose Pine theme
  {
    'rose-pine/neovim',
    name = 'rose-pine',
    lazy = true,
    opts = {
      variant = 'main',
      disable_background = false,
    },
  },

  -- Nightfox theme
  {
    'EdenEast/nightfox.nvim',
    lazy = true,
    opts = {
      options = {
        transparent = false,
      },
    },
  },

  -- Auto dark mode - follows system theme
  -- (disabled when dotfiles theme is active)
  {
    'f-person/auto-dark-mode.nvim',
    enabled = vim.fn.filereadable((os.getenv 'XDG_CONFIG_HOME' or vim.fn.expand '~/.config') .. '/dotfiles/current-theme') == 0,
    priority = 999,
    opts = {
      update_interval = 1000,
      set_dark_mode = function()
        vim.api.nvim_set_option_value('background', 'dark', {})
        vim.cmd.colorscheme 'dracula'
      end,
      set_light_mode = function()
        vim.api.nvim_set_option_value('background', 'light', {})
        vim.cmd.colorscheme 'catppuccin-latte'
      end,
    },
  },

  -- File explorer (neo-tree is imported from kickstart)
  -- See kickstart/plugins/neo-tree.lua

  -- Which-key for keybinding hints
  {
    'folke/which-key.nvim',
    lazy = false, -- Load immediately to ensure leader preview works reliably
    opts = {
      delay = 0, -- Show immediately for snappy feel
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },
      spec = {
        { '<leader>s', group = '[S]earch' },
	{ '<leader>t', group = '[T]est' },
        { '<leader>d', group = '[D]iff' },
        { '<leader>p', group = '[P]R Review' },
      },
    },
  },

  -- Todo comments highlighting
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },

  -- Mini plugins (statusline, ai, surround)
  {
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      require('mini.surround').setup()

      -- Simple and easy statusline
      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }

      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end
    end,
  },
}
