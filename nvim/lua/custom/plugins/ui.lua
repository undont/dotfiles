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
        { '<leader>c', group = '[C]laude', icon = { icon = ' ', color = 'green' } },
        { '<leader>d', group = '[D]iff', icon = { cat = 'filetype', name = 'git' } },
        { '<leader>h', group = 'Git [H]unk', icon = { cat = 'filetype', name = 'git' } },
        { '<leader>l', group = '[L]SP', icon = { icon = ' ', color = 'orange' } },
        { '<leader>m', group = '[M]arkdown', icon = { cat = 'filetype', name = 'markdown' } },
        { '<leader>n', group = '.[N]ET', icon = { cat = 'filetype', name = 'cs' } },
        { '<leader>p', group = '[P]R Review', icon = { cat = 'filetype', name = 'git' } },
        { '<leader>s', group = '[S]earch', icon = { icon = ' ', color = 'green' } },
        { '<leader>t', group = '[T]est / Toggle', icon = { cat = 'filetype', name = 'neotest-summary' } },
        { '<leader>w', group = '[W]indow', icon = { icon = ' ', color = 'blue' } },
        { '<leader>x', group = 'Diagnostics', icon = { icon = '󱖫 ', color = 'green' } },
        { 'gr', group = 'LSP [R]efactor', icon = { icon = ' ', color = 'cyan' } },
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

  -- Mini plugins (statusline, ai, surround, notify, bracketed, splitjoin)
  {
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      require('mini.surround').setup()

      -- Drop-in vim.notify replacement with notification history
      require('mini.notify').setup()

      -- Wrap vim.notify to suppress duplicate messages within a rolling window.
      -- Normalise messages before keying: Roslyn embeds worktree paths and counters
      -- in progress strings, making visually identical messages appear distinct.
      local _mini_notify = vim.notify
      local _dedup = {}
      vim.notify = function(msg, level, opts)
        local normalised = msg
          :gsub('%s+/[^%s]*', '') -- strip file/dir paths (e.g. " /src/worktree/X.sln")
          :gsub('%s*%d+%%%s*', ' ') -- strip percentages like "50%"
          :gsub('%s*%[%d+/%d+%]%s*', ' ') -- strip counters like "[5/12]"
          :gsub('%s+', ' ') -- collapse whitespace
          :match '^%s*(.-)%s*$' -- trim
        local key = tostring(level) .. normalised
        local now = vim.uv.now()
        local window = normalised:match '^%u' and 30000 or 5000
        if _dedup[key] and now - _dedup[key] < window then
          return
        end
        _dedup[key] = now
        _mini_notify(msg, level, opts)
      end

      -- LSP progress message patterns to suppress from the history view
      local LSP_NOISE = {
        '^Opening solution',
        '^Loading ',
        '^Initializ',
        ' loaded$',
        '^Client initializ',
        '^Workspace ready',
      }
      local function is_lsp_noise(msg)
        for _, pat in ipairs(LSP_NOISE) do
          if msg:match(pat) then
            return true
          end
        end
        return false
      end

      -- Filtered history: warnings/errors + any INFO that isn't LSP progress noise
      vim.keymap.set('n', '<leader>Nn', function()
        local notifs = vim.tbl_values(require('mini.notify').get_all())
        table.sort(notifs, function(a, b)
          return a.ts_update < b.ts_update
        end)
        local filtered = vim.tbl_filter(function(n)
          local lvl = n.level
          if lvl == 'WARN' or lvl == 'ERROR' or lvl == vim.log.levels.WARN or lvl == vim.log.levels.ERROR then
            return true
          end
          return not is_lsp_noise(n.msg or '')
        end, notifs)

        if #filtered == 0 then
          vim.notify('No notifications', vim.log.levels.INFO)
          return
        end

        local lines = vim.tbl_map(function(n)
          local t = os.date('%H:%M:%S', math.floor(n.ts_update))
          return string.format('%s  %s', t, (n.msg or ''):gsub('\n', ' '))
        end, filtered)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false
        vim.bo[buf].bufhidden = 'wipe'

        local w = math.min(math.floor(vim.o.columns * 0.7), 120)
        local h = math.min(#lines, math.floor(vim.o.lines * 0.6))
        vim.api.nvim_open_win(buf, true, {
          relative = 'editor',
          width = w,
          height = h,
          row = math.floor((vim.o.lines - h) / 2),
          col = math.floor((vim.o.columns - w) / 2),
          style = 'minimal',
          border = 'rounded',
          title = ' Notifications ',
          title_pos = 'center',
        })
        vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true })
        vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', { buffer = buf, silent = true })
      end, { desc = 'Notification history (filtered)' })

      -- Full unfiltered history via mini.notify's built-in viewer
      vim.keymap.set('n', '<leader>Na', function()
        require('mini.notify').show_history()
      end, { desc = 'Notification history (all)' })

      -- Extended ]/[ navigation; use uppercase for conflicting suffixes
      require('mini.bracketed').setup {
        comment = { suffix = 'C' }, -- lowercase ]c/[c is gitsigns (git changes)
        file = { suffix = 'F' }, -- lowercase ]f/[f is fugitive (changed files)
        treesitter = { suffix = 'T' }, -- lowercase ]t/[t is neotest (failed tests)
      }

      -- Split/join code constructs (gS to split, gJ to join)
      require('mini.splitjoin').setup()

      -- Simple and easy statusline
      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }

      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
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
