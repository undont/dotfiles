-- git-related plugins

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
    -- lazygit runs in an in-process terminal float, so quitting it fires no
    -- FocusGained/shell event for gitsigns to hook. without a nudge, the
    -- statusline branch (gitsigns_head) and diff counts (gitsigns_status_dict)
    -- stay stale after a commit/stage/checkout done inside lazygit. the plugin
    -- calls vim.g.lazygit_on_exit_callback after the terminal exits (and after
    -- its own :checktime), so re-run gitsigns there to re-diff every buffer.
    -- set in init (startup) so the global exists before the float can close
    init = function()
      vim.g.lazygit_on_exit_callback = function()
        local ok, gitsigns = pcall(require, 'gitsigns')
        if ok then
          gitsigns.refresh() -- async; fires GitSignsUpdate which redraws the statusline
        end
      end
    end,
  },

  -- Fugitive: in-buffer git (`:Git`, `:Git blame`, `:Gdiffsplit`, stage hunks, etc.)
  -- complements LazyGit (TUI workflow) with buffer-native operations.
  -- `<leader>g` (lower) stays the LazyGit leaf-shortcut; `<leader>G*` (capital)
  -- is the fugitive group, mirroring `<leader>H*` for gitsigns hunks
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
      -- visual mapping uses `:` (not `<cmd>`) so vim prepends `'<,'>` for the range
      { '<leader>Go', '<cmd>GBrowse<CR>', desc = '[O]pen on GitHub' },
      { '<leader>Go', ':GBrowse<CR>', mode = 'v', desc = '[O]pen on GitHub (range)' },
    },
    dependencies = {
      -- Rhubarb: `:GBrowse` handler for GitHub URLs (open file/line/commit on github.com)
      'tpope/vim-rhubarb',
    },
  },
}
