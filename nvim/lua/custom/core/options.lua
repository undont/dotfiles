-- core nvim options

local M = {}

function M.setup()
  -- must be set before plugins load
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  vim.g.have_nerd_font = true

  vim.o.number = true
  vim.o.relativenumber = true

  vim.o.mouse = 'a'

  -- the statusline shows the mode
  vim.o.showmode = false

  vim.o.tabstop = 4
  vim.o.breakindent = true

  -- sources a trusted .nvim.lua from the working directory
  vim.o.exrc = true

  vim.o.undofile = true

  vim.o.swapfile = false

  -- the default backupdir starts with `.`, which writes the backup next to the
  -- file; a synced obsidian vault replicates that as a document
  vim.o.backupdir = vim.fn.stdpath 'state' .. '/backup//'

  vim.o.ignorecase = true
  vim.o.smartcase = true

  if vim.fn.executable 'rg' == 1 then
    vim.o.grepprg = 'rg --vimgrep --smart-case'
    vim.o.grepformat = '%f:%l:%c:%m'
  end

  vim.o.signcolumn = 'yes'
  vim.o.updatetime = 250
  vim.o.timeoutlen = 200
  vim.o.ttimeoutlen = 10
  vim.opt.shortmess:append 'I' -- the intro screen flashes with cmdheight=0

  vim.o.splitright = true
  vim.o.splitbelow = true

  vim.o.list = true
  -- indent-blankline draws leading indentation, so tab is blank. omitting
  -- the key with `list` on falls back to `^I`
  vim.opt.listchars = { tab = '  ', trail = '·', nbsp = '␣' }

  vim.o.inccommand = 'split'

  vim.o.cursorline = true

  vim.o.scrolloff = 10

  vim.o.confirm = true

  vim.o.autoread = true

  vim.o.clipboard = 'unnamedplus'

  -- bare ssh with no display server and no tmux: nvim finds no clipboard tool,
  -- and its OSC 52 fallback is skipped whenever 'clipboard' is non-empty (see
  -- provider/clipboard.vim). copy goes out over OSC 52; paste reads a cache
  -- file, since an OSC 52 read blocks on a response most terminals never send
  local has_clipboard = vim.env.DISPLAY or vim.env.WAYLAND_DISPLAY or vim.env.TMUX or vim.fn.has 'mac' == 1
  if not has_clipboard then
    local osc52 = require 'vim.ui.clipboard.osc52'
    local cache = vim.fn.stdpath 'cache' .. '/clipboard'

    local function copy(reg)
      local send = osc52.copy(reg)
      return function(lines, regtype)
        send(lines)
        -- regtype rides along as the first line so blockwise/linewise yanks
        -- paste back with the shape they were yanked with
        pcall(vim.fn.writefile, vim.list_extend({ regtype or 'v' }, lines), cache)
      end
    end

    local function paste()
      local ok, lines = pcall(vim.fn.readfile, cache)
      if not ok or type(lines) ~= 'table' or #lines == 0 then
        return { {}, 'v' }
      end
      local regtype = table.remove(lines, 1)
      return { lines, regtype }
    end

    vim.g.clipboard = {
      name = 'osc52+cache',
      copy = { ['+'] = copy '+', ['*'] = copy '*' },
      paste = { ['+'] = paste, ['*'] = paste },
    }
  end

  vim.o.spell = true
  vim.opt.spelllang = { 'en_gb' }
  vim.opt.spelloptions = { 'camel' }
  vim.opt.spellcapcheck = ''

  -- zg adds to the user dictionary; the repo one holds shared terms
  local user_spell_dir = vim.fn.stdpath 'data' .. '/spell'
  vim.fn.mkdir(user_spell_dir, 'p')
  vim.opt.spellfile = {
    user_spell_dir .. '/en.utf-8.add',
    vim.fn.stdpath 'config' .. '/spell/en.utf-8.add',
  }

  vim.opt.guicursor = 'n-v-c:block,i-ci-ve:block-blinkwait700-blinkon400-blinkoff250'

  -- the ui2 msg window shows messages
  vim.o.cmdheight = 0

  -- `targets` is the key on both 0.12 and 0.13: the singular `target` is
  -- ignored on 0.13, leaving messages in the cmdline
  require('vim._core.ui2').enable { msg = { targets = 'msg' } }

  if vim.g.neovide then
    vim.g.neovide_cursor_animation_length = 0.050
    vim.g.neovide_cursor_trail_size = 0.5
    vim.g.neovide_cursor_smooth_blink = true
  end
end

return M
