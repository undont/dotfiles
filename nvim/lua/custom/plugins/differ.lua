-- differ.nvim: local diffs, file history, staging, pr review, merge conflicts,
-- all through one renderer with the same UX. owns the <leader>d* launchers
-- (replacing diffview, which keeps <leader>dT for diff-by-ticket) and the
-- <leader>p* pr launchers (replacing octo, which stays installed as a fallback,
-- reachable via :Octo). thread/comment actions are in-diff gestures bound by
-- differ itself in the pr diff: ga comment, gp reply, gr resolve, gx delete,
-- gc collapse, ]t/[t thread nav.
--
-- the build hook compiles the go sidecar (pr review) on install/update; it needs
-- go + make on PATH. local diffs work without it.

return {
  {
    'undont/differ.nvim',
    build = 'make go-build',
    cmd = 'Differ',
    keys = {
      { '<leader>do', '<cmd>Differ<CR>', desc = '[D]iff [O]pen (vs index)' },
      { '<leader>dc', '<cmd>Differ close<CR>', desc = '[D]iff [C]lose' },
      { '<leader>dt', '<cmd>Differ base<CR>', desc = '[D]iff branch [T]otal (vs base)' },
      { '<leader>de', '<cmd>Differ gofile<CR>', desc = '[D]iff [E]dit file' },
      { '<leader>dh', '<cmd>Differ log<CR>', desc = '[D]iff file [H]istory' },
      { '<leader>dp', '<cmd>Differ log origin/HEAD...HEAD<CR>', desc = '[D]iff [P]R review' },
      { '<leader>dl', '<cmd>Differ layout<CR>', desc = '[D]iff change [L]ayout' },
      -- pr review (sidecar). distinct from <leader>dp above, which is a local
      -- pr-range history diff with no github round trip
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
      require('differ').setup {
        command_alias = 'D',
      }
    end,
  },
}
