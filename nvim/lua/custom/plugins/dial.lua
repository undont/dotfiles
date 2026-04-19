-- Dial: increment/decrement engine + TailwindCSS class support.

return {
  {
    'monaqa/dial.nvim',
    keys = {
      {
        '<C-a>',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('increment', 'normal')
        end,
        desc = 'Increment',
      },
      {
        '<C-x>',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('decrement', 'normal')
        end,
        desc = 'Decrement',
      },
      {
        'g<C-a>',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('increment', 'gnormal')
        end,
        desc = 'Increment (sequential)',
      },
      {
        'g<C-x>',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('decrement', 'gnormal')
        end,
        desc = 'Decrement (sequential)',
      },
      {
        '<C-a>',
        mode = 'v',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('increment', 'visual')
        end,
        desc = 'Increment',
      },
      {
        '<C-x>',
        mode = 'v',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('decrement', 'visual')
        end,
        desc = 'Decrement',
      },
      {
        'g<C-a>',
        mode = 'v',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('increment', 'gvisual')
        end,
        desc = 'Increment (sequential)',
      },
      {
        'g<C-x>',
        mode = 'v',
        function()
          if not vim.bo.modifiable then
            return
          end
          require('dial.map').manipulate('decrement', 'gvisual')
        end,
        desc = 'Decrement (sequential)',
      },
    },
    config = function()
      local augend = require 'dial.augend'
      require('dial.config').augends:register_group {
        default = {
          augend.integer.alias.decimal,
          augend.integer.alias.hex,
          augend.constant.alias.bool,
          augend.date.alias['%Y-%m-%d'],
          augend.semver.alias.semver,
        },
      }
    end,
  },

  -- TailwindCSS dial: increment/decrement tailwind classes
  {
    'ruicsh/tailwindcss-dial.nvim',
    dependencies = { 'monaqa/dial.nvim' },
    ft = { 'html', 'css', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'astro', 'vue', 'svelte' },
    opts = {},
  },
}
