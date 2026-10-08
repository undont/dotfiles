-- neo-tree: file tree sidebar

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '|', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    popup_border_style = 'rounded',
    window = {
      mappings = {
        ['o'] = 'open',
        -- the order_by prefix is on O, so o opens without the prefix timeout
        ['oc'] = 'none',
        ['od'] = 'none',
        ['og'] = 'none',
        ['om'] = 'none',
        ['on'] = 'none',
        ['os'] = 'none',
        ['ot'] = 'none',
        ['O'] = { 'show_help', nowait = false, config = { title = 'Order by', prefix_key = 'O' } },
        ['Oc'] = { 'order_by_created', nowait = false },
        ['Od'] = { 'order_by_diagnostics', nowait = false },
        ['Og'] = { 'order_by_git_status', nowait = false },
        ['Om'] = { 'order_by_modified', nowait = false },
        ['On'] = { 'order_by_name', nowait = false },
        ['Os'] = { 'order_by_size', nowait = false },
        ['Ot'] = { 'order_by_type', nowait = false },
        ['<C-j>'] = function(state)
          vim.api.nvim_feedkeys('j', 'n', false)
        end,
        ['<C-k>'] = function(state)
          vim.api.nvim_feedkeys('k', 'n', false)
        end,
      },
    },
    filesystem = {
      -- oil.nvim owns directory buffers (`nvim <dir>`)
      hijack_netrw_behavior = 'disabled',
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
        never_show = { '.DS_Store' },
      },
      window = {
        mappings = {
          ['|'] = 'close_window',
        },
        fuzzy_finder_mappings = {
          ['<C-j>'] = 'move_cursor_down',
          ['<C-k>'] = 'move_cursor_up',
        },
      },
    },
  },
  config = function(_, opts)
    require('neo-tree').setup(opts)
    require('features.neo-tree-git-patch').apply()
  end,
}
