-- treesitter-textobjects: select, move and swap by syntax node

return {
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    event = 'VeryLazy',
    config = function()
      local ts_select = require 'nvim-treesitter-textobjects.select'
      local ts_move = require 'nvim-treesitter-textobjects.move'
      local ts_swap = require 'nvim-treesitter-textobjects.swap'

      require('nvim-treesitter-textobjects').setup {
        select = { lookahead = true },
        move = { set_jumps = true },
      }

      local select_maps = {
        { 'am', '@function.outer', 'Around method/function' },
        { 'im', '@function.inner', 'Inside method/function' },
        { 'aC', '@class.outer', 'Around class' },
        { 'iC', '@class.inner', 'Inside class' },
      }
      for _, map in ipairs(select_maps) do
        vim.keymap.set({ 'x', 'o' }, map[1], function()
          ts_select.select_textobject(map[2])
        end, { desc = map[3] })
      end

      vim.keymap.set({ 'n', 'x', 'o' }, ']m', function()
        ts_move.goto_next_start '@function.outer'
      end, { desc = 'Next function start' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[m', function()
        ts_move.goto_previous_start '@function.outer'
      end, { desc = 'Previous function start' })
      vim.keymap.set({ 'n', 'x', 'o' }, ']M', function()
        ts_move.goto_next_end '@function.outer'
      end, { desc = 'Next function end' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[M', function()
        ts_move.goto_previous_end '@function.outer'
      end, { desc = 'Previous function end' })

      local function with_parser(fn)
        return function()
          local ok, parser = pcall(vim.treesitter.get_parser)
          if not ok or not parser then
            vim.notify('No treesitter parser for this buffer', vim.log.levels.WARN)
            return
          end
          fn()
        end
      end
      vim.keymap.set(
        'n',
        '>p',
        with_parser(function()
          ts_swap.swap_next '@parameter.inner'
        end),
        { desc = 'Swap parameter right' }
      )
      vim.keymap.set(
        'n',
        '<p',
        with_parser(function()
          ts_swap.swap_previous '@parameter.inner'
        end),
        { desc = 'Swap parameter left' }
      )
    end,
  },
}
