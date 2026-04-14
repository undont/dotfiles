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
        filter = function(mapping)
          return mapping.desc ~= 'diffview_ignore'
        end,
        win = {
          no_overlap = false,
        },
        icons = {
          mappings = vim.g.have_nerd_font,
        },
        spec = {
          -- ── Always-visible groups ──
          { '<leader>a', group = '[A]I', icon = { icon = '󰚩 ', color = 'purple' } },
          { '<leader>b', group = '[B]reakpoint / Buffer', icon = { icon = '󰈔 ', color = 'red' } },
          { '<leader>d', group = '[D]iff', icon = { cat = 'filetype', name = 'git' } },
          { '<leader>H', group = 'Git [H]unk', icon = { cat = 'filetype', name = 'git' } },
          { '<leader>h', group = '[H]arpoon', icon = { icon = '󱡀 ', color = 'blue' } },
          { '<leader>s', group = '[S]earch', icon = { icon = '', color = 'blue' } },
          { '<leader>S', group = '[S]pell', icon = { icon = '󰓆 ', color = 'yellow' } },
          { '<leader>t', group = '[T]est / Toggle', icon = { cat = 'filetype', name = 'neotest-summary' } },
          { '<leader>l', group = '[L]SP', icon = { icon = '', color = 'green' } },
          { '<leader>w', group = '[W]indow', icon = { icon = '', color = 'red' } },

          -- ── Always-visible (non-code contexts like Octo, diffview) ──
          { '<leader>p', group = '[P]R Review', icon = { cat = 'filetype', name = 'git' } },

          -- ── Filetype-gated groups (hidden by default, shown in code files via autocmd) ──
          { '<leader>x', group = 'Diagnostics', icon = { icon = '󱖫 ', color = 'green' }, hidden = true },
          { '<leader>k', group = 'Musi[K]', icon = { icon = '󰎆 ', color = 'purple' }, hidden = true },
          { '<leader>u', icon = { icon = '󰕌 ', color = 'blue' }, hidden = true },
          { 'gr', group = 'LSP [R]efactor', icon = { icon = '󰅩', color = 'green' }, hidden = true },

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

          { '<leader>?', icon = { icon = '', color = 'blue' } },
          { '<leader>/', icon = { icon = '', color = 'blue' } },
          { '<leader><leader>', icon = { icon = '', color = 'blue' } },
          { '<leader>z', icon = { icon = '', color = 'red' } },
          -- ── Conditionally hidden (shown in code files via autocmd) ──
          { '<leader>q', icon = { icon = '', color = 'green' }, hidden = true },
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

      local function update_filetype_groups()
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
          { 'gr', group = 'LSP [R]efactor', icon = { icon = '󰅩', color = 'green' }, hidden = not is_code },
          { '<leader>f', hidden = not is_code },
          { '<leader>k', group = 'Musi[K]', icon = { icon = '󰎆 ', color = 'purple' }, hidden = not is_code },
          { '<leader>u', icon = { icon = '󰕌 ', color = 'blue' }, hidden = not is_code },
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
      end

      vim.api.nvim_create_autocmd({ 'BufEnter', 'FileType' }, {
        group = vim.api.nvim_create_augroup('which-key-filetype', { clear = true }),
        callback = update_filetype_groups,
      })

      vim.schedule(update_filetype_groups)
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

  -- Fidget: LSP progress spinner and vim.notify backend
  {
    'j-hui/fidget.nvim',
    event = 'VeryLazy',
    opts = {
      progress = {
        display = {
          done_ttl = 2,
          progress_icon = { 'dots' },
        },
      },
      notification = {
        override_vim_notify = true,
        window = {
          winblend = 0,
          align = 'bottom',
        },
      },
    },
    config = function(_, opts)
      opts.notification = opts.notification or {}
      opts.notification.configs = {
        default = vim.tbl_extend('force', require('fidget.notification').default_config, {
          name = false,
          icon = false,
        }),
      }
      require('fidget').setup(opts)

      -- Wrap fidget's vim.notify with a spam filter (noisy dotnet/roslyn startup)
      local base_notify = vim.notify
      vim.notify = function(msg, level, nopts)
        if type(msg) ~= 'string' then
          return base_notify(msg, level, nopts)
        end

        if msg:match '^Multiple potential target files found' then
          return
        end

        local title = nopts and nopts.title
        if not title or title == 'Progress' or (type(title) == 'string' and (title:match 'roslyn' or title:match 'easy%-dotnet')) then
          local dotnet_spam = { '^Initializing', '^Loading ', ' loaded$', '^Client initialized' }
          for _, pat in ipairs(dotnet_spam) do
            if msg:match(pat) then
              return
            end
          end
        end

        return base_notify(msg, level, nopts)
      end

      vim.keymap.set('n', '<leader>Nn', '<cmd>Fidget history<cr>', { desc = 'Notification history' })
    end,
  },

  -- Noice: enhanced LSP hover and signature help rendering
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

  -- Mini plugins
  -- VeryLazy so the 7 module requires (surround/pairs/hipatterns/bracketed/
  -- splitjoin/icons/statusline) defer past the initial UI paint. Statusline
  -- redraws once setup lands, which is invisible in practice.
  {
    'echasnovski/mini.nvim',
    event = 'VeryLazy',
    config = function()
      -- Icons provider (used by mini.statusline for filetype icons)
      local template_icon = vim.fn.nr2char(0xf05c0) -- nf-md-file_code_outline
      local gopher_icon = vim.fn.nr2char(0xe627) -- nf-seti-go (gopher)
      require('mini.icons').setup {
        filetype = {
          yaml = { glyph = '' },
          template = { glyph = template_icon },
          go = { glyph = gopher_icon },
        },
        os = {
          git = { glyph = '' }, -- nf-oct-git_branch
        },
        extension = {
          template = { glyph = template_icon },
          go = { glyph = gopher_icon },
        },
      }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      -- Uses 'gs' prefix to avoid delay on native 's' (substitute char)
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
