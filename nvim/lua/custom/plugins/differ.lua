-- differ.nvim: local diffs, file history, staging, pr review, merge conflicts,
-- all through one renderer with the same UX. owns the <leader>d* launchers
-- (replacing diffview, which keeps <leader>dT for diff-by-ticket) and the
-- <leader>p* pr launchers (replacing octo, which stays installed as a fallback,
-- reachable via :Octo). thread/comment actions are in-diff gestures bound by
-- differ itself in the pr diff: ga comment, gp reply, gr resolve, gx delete,
-- gc collapse, ]t/[t thread nav.

-- the build hook compiles the go sidecar (pr review) on install/update; it needs
-- go + make on PATH. local diffs work without it.

-- local-dev toggle: flip to true (and restart nvim) to run differ.nvim from the
-- ~/code/differ.nvim checkout instead of the installed release. lazy serves the
-- plugin's modules from `dir`, so this is the only place the swap actually takes
-- (an rtp prepend elsewhere loses to lazy's loader). the sidecar self-locates its
-- bin off its own lua file, so PR features then need `make go-build` run in the
-- checkout; local diffs/history/staging work without it. false = installed release.
--
-- the swap is guarded by a real checkout existing, so leaving this true in shared
-- dots stays safe: machines without ~/code/differ.nvim (or with a stale/empty one)
-- fall back to the release instead of pointing lazy at a dir with no modules
-- (which would break :Differ entirely). the guard checks the entry module rather
-- than just the dir so an empty or half-cloned checkout doesn't count as dev
local DIFFER_DEV = true
local DIFFER_LOCAL = vim.fn.expand '~/code/differ.nvim'
local DIFFER_USE_DEV = DIFFER_DEV and vim.fn.filereadable(DIFFER_LOCAL .. '/lua/differ/init.lua') == 1

-- :D as a cold-start alias for :Differ. a cmdline abbrev, not differ's
-- command_alias, so it expands before the plugin is loaded: `:D ...` rewrites to
-- `:Differ ...`, which is the lazy `cmd` trigger. defined here at startup (this
-- spec module is required when lazy builds its plugin list) rather than in the
-- plugin's config, which would only run after the load it's meant to trigger. the
-- getcmdtype/getcmdline guard keeps it from expanding mid-line, e.g. in :s/D/x/
vim.cmd [[cnoreabbrev <expr> D (getcmdtype() == ':' && getcmdline() ==# 'D') ? 'Differ' : 'D']]

return {
  {
    'undont/differ.nvim',
    dir = DIFFER_USE_DEV and DIFFER_LOCAL or nil,
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
      -- :D alias is a cmdline abbrev defined at startup above, not command_alias,
      -- so it survives a cold start before this config runs
      require('differ').setup {}
    end,
  },
}
