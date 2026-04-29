-- Git-related plugins

return {
  -- LazyGit integration
  {
    'kdheepak/lazygit.nvim',
    lazy = true,
    cmd = {
      'LazyGit',
      'LazyGitConfig',
      'LazyGitCurrentFile',
      'LazyGitFilter',
      'LazyGitFilterCurrentFile',
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
  },

  -- Fugitive: in-buffer git (`:Git`, `:Git blame`, `:Gdiffsplit`, stage hunks, etc.)
  -- Complements LazyGit (TUI workflow) with buffer-native operations.
  -- `<leader>g` (lower) stays the LazyGit leaf-shortcut; `<leader>G*` (capital)
  -- is the fugitive group, mirroring `<leader>H*` for gitsigns hunks.
  {
    'tpope/vim-fugitive',
    cmd = {
      'G',
      'Git',
      'Gdiffsplit',
      'Gvdiffsplit',
      'Gread',
      'Gwrite',
      'Ggrep',
      'GMove',
      'GRename',
      'GDelete',
      'GRemove',
      'GBrowse',
      'Gclog',
      'Gllog',
      'Gcd',
      'Glcd',
    },
    keys = {
      { '<leader>Gs', '<cmd>Git<CR>', desc = '[S]tatus (g? for help)' },
      { '<leader>Gb', '<cmd>Git blame<CR>', desc = '[B]lame' },
      { '<leader>Gd', '<cmd>Gdiffsplit<CR>', desc = '[D]iff against index' },
      { '<leader>Gl', '<cmd>0Gclog<CR>', desc = 'File [L]og → qf' },
      { '<leader>Gw', '<cmd>Gwrite<CR>', desc = '[W]rite (stage buffer)' },
      -- GBrowse: normal opens current line, visual opens selected range.
      -- Visual mapping uses `:` (not `<cmd>`) so vim prepends `'<,'>` for the range.
      { '<leader>Go', '<cmd>GBrowse<CR>', desc = '[O]pen on GitHub' },
      { '<leader>Go', ':GBrowse<CR>', mode = 'v', desc = '[O]pen on GitHub (range)' },
    },
    dependencies = {
      -- Rhubarb: `:GBrowse` handler for GitHub URLs (open file/line/commit on github.com)
      'tpope/vim-rhubarb',
    },
  },
}
