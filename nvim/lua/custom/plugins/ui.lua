-- UI plugins: which-key, statusline, todo-comments
-- Colourschemes are custom files in nvim/colors/ — no plugins needed

return {
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
      },
      spec = {
        { '<leader>a', group = '[A]I', icon = { icon = '󰚩 ', color = 'purple' } },
        { '<leader>b', group = '[B]uffer', icon = { icon = '󰈔 ', color = 'azure' } },
        { '<leader>B', group = '[B]reakpoint', icon = { icon = '', color = 'red' } },
        { '<leader>c', group = '[C]laude', icon = { icon = '', color = 'green' } },
        { '<leader>d', group = '[D]iff', icon = { cat = 'filetype', name = 'git' } },
        { '<leader>H', group = 'Git [H]unk', icon = { cat = 'filetype', name = 'git' } },
        { '<leader>l', group = '[L]SP', icon = { icon = '', color = 'orange' } },
        { '<leader>m', group = '[M]arkdown', icon = { cat = 'filetype', name = 'markdown' } },
        { '<leader>n', group = '.[N]ET', icon = { cat = 'filetype', name = 'cs' } },
        { '<leader>p', group = '[P]R Review', icon = { cat = 'filetype', name = 'git' } },
        { '<leader>s', group = '[S]earch', icon = { icon = '', color = 'green' } },
        { '<leader>S', group = '[S]pell', icon = { icon = '󰓆 ', color = 'yellow' } },
        { '<leader>t', group = '[T]est / Toggle', icon = { cat = 'filetype', name = 'neotest-summary' } },
        { '<leader>w', group = '[W]indow', icon = { icon = '', color = 'blue' } },
        { '<leader>x', group = 'Diagnostics', icon = { icon = '󱖫 ', color = 'green' } },
        { 'gr', group = 'LSP [R]efactor', icon = { icon = '󰅩', color = 'cyan' } },
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

  -- Trouble: better diagnostics list
  {
    'folke/trouble.nvim',
    cmd = 'Trouble',
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>', desc = 'All diagnostics' },
      { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', desc = 'Buffer diagnostics' },
      { '<leader>xq', '<cmd>Trouble qflist toggle<CR>', desc = 'Quickfix list' },
      { '<leader>xl', '<cmd>Trouble loclist toggle<CR>', desc = 'Location list' },
    },
    opts = {},
  },

  -- Noice: enhanced LSP hover and signature help rendering (progress handled by fidget.nvim)
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = { 'MunifTanjim/nui.nvim' },
    opts = {
      cmdline = { enabled = false },
      messages = { enabled = false },
      popupmenu = { enabled = false },
      notify = { enabled = false },
      lsp = {
        hover = { enabled = true },
        signature = { enabled = true },
        progress = { enabled = false },
        message = { enabled = false },
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
        },
      },
      presets = {
        lsp_doc_border = true,
        bottom_search = true,
        long_message_to_split = true,
      },
    },
  },

  -- Nvim-notify: beautiful animated notifications
  {
    'rcarriga/nvim-notify',
    event = 'VeryLazy',
    config = function()
      local notify = require 'notify'
      notify.setup {
        stages = 'fade',
        timeout = 3000,
        max_width = 80,
        max_height = 20,
        render = 'compact',
        background_colour = 'Normal',
        icons = {
          ERROR = '',
          WARN = '',
          INFO = '',
          DEBUG = '',
          TRACE = '',
        },
      }
      vim.notify = notify

      -- Suppress easy-dotnet progress spam - let "workspace ready" tell us if something went wrong
      local _original_notify = vim.notify
      vim.notify = function(msg, level, opts)
        -- Block easy-dotnet LSP spam patterns (keep "Opening solution" visible)
        local spam_patterns = {
          '^Initializing',
          '^Loading ',
          ' loaded$',
          '^Client initialized',
          '^No matching notification',
          '^Multiple potential target files found', -- roslyn.nvim on non-file buffers (Octo, etc.)
        }
        if type(msg) == 'string' then
          for _, pat in ipairs(spam_patterns) do
            if msg:match(pat) then
              return -- drop spam message
            end
          end
        end
        return _original_notify(msg, level, opts)
      end

      --- Open a notification history float with dynamic height.
      local function open_notify_float(title, entries)
        if #entries == 0 then
          vim.notify('No notifications', vim.log.levels.INFO)
          return
        end

        local level_icons = {
          [vim.log.levels.ERROR] = 'E',
          [vim.log.levels.WARN] = 'W',
          [vim.log.levels.INFO] = 'I',
          [vim.log.levels.DEBUG] = 'D',
          [vim.log.levels.TRACE] = 'T',
        }
        local lines = vim.tbl_map(function(n)
          local t = os.date('%H:%M:%S', math.floor(n.time / 1000))
          local icon = level_icons[n.level] or 'I'
          local msg = type(n.message) == 'table' and table.concat(n.message, ' ') or tostring(n.message or '')
          return string.format('%s [%s] %s', t, icon, msg:gsub('\n', ' '))
        end, entries)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false
        vim.bo[buf].bufhidden = 'wipe'

        local w = math.min(math.floor(vim.o.columns * 0.8), 120)
        -- Count wrapped screen lines to size the window properly
        local wrapped = 0
        for _, line in ipairs(lines) do
          wrapped = wrapped + math.max(1, math.ceil(#line / w))
        end
        local h = math.max(3, math.min(wrapped, math.floor(vim.o.lines * 0.6)))

        local win = vim.api.nvim_open_win(buf, true, {
          relative = 'editor',
          width = w,
          height = h,
          row = math.floor((vim.o.lines - h) / 2),
          col = math.floor((vim.o.columns - w) / 2),
          style = 'minimal',
          border = 'rounded',
          title = ' ' .. title .. ' ',
          title_pos = 'center',
        })
        vim.wo[win].wrap = true
        vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true })
        vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', { buffer = buf, silent = true })
      end

      -- Notification history viewer (warnings/errors only)
      vim.keymap.set('n', '<leader>Nn', function()
        local history = notify.history()
        local filtered = vim.tbl_filter(function(n)
          return n.level == vim.log.levels.WARN or n.level == vim.log.levels.ERROR
        end, history)
        open_notify_float('Notifications', filtered)
      end, { desc = 'Notification history (filtered)' })

      -- Full unfiltered history
      vim.keymap.set('n', '<leader>Na', function()
        open_notify_float('All Notifications', notify.history())
      end, { desc = 'Notification history (all)' })
    end,
  },

  -- Mini plugins
  {
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      -- Prefix remapped from 's' to 'gs' to avoid clash with flash.nvim
      require('mini.surround').setup {
        mappings = {
          add = 'gsa',
          delete = 'gsd',
          find = 'gsf',
          find_left = 'gsF',
          highlight = 'gsh',
          replace = 'gsr',
          update_n_lines = 'gsn',
        },
      }

      -- Auto-close brackets, quotes, etc. (replaces nvim-autopairs)
      require('mini.pairs').setup()

      -- Highlight hex colour codes inline
      require('mini.hipatterns').setup {
        highlighters = {
          hex_color = require('mini.hipatterns').gen_highlighter.hex_color(),
        },
      }

      -- Extended ]/[ navigation; disable suffixes that conflict with other plugins
      require('mini.bracketed').setup {
        comment = { suffix = '' }, -- ]c/[c reserved for gitsigns (git changes)
        file = { suffix = 'f' }, -- diffview overrides ]f/[f when open
        treesitter = { suffix = '' }, -- ]t/[t reserved for neotest (failed tests)
      }

      -- Split/join code constructs (gS to split, gJ to join)
      require('mini.splitjoin').setup()

      -- Simple and easy statusline
      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }

      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        local loc = '%2l:%-2v'
        if vim.t.zoomed then
          loc = loc .. ' Z'
        end
        return loc
      end

      -- Truncate branch name to ticket ID (e.g. "feature/DANA-123-some-desc" -> "DANA-123")
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_git = function(args)
        if statusline.is_truncated(args.trunc_width) then
          return ''
        end
        local head = vim.b.gitsigns_head or ''
        if head == '' then
          return ''
        end
        -- Extract ticket ID pattern (e.g. DANA-123, JIRA-456)
        local ticket = head:match '[A-Z]+-[0-9]+'
        local branch = ticket or head
        local icon = vim.g.have_nerd_font and ' ' or 'Git:'
        return icon .. branch
      end
    end,
  },
}
