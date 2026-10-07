-- differ.nvim: local diffs, file history, staging, pr review and merge
-- conflicts. owns the <leader>d* and <leader>p* launchers; thread and comment
-- actions are in-diff gestures bound by differ itself. the build hook compiles
-- the go sidecar for pr review and needs go + make on PATH

-- true runs differ.nvim from the ~/code/differ.nvim checkout (restart nvim),
-- where pr features need `make go-build` run in the checkout. falls back to
-- the release when the checkout has no entry module
local DIFFER_DEV = true
local DIFFER_LOCAL = vim.fn.expand '~/code/differ.nvim'
local DIFFER_USE_DEV = DIFFER_DEV and vim.fn.filereadable(DIFFER_LOCAL .. '/lua/differ/init.lua') == 1

-- :D expands to :Differ, the lazy `cmd` trigger. a cmdline abbrev defined at
-- startup, not differ's command_alias, which only exists once the plugin has
-- loaded. the guard stops it expanding mid-line, e.g. in :s/D/x/
vim.cmd [[cnoreabbrev <expr> D (getcmdtype() == ':' && getcmdline() ==# 'D') ? 'Differ' : 'D']]

return {
  {
    'undont/differ.nvim',
    dir = DIFFER_USE_DEV and DIFFER_LOCAL or nil,
    build = 'make go-build',
    cmd = 'Differ',
    keys = {
      { '<leader>do', '<cmd>Differ<CR>', desc = '[D]iff [O]pen (vs index)' },
      { '<leader>dt', '<cmd>Differ base<CR>', desc = '[D]iff branch [T]otal (vs base)' },
      {
        '<leader>dT',
        function()
          -- commit discovery shared with <leader>xT / <leader>lT (features/ticket.lua)
          require('features.ticket').prompt_commits(function(ctx)
            local oldest, newest = ctx.commits[#ctx.commits], ctx.commits[1]
            if newest == ctx.head then
              -- the single-rev form diffs against the working tree
              vim.cmd(('Differ %s^'):format(oldest))
            else
              -- a working-tree diff would include the commits after the newest match
              vim.cmd(('Differ %s^..%s'):format(oldest, newest))
            end
          end)
        end,
        desc = '[D]iff branch by [T]icket',
      },
      { '<leader>dh', '<cmd>Differ log<CR>', desc = '[D]iff file [H]istory' },
      { '<leader>dp', '<cmd>Differ log origin/HEAD...HEAD<CR>', desc = '[D]iff [P]R review' },
      -- pr review through the sidecar; <leader>dp above is a local history diff
      { '<leader>pl', '<cmd>Differ pr list<CR>', desc = '[L]ist PRs' },
      {
        '<leader>po',
        function()
          vim.ui.input({ prompt = 'PR number: ' }, function(input)
            if input and input ~= '' then
              vim.cmd('Differ pr ' .. input)
            end
          end)
        end,
        desc = '[O]pen by number',
      },
      { '<leader>pr', '<cmd>Differ pr review<CR>', desc = '[R]eview start' },
      { '<leader>pe', '<cmd>Differ pr review resume<CR>', desc = 'Review r[E]sume' },
      { '<leader>pm', '<cmd>Differ pr review submit<CR>', desc = 'Review sub[M]it' },
      { '<leader>pd', '<cmd>Differ pr review discard<CR>', desc = 'Review [D]iscard' },
      { '<leader>psm', '<cmd>Differ pr merge squash<CR>', desc = '[S]quash [M]erge' },
      { '<leader>pk', '<cmd>Differ pr checks<CR>', desc = 'Chec[K]s' },
      { '<leader>pO', '<cmd>Differ pr checkout<CR>', desc = 'Check[O]ut' },
      { '<leader>pR', '<cmd>Differ pr ready<CR>', desc = 'Mark [R]eady' },
      { '<leader>pD', '<cmd>Differ pr draft<CR>', desc = 'Mark [D]raft' },
      { '<leader>pX', '<cmd>Differ pr close<CR>', desc = 'Close PR' },
      { '<leader>pb', '<cmd>Differ pr browser<CR>', desc = 'Open in [B]rowser' },
      { '<leader>py', '<cmd>Differ pr url<CR>', desc = '[Y]ank URL' },
      { '<leader>pq', '<cmd>Differ close<CR>', desc = '[Q]uit PR' },
    },
    config = function()
      -- vim.g.differ_opts is set in local.lua
      require('differ').setup(vim.g.differ_opts or {})
    end,
  },
}
