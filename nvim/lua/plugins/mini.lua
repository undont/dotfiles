-- mini.nvim modules: icons, surround, pairs, hipatterns, bracketed,
-- splitjoin, statusline. loaded eagerly: the dashboard uses the mini.icons glyphs

return {
  {
    'echasnovski/mini.nvim',
    lazy = false,
    config = function()
      local template_icon = vim.fn.nr2char(0xf05c0) -- nf-md-file_code_outline
      local gopher_icon = vim.fn.nr2char(0xe627) -- nf-seti-go (gopher)
      local yaml_icon = vim.fn.nr2char(0xf013) -- nf-fa-cog
      local csharp_icon = vim.fn.nr2char(0xf031b) -- nf-md-language_csharp (matches `cs` extension)
      local shell_icon = vim.fn.nr2char(0xe691) -- nf-seti-shell (matches mini's `sh` filetype glyph)
      local claude_icon = vim.fn.nr2char(0xf06c4) -- nf-md-asterisk (anthropic-style sunburst)
      local me_icon = vim.fn.nr2char(0xf007) -- nf-fa-user

      -- icons without an explicit hl take the nvim-web-devicons brand colour
      -- instead of mini's theme-derived one. devicons reapplies its DevIcon*
      -- groups on ColorScheme
      local devicons = require 'nvim-web-devicons'
      local brand_lookup = {
        filetype = function(name)
          local _, hl = devicons.get_icon_by_filetype(name)
          return hl
        end,
        extension = function(name)
          local _, hl = devicons.get_icon('', name)
          return hl
        end,
        file = function(name)
          local _, hl = devicons.get_icon(name)
          return hl
        end,
      }
      local function with_brand_hl(category, entries)
        local names = require('mini.icons').list(category)
        vim.list_extend(names, vim.tbl_keys(entries))
        for _, name in ipairs(names) do
          local entry = entries[name] or {}
          local hl = entry.hl == nil and brand_lookup[category](name) or nil
          if hl ~= nil then
            entry.hl = hl
            entries[name] = entry
          end
        end
        return entries
      end

      require('mini.icons').setup {
        filetype = with_brand_hl('filetype', {
          yaml = { glyph = yaml_icon },
          template = { glyph = template_icon },
          go = { glyph = gopher_icon },
          -- render-markdown looks up code-block languages as filetypes
          cs = { glyph = csharp_icon },
          csharp = { glyph = csharp_icon, hl = brand_lookup.filetype 'cs' },
          -- transcript speaker fences (```claude / ```me) in vault notes.
          -- render-markdown resolves the fence word through vim.filetype.match,
          -- where 'me' is nroff, so the `me` glyph is set on nroff
          claude = { glyph = claude_icon, hl = 'ClaudeIcon' }, -- ClaudeIcon defined in plugins/which-key.lua
          nroff = { glyph = me_icon, hl = 'MiniIconsBlue' },
        }),
        os = {
          git = { glyph = '' }, -- nf-oct-git_branch
        },
        extension = with_brand_hl('extension', {
          template = { glyph = template_icon },
          go = { glyph = gopher_icon },
          yml = { glyph = yaml_icon },
          yaml = { glyph = yaml_icon },
          -- mini.icons resolves sh/bash/zsh through vim.filetype.match(), which
          -- returns nil for them during the dashboard's first paint, and caches
          -- the generic glyph for the session
          sh = { glyph = shell_icon },
          bash = { glyph = shell_icon },
          zsh = { glyph = shell_icon },
        }),
        file = with_brand_hl('file', {}),
      }

      -- 'gs' prefix: an 's' prefix delays the native 's'
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

      require('mini.pairs').setup()

      require('mini.hipatterns').setup {
        highlighters = {
          hex_color = require('mini.hipatterns').gen_highlighter.hex_color(),
        },
      }

      -- an empty suffix disables the pair
      require('mini.bracketed').setup {
        comment = { suffix = '' }, -- ]c/[c is gitsigns
        diagnostic = { suffix = '' }, -- ]d/[d is features.lists
        file = { suffix = 'f' }, -- differ overrides ]f/[f when open; features/dated-notes shadows it on dated notes
        treesitter = { suffix = '' }, -- ]t/[t is failed tests (features.lists)
        quickfix = { suffix = '' }, -- ]q/[q is features.lists
        location = { suffix = '' }, -- ]l/[l is features.lists
      }

      -- ]f/[f walk DD-MM-YYYY note directories by date rather than lexically
      require('features.dated-notes').setup_bracketed()

      -- redirect ]f/[f from neo-tree to the first normal editing window
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

      local splitjoin = require 'mini.splitjoin'
      splitjoin.setup()

      -- go requires a trailing comma before a newline, and ruff and zig fmt keep
      -- a list one item per line while it ends in one, so split adds it and join drops it
      local trailing_comma = {
        split = { hooks_post = { splitjoin.gen_hook.add_trailing_separator() } },
        join = { hooks_post = { splitjoin.gen_hook.del_trailing_separator() } },
      }
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'go', 'python', 'zig' },
        callback = function(ev)
          vim.b[ev.buf].minisplitjoin_config = trailing_comma
        end,
      })

      require('features.statusline').setup()
    end,
  },
}
