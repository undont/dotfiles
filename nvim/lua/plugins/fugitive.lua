-- fugitive and rhubarb: `<leader>G*` is its group

return {
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
      -- the visual mapping uses `:`, not `<cmd>`, so vim prepends `'<,'>`
      { '<leader>Go', '<cmd>GBrowse<CR>', desc = '[O]pen on GitHub' },
      { '<leader>Go', ':GBrowse<CR>', mode = 'v', desc = '[O]pen on GitHub (range)' },
    },
    dependencies = {
      -- rhubarb: the `:GBrowse` handler for GitHub URLs
      'tpope/vim-rhubarb',
    },
  },
}
