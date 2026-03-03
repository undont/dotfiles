-- Completion configuration (blink.cmp)

return {
  {
    'saghen/blink.cmp',
    dependencies = {
      'rafamadriz/friendly-snippets',
      { 'saghen/blink.compat', opts = {} },
      {
        'L3MON4D3/LuaSnip',
        version = 'v2.*',
        build = 'make install_jsregexp',
        dependencies = { 'rafamadriz/friendly-snippets' },
        config = function()
          require('luasnip.loaders.from_lua').load { paths = '~/.config/nvim/snippets/' }
        end,
      },
    },
    version = '*',
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset = 'default',
        ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
        ['<C-e>'] = { 'hide', 'fallback' },
        ['<CR>'] = { 'accept', 'fallback' },
        ['<Tab>'] = { 'snippet_forward', 'fallback' },
        ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
        ['<Up>'] = { 'select_prev', 'fallback' },
        ['<Down>'] = { 'select_next', 'fallback' },
        ['<C-p>'] = { 'select_prev', 'fallback' },
        ['<C-n>'] = { 'select_next', 'fallback' },
        ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
        ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
      },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = 'mono',
      },
      completion = {
        accept = { auto_brackets = { enabled = true } },
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        list = {
          selection = { preselect = true, auto_insert = true },
        },
        menu = {
          draw = {
            columns = { { 'kind_icon' }, { 'label', 'label_description', gap = 1 }, { 'source_name' } },
          },
        },
      },
      fuzzy = {
        sorts = {
          'exact',
          'score',
          'sort_text',
          'kind',
          'label',
        },
      },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
        providers = {
          snippets = { score_offset = -3 },
          buffer = { score_offset = -5 },
        },
      },
    },
    opts_extend = { 'sources.default' },
  },
}
