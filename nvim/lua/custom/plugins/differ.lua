-- differ.nvim: local diffs, file history, staging, pr review, merge conflicts,
-- all through one renderer with the same UX. owns every <leader>d* launcher,
-- including dT (diff by ticket, reusing features/ticket.lua's commit discovery;
-- differ's own revspec grammar covers both shapes it needs, so no plugin-side
-- change was required), and the <leader>p* pr launchers (replacing octo, which
-- stays installed as a fallback, reachable via :Octo). thread/comment actions
-- are in-diff gestures bound by differ itself in the pr diff: ga comment,
-- gp reply, gr resolve, gx delete, gc collapse, ]t/[t thread nav.

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
      {
        '<leader>dT',
        function()
          -- commit discovery shared with <leader>xT / <leader>lT (features/ticket.lua).
          -- both revspecs below are native :Differ grammar (rev vs worktree, two-dot
          -- range), so no differ-side support was needed for this
          require('custom.features.ticket').prompt_commits(function(ctx)
            local oldest, newest = ctx.commits[#ctx.commits], ctx.commits[1]
            if newest == ctx.head then
              -- single-rev form diffs against the working tree, so uncommitted
              -- and untracked changes are included
              vim.cmd(('Differ %s^'):format(oldest))
            else
              -- commits exist after the newest match; a working-tree diff would
              -- include them, so stick to the fixed range
              vim.cmd(('Differ %s^..%s'):format(oldest, newest))
            end
          end)
        end,
        desc = '[D]iff branch by [T]icket',
      },
      { '<leader>de', '<cmd>Differ gofile<CR>', desc = '[D]iff [E]dit file' },
      { '<leader>dd', '<cmd>Differ panel<CR>', desc = '[D]iff panel toggle' },
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
      -- includes differ_opts for local overrides via local.lua in nvim config
      require('differ').setup(vim.g.differ_opts or {})

      -- pin a permanent <Space>/]/[ to which-key on differ buffers. which-key's
      -- auto-trigger system has suspension windows (ModeChanged, BufNew) where the
      -- trigger keymap is absent, and each wk.add calls Buf.clear() which drops all
      -- triggers globally. a .cs diff makes it reliable: the roslyn/dotnet open churn
      -- (User RealDotnetFile, semantic token refresh, scan_files buffer create/delete)
      -- fires the very events that hit the suspension windows. every differ buffer is
      -- named differ://, so key off the name; a plain buffer-local map isn't managed
      -- by the trigger system, so it survives
      vim.api.nvim_create_autocmd('BufWinEnter', {
        group = vim.api.nvim_create_augroup('differ-whichkey', { clear = true }),
        callback = function(ev)
          if not vim.api.nvim_buf_get_name(ev.buf):match '^differ://' then
            return
          end
          local wk = require 'which-key'
          for _, key in ipairs { ' ', ']', '[' } do
            vim.keymap.set('n', key, function()
              wk.show(key)
            end, { buffer = ev.buf })
          end
        end,
      })
    end,
  },
}
