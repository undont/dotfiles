-- Core Neovim options
-- See :help vim.o and :help vim.g

local M = {}

function M.setup()
  -- Leader key (must be set before plugins load)
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  -- Nerd Font availability
  vim.g.have_nerd_font = true

  -- Line numbers
  vim.o.number = true
  vim.o.relativenumber = true

  -- Mouse support
  vim.o.mouse = 'a'

  -- Don't show mode in command line (shown in statusline)
  vim.o.showmode = false

  -- Sync clipboard between OS and Neovim
  -- Schedule after UiEnter to avoid increasing startup time
  vim.schedule(function()
    vim.o.clipboard = 'unnamedplus'
  end)

  -- Indentation
  vim.o.tabstop = 4
  vim.o.breakindent = true

  -- Project-local config: source a trusted .nvim.lua from the working
  -- directory (prompts to trust on first load; see :help 'exrc')
  vim.o.exrc = true

  -- Persistent undo
  vim.o.undofile = true

  -- Disable swap files (undo + autoread + git make them redundant)
  vim.o.swapfile = false

  -- Search
  vim.o.ignorecase = true
  vim.o.smartcase = true

  -- Use ripgrep for :grep / :grepadd (quickfix-based workflow)
  if vim.fn.executable 'rg' == 1 then
    vim.o.grepprg = 'rg --vimgrep --smart-case'
    vim.o.grepformat = '%f:%l:%c:%m'
  end

  -- UI
  vim.o.signcolumn = 'yes'
  vim.o.updatetime = 250
  vim.o.timeoutlen = 200
  vim.o.ttimeoutlen = 10 -- Fast key code sequences (responsive escape key)
  vim.opt.shortmess:append 'I' -- Suppress intro screen (flashes with cmdheight=0)

  -- Window splitting
  vim.o.splitright = true
  vim.o.splitbelow = true

  -- Whitespace characters
  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

  -- Live substitution preview
  vim.o.inccommand = 'split'

  -- Cursor line
  vim.o.cursorline = true

  -- Scroll offset
  vim.o.scrolloff = 10

  -- Confirm before closing unsaved buffers
  vim.o.confirm = true

  -- Auto-reload files changed outside nvim
  vim.o.autoread = true

  -- Spellcheck
  vim.o.spell = true
  vim.opt.spelllang = { 'en_gb' }
  vim.opt.spelloptions = { 'camel' }
  vim.opt.spellcapcheck = ''

  -- Spellfiles: user dictionary (zg adds here) + repo dictionary (shared terms)
  local user_spell_dir = vim.fn.stdpath 'data' .. '/spell'
  vim.fn.mkdir(user_spell_dir, 'p')
  vim.opt.spellfile = {
    user_spell_dir .. '/en.utf-8.add',
    vim.fn.stdpath 'config' .. '/spell/en.utf-8.add',
  }

  -- Cursor style (block in all modes, blinking in insert)
  vim.opt.guicursor = 'n-v-c:block,i-ci-ve:block-blinkwait700-blinkon400-blinkoff250'

  -- Reclaim the command line row (ui2 msg window handles messages)
  vim.o.cmdheight = 0

  -- Experimental UI2: replaces builtin message + cmdline presentation.
  -- Messages appear in a floating window that auto-dismisses; cmdline
  -- appears on-demand. Use g< or ENTER after a command to see full messages.
  require('vim._core.ui2').enable {
    msg = {
      targets = 'msg',
      msg = {
        timeout = 4000,
      },
    },
  }
end

return M
