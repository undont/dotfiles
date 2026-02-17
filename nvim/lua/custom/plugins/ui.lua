-- UI plugins: which-key, statusline, todo-comments
-- Colourschemes are custom files in nvim/colors/ — no plugins needed

return {
  -- File explorer (neo-tree is imported from kickstart)
  -- See kickstart/plugins/neo-tree.lua

  -- Which-key for keybinding hints
  {
    'folke/which-key.nvim',
    lazy = false, -- Load immediately to ensure leader preview works reliably
    opts = {
      delay = 0, -- Show immediately for snappy feel
      icons = {
        mappings = vim.g.have_nerd_font,
      },
      spec = {
        { '<leader>c', group = '[C]laude', icon = { icon = ' ', color = 'green' } },
        { '<leader>d', group = '[D]iff', icon = { cat = 'filetype', name = 'git' } },
        { '<leader>h', group = 'Git [H]unk', icon = { cat = 'filetype', name = 'git' } },
        { '<leader>l', group = '[L]SP', icon = { icon = ' ', color = 'orange' } },
        { '<leader>m', group = '[M]arkdown', icon = { cat = 'filetype', name = 'markdown' } },
        { '<leader>n', group = '.[N]ET', icon = { cat = 'filetype', name = 'cs' } },
        { '<leader>p', group = '[P]R Review', icon = { cat = 'filetype', name = 'git' } },
        { '<leader>s', group = '[S]earch', icon = { icon = ' ', color = 'green' } },
        { '<leader>t', group = '[T]est / Toggle', icon = { cat = 'filetype', name = 'neotest-summary' } },
        { '<leader>w', group = '[W]indow', icon = { icon = ' ', color = 'blue' } },
        { '<leader>x', group = 'Diagnostics', icon = { icon = '󱖫 ', color = 'green' } },
        { 'gr', group = 'LSP [R]efactor', icon = { icon = ' ', color = 'cyan' } },
      },
    },
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

  -- Mini plugins (statusline, ai, surround)
  {
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      require('mini.surround').setup()

      -- Simple and easy statusline
      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }

      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- Truncate branch name to ticket ID (e.g. "feature/DANA-123-some-desc" -> "DANA-123")
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_git = function(args)
        if statusline.is_truncated(args.trunc_width) then
          return ''
        end
        local head = vim.b.gitsigns_head or ''
        if head == '' then
          return ''
        end
        -- Extract ticket ID pattern (e.g. DANA-123, JIRA-456)
        local ticket = head:match '[A-Z]+-[0-9]+'
        local branch = ticket or head
        local icon = vim.g.have_nerd_font and ' ' or 'Git:'
        return icon .. branch
      end
    end,
  },
}
