-- lazygit: lazygit in a terminal float

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
}
