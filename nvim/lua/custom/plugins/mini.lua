-- Mini.nvim modules: icons, surround, pairs, hipatterns, bracketed,
-- splitjoin, statusline.
-- Loads eagerly so mini.icons custom glyphs are available for the
-- dashboard. All modules are lightweight (keymaps/tables).

return {
  {
    'echasnovski/mini.nvim',
    lazy = false,
    config = function()
      -- Icons provider (used by mini.statusline for filetype icons)
      local template_icon = vim.fn.nr2char(0xf05c0) -- nf-md-file_code_outline
      local gopher_icon = vim.fn.nr2char(0xe627) -- nf-seti-go (gopher)
      local yaml_icon = vim.fn.nr2char(0xf013) -- nf-fa-cog
      local csharp_icon = vim.fn.nr2char(0xf031b) -- nf-md-language_csharp (matches `cs` extension)
      require('mini.icons').setup {
        filetype = {
          yaml = { glyph = yaml_icon },
          template = { glyph = template_icon },
          go = { glyph = gopher_icon },
          -- render-markdown looks up code-block languages as filetypes; without
          -- this `csharp` falls back to the generic file glyph instead of the
          -- C# icon that mini.icons ships for the `cs` extension.
          cs = { glyph = csharp_icon, hl = 'MiniIconsGreen' },
          csharp = { glyph = csharp_icon, hl = 'MiniIconsGreen' },
        },
        os = {
          git = { glyph = '' }, -- nf-oct-git_branch
        },
        extension = {
          template = { glyph = template_icon },
          go = { glyph = gopher_icon },
          yml = { glyph = yaml_icon },
          yaml = { glyph = yaml_icon },
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
        quickfix = { suffix = '' }, -- ]q/[q wrapped in custom.core.lists (empty-list notify + cursor-relative idx)
        location = { suffix = '' }, -- ]l/[l wrapped in custom.core.lists (empty-list notify + cursor-relative idx)
      }

      -- Redirect ]f/[f from neo-tree to the first normal editing window
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'neo-tree',
        callback = function(ev)
          for key, dir in pairs { [']f'] = 'forward', ['[f'] = 'backward' } do
            vim.keymap.set('n', key, function()
              for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == '' then
                  vim.api.nvim_set_current_win(win)
                  MiniBracketed.file(dir)
                  return
                end
              end
            end, { buffer = ev.buf })
          end
        end,
      })

      -- Split/join code constructs (gS to split, gJ to join)
      require('mini.splitjoin').setup()

      -- Simple and easy statusline
      local statusline = require 'mini.statusline'
      statusline.setup {
        use_icons = vim.g.have_nerd_font,
        content = {
          -- Mirrors the default active content plus a macro recording
          -- indicator. cmdheight=0 and ui2 swallow the native
          -- "recording @a" message, so surface the register here.
          active = function()
            local mode, mode_hl = statusline.section_mode { trunc_width = 120 }
            local macro = vim.fn.reg_recording()
            local git = statusline.section_git { trunc_width = 40 }
            local diff = statusline.section_diff { trunc_width = 75 }
            local diagnostics = statusline.section_diagnostics { trunc_width = 75 }
            local lsp = statusline.section_lsp { trunc_width = 75 }
            local filename = statusline.section_filename { trunc_width = 140 }
            local fileinfo = statusline.section_fileinfo { trunc_width = 120 }
            local location = statusline.section_location { trunc_width = 75 }
            local search = statusline.section_searchcount { trunc_width = 75 }

            return statusline.combine_groups {
              { hl = mode_hl, strings = { mode } },
              { hl = 'MiniStatuslineModeReplace', strings = { macro ~= '' and ('󰑊 @' .. macro) or '' } },
              { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diagnostics, lsp } },
              '%<',
              { hl = 'MiniStatuslineFilename', strings = { filename } },
              '%=',
              { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
              { hl = mode_hl, strings = { search, location } },
            }
          end,
        },
      }

      -- Redraw statusline on record start/stop so the indicator updates
      -- immediately rather than on the next unrelated event.
      vim.api.nvim_create_autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
        group = vim.api.nvim_create_augroup('mini-statusline-macro', { clear = true }),
        callback = function()
          vim.cmd.redrawstatus()
        end,
      })

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
