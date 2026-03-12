-- GitHub Copilot configuration

return {
  {
    'github/copilot.vim',
    init = function()
      -- Disable default Tab mapping — handled by blink.cmp's smart Tab
      vim.g.copilot_no_tab_map = true
    end,
    config = function()
      -- Disable Copilot for sensitive files
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufNew' }, {
        pattern = {
          '.env*',
          '*.env',
          '*secret*',
          '*credential*',
          '*.key',
          '*.pem',
          '*.secrets.zsh',
        },
        callback = function()
          vim.b.copilot_enabled = false
        end,
      })

      -- Set Copilot suggestion highlight for non-generated colourschemes
      -- Generated themes set CopilotSuggestion directly; this is a fallback
      local function set_copilot_hl()
        -- Skip if the colourscheme already defined CopilotSuggestion (generated themes)
        local existing = vim.api.nvim_get_hl(0, { name = 'CopilotSuggestion' })
        if existing.fg then
          return
        end

        -- Blend Comment fg towards Normal bg for a ghost-text effect
        local comment_hl = vim.api.nvim_get_hl(0, { name = 'Comment' })
        local normal_hl = vim.api.nvim_get_hl(0, { name = 'Normal' })
        local cfg = comment_hl.fg or 0x5c6370
        local nbg = normal_hl.bg or 0x1e1e2e

        -- Blend 40% towards background
        local function blend(fg_c, bg_c, ratio)
          local function ch(hex, shift)
            return bit.band(bit.rshift(hex, shift), 0xff)
          end
          local r = ch(fg_c, 16) + (ch(bg_c, 16) - ch(fg_c, 16)) * ratio
          local g = ch(fg_c, 8) + (ch(bg_c, 8) - ch(fg_c, 8)) * ratio
          local b = ch(fg_c, 0) + (ch(bg_c, 0) - ch(fg_c, 0)) * ratio
          return bit.bor(bit.lshift(math.floor(r), 16), bit.lshift(math.floor(g), 8), math.floor(b))
        end

        vim.api.nvim_set_hl(0, 'CopilotSuggestion', {
          fg = blend(cfg, nbg, 0.40),
          italic = true,
        })
      end

      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('CopilotHighlights', { clear = true }),
        callback = function()
          vim.defer_fn(set_copilot_hl, 10)
        end,
      })

      vim.api.nvim_create_autocmd('VimEnter', {
        group = 'CopilotHighlights',
        callback = function()
          vim.defer_fn(set_copilot_hl, 100)
        end,
      })

      vim.api.nvim_create_user_command('CopilotHighlightFix', set_copilot_hl, {
        desc = 'Fix Copilot suggestion highlighting',
      })
    end,
  },
}
