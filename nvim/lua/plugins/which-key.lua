-- which-key: the top level shows category groups; standalone keys and
-- filetype-specific groups are hidden unless the filetype matches

return {
  {
    'folke/which-key.nvim',
    lazy = false,
    config = function()
      local wk = require 'which-key'
      local claude_icon = vim.fn.nr2char(0xf06c4) -- nf-md-asterisk, matches the ```claude fence icon

      -- also used by the ```claude fence glyph in mini.lua
      vim.api.nvim_set_hl(0, 'ClaudeIcon', { fg = '#ff9e64' })
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('claude-icon-hl', { clear = true }),
        callback = function()
          vim.api.nvim_set_hl(0, 'ClaudeIcon', { fg = '#ff9e64' })
        end,
      })

      local dotnet_fts = { cs = true, fsharp = true, razor = true, xml = true }

      wk.setup {
        delay = 0,
        win = {
          no_overlap = false,
        },
        icons = {
          mappings = vim.g.have_nerd_font,
        },
        spec = {
          -- ── always-visible groups ──
          { '<leader>a', group = '[A]I', icon = { icon = '󰚩 ', color = 'purple' } },
          { '<leader>b', group = '[B]reakpoint / Buffer', icon = { icon = '󰈔 ', color = 'red' } },
          { '<leader>d', group = '[D]iff', icon = { cat = 'filetype', name = 'git' } },
          { '<leader>G', group = '[G]it (Fugitive)', icon = { cat = 'filetype', name = 'git' } },
          { '<leader>H', group = 'Git [H]unk', icon = { cat = 'filetype', name = 'git' } },
          { '<leader>h', group = '[H]arpoon', icon = { icon = '󱡀 ', color = 'blue' } },
          { '<leader>s', group = '[S]earch', icon = { icon = '', color = 'blue' } },
          { '<leader>S', group = '[S]pell', icon = { icon = '󰓆 ', color = 'yellow' } },
          { '<leader>t', group = '[T]est / Toggle', icon = { cat = 'filetype', name = 'neotest-summary' } },
          { '<leader>l', group = '[L]SP', icon = { icon = '', color = 'green' } },
          { '<leader>o', group = '[O]bsidian', icon = { icon = '󱞁 ', color = 'purple' } },
          { '<leader>w', group = '[W]indow', icon = { icon = '', color = 'red' } },

          -- ── always-visible (non-code contexts like differ) ──
          { '<leader>p', group = '[P]R Review', icon = { cat = 'filetype', name = 'git' } },

          -- ── always-visible (qf/loclist commands work in any buffer) ──
          { '<leader>x', group = 'Diagnostics', icon = { icon = '󱖫 ', color = 'green' } },

          -- ── filetype-gated groups (hidden by default, shown in code files via autocmd) ──
          { '<leader>k', group = 'Musi[K]', icon = { icon = '󰎆 ', color = 'purple' }, hidden = true },
          { '<leader>u', icon = { icon = '󰕌 ', color = 'blue' }, hidden = true },
          { 'gr', group = 'LSP [R]efactor', icon = { icon = '󰅩', color = 'green' }, hidden = true },

          -- ── filetype-gated groups (hidden by default, shown for specific filetypes via autocmd); <leader>N is always shown ──
          { '<leader>c', group = '[C]laude', icon = { icon = claude_icon, hl = 'ClaudeIcon' }, hidden = true },
          { '<leader>m', group = '[M]arkdown', icon = { cat = 'filetype', name = 'markdown' }, hidden = true },
          { '<leader>n', group = '.[N]ET', icon = { cat = 'filetype', name = 'cs' }, hidden = true },
          { '<leader>N', group = '[N]otifications', icon = { icon = '󰈸 ', color = 'yellow' } },

          -- ── always-hidden standalone keys (muscle memory) ──
          { '<leader>1', hidden = true },
          { '<leader>2', hidden = true },
          { '<leader>3', hidden = true },
          { '<leader>4', hidden = true },
          { '<leader>e', hidden = true },
          { '<leader>g', hidden = true },
          { '<leader>i', hidden = true },

          -- ── macOS-style navigation (core/macos-nav.lua), muscle memory, kept out of which-key ──
          { '<M-CR>', hidden = true },
          { '<M-BS>', hidden = true },
          { '<D-BS>', hidden = true },
          { '<M-Right>', hidden = true },
          { '<M-Left>', hidden = true },
          { '<M-f>', hidden = true },
          { '<M-b>', hidden = true },
          { '<Home>', hidden = true },
          { '<End>', hidden = true },

          { '<leader>?', icon = { icon = '', color = 'blue' } },
          { '<leader><leader>', icon = { icon = '', color = 'blue' } },
          { '<leader>z', icon = { icon = '', color = 'red' } },
          -- ── hidden, shown in code files via autocmd; <leader>Q stays hidden ──
          { '<leader>q', icon = { icon = '', color = 'green' }, hidden = true },
          { '<leader>Q', icon = { icon = '', color = 'green' }, hidden = true },
          { '<leader>f', hidden = true },
          { '<leader>bb', hidden = true },
          { '<leader>bc', hidden = true },
          { '<leader>bL', hidden = true },
          { '<leader>bl', hidden = true },
        },
      }

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

      -- each wk.add calls Buf.clear(), which removes every trigger keymap from
      -- every buffer, so wk.add only runs when visibility changes
      local prev_vis = {}

      local function update_filetype_groups()
        -- special buffers (differ, telescope, neo-tree) keep the previous state
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
          { 'gr', group = 'LSP [R]efactor', icon = { icon = '󰅩', color = 'green' }, hidden = not is_code },
          { '<leader>f', hidden = not is_code },
          { '<leader>k', group = 'Musi[K]', icon = { icon = '󰎆 ', color = 'purple' }, hidden = not is_code },
          { '<leader>u', icon = { icon = '󰕌 ', color = 'blue' }, hidden = not is_code },
          { '<leader>q', hidden = not is_code },
          { '<leader>bb', hidden = not is_code },
          { '<leader>bc', hidden = not is_code },
          { '<leader>bL', hidden = not is_code },
          { '<leader>bl', hidden = not is_code },

          { '<leader>c', group = '[C]laude', icon = { icon = claude_icon, hl = 'ClaudeIcon' }, hidden = not is_markdown },
          { '<leader>m', group = '[M]arkdown', icon = { cat = 'filetype', name = 'markdown' }, hidden = not is_markdown },

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
}
