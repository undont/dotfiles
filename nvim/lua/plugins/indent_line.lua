return {
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {
      indent = { tab_char = '▎' },
    },
    config = function(_, opts)
      local hooks = require 'ibl.hooks'

      -- scope guides are a brightened Whitespace fg
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        local hl = vim.api.nvim_get_hl(0, { name = 'Whitespace' })
        if hl.fg then
          local hex = string.format('%06x', hl.fg)
          local r = math.min(255, math.floor(tonumber(hex:sub(1, 2), 16) * 1.5))
          local g = math.min(255, math.floor(tonumber(hex:sub(3, 4), 16) * 1.5))
          local b = math.min(255, math.floor(tonumber(hex:sub(5, 6), 16) * 1.5))
          vim.api.nvim_set_hl(0, 'IblScope', { fg = string.format('#%02x%02x%02x', r, g, b) })
        end
      end)

      require('ibl').setup(opts)
    end,
  },
}
