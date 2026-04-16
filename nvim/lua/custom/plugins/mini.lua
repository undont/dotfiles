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
      require('mini.icons').setup {
        filetype = {
          yaml = { glyph = yaml_icon },
          template = { glyph = template_icon },
          go = { glyph = gopher_icon },
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
