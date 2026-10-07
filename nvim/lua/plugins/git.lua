-- lazygit, fugitive and rhubarb

return {
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
    -- lazygit runs in an in-process terminal float, so quitting it fires no
    -- event gitsigns hooks, and the statusline branch and diff counts go
    -- stale. the plugin calls vim.g.lazygit_on_exit_callback after the
    -- terminal exits. set in init so the global exists before the float closes
    init = function()
      vim.g.lazygit_on_exit_callback = function()
        local ok, gitsigns = pcall(require, 'gitsigns')
        if ok then
          gitsigns.refresh() -- fires GitSignsUpdate, which redraws the statusline
        end
      end
    end,
  },

  -- fugitive: `<leader>G*` is its group; `<leader>g` is lazygit
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
