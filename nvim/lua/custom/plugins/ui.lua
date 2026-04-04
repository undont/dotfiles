-- UI plugins: which-key, statusline, todo-comments
-- Colourschemes are custom files in nvim/colors/ — no plugins needed

return {
  -- File explorer (neo-tree is imported from kickstart)
  -- See kickstart/plugins/neo-tree.lua

  -- Which-key for keybinding hints
  -- Tiered display: top-level shows category groups only; standalone keys and
  -- context-specific groups are hidden unless the filetype is relevant.
  {
    'folke/which-key.nvim',
    lazy = false, -- Load immediately to ensure leader preview works reliably
    config = function()
      local wk = require 'which-key'

      -- Custom highlight for Claude icon (distinct orange, not DiagnosticWarn yellow)
      vim.api.nvim_set_hl(0, 'WhichKeyIconClaude', { fg = '#ff9e64' })
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('which-key-claude-hl', { clear = true }),
        callback = function()
          vim.api.nvim_set_hl(0, 'WhichKeyIconClaude', { fg = '#ff9e64' })
        end,
      })

      -- Filetype sets for context gating
      local dotnet_fts = { cs = true, fsharp = true, razor = true, xml = true }

      wk.setup {
        delay = 0, -- Show immediately for snappy feel
        icons = {
          mappings = vim.g.have_nerd_font,
        },
        spec = {
          -- ── Always-visible groups ──
          { '<leader>a', group = '[A]I', icon = { icon = '󰚩 ', color = 'purple' } },
          { '<leader>b', group = '[B]uffer / Breakpoint', icon = { icon = '󰈔 ', color = 'azure' } },
          { '<leader>d', group = '[D]iff', icon = { cat = 'filetype', name = 'git' } },
          { '<leader>H', group = 'Git [H]unk', icon = { cat = 'filetype', name = 'git' } },
          { '<leader>h', group = '[H]arpoon', icon = { icon = '󱡀 ', color = 'cyan' } },
          { '<leader>s', group = '[S]earch', icon = { icon = '', color = 'green' } },
          { '<leader>S', group = '[S]pell', icon = { icon = '󰓆 ', color = 'yellow' } },
          { '<leader>t', group = '[T]est / Toggle', icon = { cat = 'filetype', name = 'neotest-summary' } },
          { '<leader>l', group = '[L]SP', icon = { icon = '', color = 'orange' } },
          { '<leader>w', group = '[W]indow', icon = { icon = '', color = 'blue' } },

          -- ── Always-visible (non-code contexts like Octo, diffview) ──
          { '<leader>p', group = '[P]R Review', icon = { cat = 'filetype', name = 'git' } },

          -- ── Filetype-gated groups (hidden by default, shown in code files via autocmd) ──
          { '<leader>x', group = 'Diagnostics', icon = { icon = '󱖫 ', color = 'green' }, hidden = true },
          { '<leader>k', group = 'Musi[K]', icon = { icon = '󰎆 ', color = 'purple' }, hidden = true },
          { 'gr', group = 'LSP [R]efactor', icon = { icon = '󰅩', color = 'cyan' }, hidden = true },

          -- ── Filetype-gated groups (hidden by default, shown for specific filetypes via autocmd) ──
          { '<leader>c', group = '[C]laude', icon = { icon = '', hl = 'WhichKeyIconClaude' }, hidden = true },
          { '<leader>m', group = '[M]arkdown', icon = { cat = 'filetype', name = 'markdown' }, hidden = true },
          { '<leader>n', group = '.[N]ET', icon = { cat = 'filetype', name = 'cs' }, hidden = true },
          { '<leader>N', group = '[N]otifications', icon = { icon = '󰈸 ', color = 'yellow' } },

          -- ── Always-hidden standalone keys (muscle memory) ──
          { '<leader>1', hidden = true },
          { '<leader>2', hidden = true },
          { '<leader>3', hidden = true },
          { '<leader>4', hidden = true },
          { '<leader>e', hidden = true },
          { '<leader>g', hidden = true },
          { '<leader>i', hidden = true },

          { '<leader>?', icon = { icon = '', color = 'cyan' } },
          { '<leader>/', icon = { icon = '', color = 'green' } },
          { '<leader><leader>', icon = { icon = '', color = 'azure' } },
          { '<leader>z', icon = { icon = '', color = 'blue' } },
          -- ── Conditionally hidden (shown in code files via autocmd) ──
          { '<leader>q', icon = { icon = '', color = 'orange' }, hidden = true },
          { '<leader>f', hidden = true },
          { '<leader>bb', hidden = true },
          { '<leader>bc', hidden = true },
          { '<leader>bL', hidden = true },
          { '<leader>bl', hidden = true },
        },
      }

      -- Show/hide context-specific groups based on current buffer filetype
      local non_code_fts = {
        [''] = true,
        dashboard = true,
        lazy = true,
        mason = true,
        oil = true,
        gitcommit = true,
        gitrebase = true,
        DressingInput = true,
        TelescopePrompt = true,
        ['neotest-summary'] = true,
        ['neotest-output-panel'] = true,
      }

      -- Track last visibility state to avoid unnecessary wk.add calls.
      -- Each wk.add internally calls Buf.clear() which removes ALL trigger
      -- keymaps from ALL buffers, creating a brief window where which-key
      -- can't intercept <leader>. Caching prevents this during rapid buffer
      -- transitions (e.g. diffview file navigation).
      local prev_vis = {}

      vim.api.nvim_create_autocmd('BufEnter', {
        group = vim.api.nvim_create_augroup('which-key-filetype', { clear = true }),
        callback = function()
          -- Only update for real file buffers; preserve previous state in
          -- special contexts (diffview, telescope, neo-tree, etc.)
          if vim.bo.buftype ~= '' then
            return
          end
          local ft = vim.bo.filetype
          if ft == '' then
            return
          end
          local is_code = not non_code_fts[ft]
          local is_markdown = ft == 'markdown'
          local is_dotnet = dotnet_fts[ft] or false

          if prev_vis.code == is_code and prev_vis.md == is_markdown and prev_vis.dotnet == is_dotnet then
            return
          end
          prev_vis = { code = is_code, md = is_markdown, dotnet = is_dotnet }

          wk.add {
            -- Code-file groups (LSP, diagnostics, format, breakpoints)
            { '<leader>x', group = 'Diagnostics', icon = { icon = '󱖫 ', color = 'green' }, hidden = not is_code },
            { 'gr', group = 'LSP [R]efactor', icon = { icon = '󰅩', color = 'cyan' }, hidden = not is_code },
            { '<leader>f', hidden = not is_code },
            { '<leader>k', group = 'Musi[K]', icon = { icon = '󰎆 ', color = 'purple' }, hidden = not is_code },
            { '<leader>q', hidden = not is_code },
            { '<leader>bb', hidden = not is_code },
            { '<leader>bc', hidden = not is_code },
            { '<leader>bL', hidden = not is_code },
            { '<leader>bl', hidden = not is_code },

            -- Markdown-only groups
            { '<leader>c', group = '[C]laude', icon = { icon = '', hl = 'WhichKeyIconClaude' }, hidden = not is_markdown },
            { '<leader>m', group = '[M]arkdown', icon = { cat = 'filetype', name = 'markdown' }, hidden = not is_markdown },

            -- .NET-only group
            { '<leader>n', group = '.[N]ET', icon = { cat = 'filetype', name = 'cs' }, hidden = not is_dotnet },
          }
        end,
      })
    end,
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

  -- Noice: enhanced LSP hover and signature help rendering (progress handled by nvim-notify)
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

      -- Suppress noisy notifications selectively
      local _original_notify = vim.notify
      vim.notify = function(msg, level, opts)
        if type(msg) ~= 'string' then
          return _original_notify(msg, level, opts)
        end

        -- Suppress INFO noise for 2s after <leader>lR refresh (async LSP shutdown
        -- messages arrive well after the defer that shows "Neovim refreshed")
        local refresh_at = vim.g.nvim_refresh_at
        if refresh_at and (vim.uv.now() - refresh_at) < 2000 and (level == vim.log.levels.INFO or level == nil) then
          return
        end

        -- Global noise (source-agnostic)
        if msg:match '^No matching notification' then
          return
        end
        if msg:match '^Multiple potential target files found' then
          return
        end

        -- Dotnet startup spam — only filter untitled (direct easy-dotnet calls) or dotnet-sourced
        local title = opts and opts.title
        if not title or title == 'Progress' or title:match 'roslyn' or title:match 'easy%-dotnet' then
          local dotnet_spam = { '^Initializing', '^Loading ', ' loaded$', '^Client initialized' }
          for _, pat in ipairs(dotnet_spam) do
            if msg:match(pat) then
              return
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

      -- LSP progress → nvim-notify (replaces fidget.nvim)
      local progress_notifications = {} ---@type table<string, number|nil>
      vim.api.nvim_create_autocmd('LspProgress', {
        callback = function(ev)
          local data = ev.data
          if not data or not data.params then
            return
          end
          local val = data.params.value
          if not val then
            return
          end

          -- Skip roslyn's stale Restore progress tokens (never complete)
          if val.title and val.title:match '^Restore' then
            return
          end

          local client = vim.lsp.get_client_by_id(data.client_id)
          local client_name = client and client.name or 'lsp'
          local token = data.params.token
          local key = data.client_id .. ':' .. tostring(token)

          if val.kind == 'begin' then
            local msg = val.title or 'Working...'
            if val.message then
              msg = msg .. ': ' .. val.message
            end
            progress_notifications[key] = vim.notify(msg, vim.log.levels.INFO, {
              title = client_name,
              timeout = false,
              hide_from_history = true,
            })
          elseif val.kind == 'report' then
            local existing = progress_notifications[key]
            if existing then
              local msg = val.message or val.title or 'Working...'
              if val.percentage then
                msg = msg .. ' (' .. val.percentage .. '%)'
              end
              vim.notify(msg, vim.log.levels.INFO, {
                title = client_name,
                replace = existing,
                timeout = false,
                hide_from_history = true,
              })
            end
          elseif val.kind == 'end' then
            local existing = progress_notifications[key]
            if existing then
              local msg = val.message or 'Done'
              vim.notify(msg, vim.log.levels.INFO, {
                title = client_name,
                replace = existing,
                timeout = 2000,
                hide_from_history = true,
              })
              progress_notifications[key] = nil
            end
          end
        end,
      })

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
      -- Icons provider (used by mini.statusline for filetype icons)
      local template_icon = vim.fn.nr2char(0xf05c0) -- nf-md-file_code_outline
      require('mini.icons').setup {
        filetype = {
          yaml = { glyph = '' },
          template = { glyph = template_icon },
        },
        os = {
          git = { glyph = '' }, -- nf-oct-git_branch
        },
        extension = {
          template = { glyph = template_icon },
        },
      }

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

      -- Strip home directory prefix from filename (~/foo/bar → foo/bar)
      ---@diagnostic disable-next-line: duplicate-set-field, unused-local
      statusline.section_filename = function(args)
        if vim.bo.buftype == 'terminal' then
          return '%t'
        end
        local path = vim.fn.expand '%:p'
        local home = vim.uv.os_homedir()
        if home and path:sub(1, #home) == home then
          path = '~' .. path:sub(#home + 1)
        end
        local flags = (vim.bo.modified and ' [+]' or '') .. (vim.bo.readonly and ' [RO]' or '')
        return path .. flags
      end

      -- Compact diff (just +N -N), hide LSP server count
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_diff = function(args)
        if statusline.is_truncated(args.trunc_width) then
          return ''
        end
        local s = vim.b.gitsigns_status_dict
        if not s then
          return ''
        end
        local parts = {}
        if (s.added or 0) > 0 then
          table.insert(parts, '+' .. s.added)
        end
        if (s.removed or 0) > 0 then
          table.insert(parts, '-' .. s.removed)
        end
        if #parts == 0 then
          return ''
        end
        return table.concat(parts, ' ')
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_lsp = function()
        return ''
      end

      -- Truncate branch name to ticket ID (e.g. "feature/ACME-123-some-desc" -> "ACME-123")
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_git = function(args)
        if statusline.is_truncated(args.trunc_width) then
          return ''
        end
        local head = vim.b.gitsigns_head or ''
        if head == '' then
          return ''
        end
        -- Extract ticket ID pattern (e.g. ACME-123, JIRA-456)
        local ticket = head:match '[A-Z]+-[0-9]+'
        local branch = ticket or head
        local icon = vim.g.have_nerd_font and (MiniIcons.get('os', 'git') .. ' ') or 'Git: '
        return icon .. branch
      end
    end,
  },
}
