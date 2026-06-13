-- PR review plugins: diffview, octo

local diff_edit = require 'custom.features.diff-edit'
local octo_cache = require 'custom.features.octo-review-cache'

return {
  -- Diffview: side-by-side diffs and file history
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles' },
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      {
        '<leader>do',
        function()
          -- Phase tracer: enable via `:lua vim.g.do_perf = true`, run
          -- `<leader>do` once, paste output. Off by default; near-zero overhead.
          local t0 = vim.g.do_perf and vim.uv.hrtime() or nil
          local segs = {}
          local function mark(label)
            if t0 then
              table.insert(segs, string.format('%s=%.0fms', label, (vim.uv.hrtime() - t0) / 1e6))
            end
          end

          local current_file = vim.fn.expand '%:p'
          local current_line = vim.fn.line '.'
          local has_file = current_file ~= '' and vim.bo.buftype == ''
          mark 'preamble'

          -- After diffview opens, restore cursor line if the same file is shown
          if has_file and current_line > 1 then
            vim.api.nvim_create_autocmd('User', {
              pattern = 'DiffviewViewOpened',
              once = true,
              callback = function()
                local view = require('diffview.lib').get_current_view()
                if not view then
                  return
                end
                view.emitter:once('file_open_post', function(_, new_entry)
                  if new_entry and new_entry.absolute_path == current_file then
                    vim.schedule(function()
                      if view.cur_layout then
                        local win = view.cur_layout:get_main_win()
                        if win and win.id and vim.api.nvim_win_is_valid(win.id) then
                          pcall(vim.api.nvim_win_set_cursor, win.id, { current_line, 0 })
                        end
                      end
                    end)
                  end
                end)
              end,
            })
          end
          mark 'cursor_hook'

          diff_edit.diffview_open 'DiffviewOpen'
          mark 'diffview_open'

          if t0 then
            vim.notify('[do-perf] ' .. table.concat(segs, ' '), vim.log.levels.INFO)
          end
        end,
        desc = '[D]iff [O]pen (vs index)',
      },
      {
        '<leader>dc',
        function()
          vim.cmd 'DiffviewClose'
        end,
        desc = '[D]iff [C]lose',
      },
      {
        '<leader>dt',
        function()
          local base = vim.fn.systemlist('git merge-base main HEAD')[1]

          if not base or base == '' then
            vim.notify('Could not find merge-base with main', vim.log.levels.WARN)
            return
          end

          -- Single-rev form diffs the merge-base against the working tree, so
          -- both branch commits and uncommitted/unstaged changes are included.
          diff_edit.diffview_open('DiffviewOpen ' .. base)
        end,
        desc = '[D]iff branch [T]otal (vs main)',
      },
      {
        '<leader>dT',
        function()
          -- Commit discovery shared with <leader>xT / <leader>lT (core/ticket.lua)
          require('custom.features.ticket').prompt_commits(function(ctx)
            local oldest, newest = ctx.commits[#ctx.commits], ctx.commits[1]
            if newest == ctx.head then
              -- Single-rev form diffs against the working tree, so
              -- uncommitted changes are included in the review.
              diff_edit.diffview_open(string.format('DiffviewOpen %s^', oldest))
            else
              -- Commits exist after the newest match; a working-tree diff
              -- would include them, so stick to the fixed range.
              diff_edit.diffview_open(string.format('DiffviewOpen %s^...%s', oldest, newest))
            end
          end)
        end,
        desc = '[D]iff branch by [T]icket',
      },
      { '<leader>de', diff_edit.edit_diff_file, desc = '[D]iff [E]dit file' },
      {
        '<leader>dh',
        function()
          local file = vim.fn.expand '%'
          if file ~= '' and vim.fn.filereadable(file) == 1 then
            diff_edit.diffview_open 'DiffviewFileHistory %'
          else
            diff_edit.diffview_open 'DiffviewFileHistory'
          end
        end,
        desc = '[D]iff file [H]istory',
      },
      {
        '<leader>dp',
        function()
          diff_edit.diffview_open 'DiffviewFileHistory --range=origin/HEAD...HEAD --right-only --no-merges'
        end,
        desc = '[D]iff [P]R review',
      },
    },
    config = function(_, opts)
      require('diffview').setup(opts)

      -- Pin a permanent <Space> → which-key keymap on diffview buffers.
      -- Which-key's trigger system has brief suspension windows (ModeChanged,
      -- BufNew) where the <Space> trigger is absent. A regular buffer-local
      -- keymap isn't managed by the trigger system and can't be removed.
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'DiffviewFiles', 'DiffviewFileHistory', 'DiffviewBlob' },
        callback = function(ev)
          vim.keymap.set('n', ' ', function()
            require('which-key').show ' '
          end, { buffer = ev.buf })
          vim.keymap.set('n', '<leader>u', '<Nop>', { buffer = ev.buf })
          -- Allow diff commands to work from any diff buffer
          vim.keymap.set('n', '<leader>dc', function()
            vim.cmd 'DiffviewClose'
          end, { buffer = ev.buf, desc = '[D]iff [C]lose' })
          vim.keymap.set('n', '<leader>de', diff_edit.edit_diff_file, { buffer = ev.buf, desc = '[D]iff [E]dit file' })
        end,
      })

      -- Patch diffview upstream bugs (nil guards for async race conditions)
      -- See: https://github.com/sindrets/diffview.nvim/issues/550
      local api = vim.api

      -- Patch init_layout: curwin may already be closed after layout:create()
      local SV = require('diffview.scene.views.standard.standard_view').StandardView
      SV.init_layout = function(self)
        local first_init = not vim.t[self.tabpage].diffview_view_initialized
        local curwin = api.nvim_get_current_win()

        self:use_layout(SV.get_temp_layout())
        self.cur_layout:create()
        vim.t[self.tabpage].diffview_view_initialized = true

        if first_init and api.nvim_win_is_valid(curwin) then
          api.nvim_win_close(curwin, false)
        end

        self.panel:focus()
        self.emitter:emit 'post_layout'
      end

      local Layout = require('diffview.scene.layout').Layout
      Layout.sync_scroll = function(self)
        local curwin = api.nvim_get_current_win()
        local target, max = nil, 0

        for _, win in ipairs(self.windows) do
          if win.id and api.nvim_win_is_valid(win.id) then
            local lcount = api.nvim_buf_line_count(api.nvim_win_get_buf(win.id))
            if lcount > max then
              target, max = win, lcount
            end
          end
        end

        if not target then
          return
        end

        local main_win = self:get_main_win()
        if not main_win or not api.nvim_win_is_valid(main_win.id) then
          return
        end
        local cursor = api.nvim_win_get_cursor(main_win.id)

        for _, win in ipairs(self.windows) do
          if api.nvim_win_is_valid(win.id) then
            api.nvim_win_call(win.id, function()
              if win == target then
                vim.cmd('norm! ' .. api.nvim_replace_termcodes('<c-e><c-y>', true, true, true))
              end
              if win.id ~= curwin then
                api.nvim_exec_autocmds('WinLeave', { modeline = false })
              end
            end)
          end
        end

        if api.nvim_win_is_valid(target.id) then
          api.nvim_win_set_cursor(target.id, cursor)
        end
      end
    end,
    opts = function()
      local actions = require 'diffview.actions'
      local function safe_compat_fold(fold_cmd)
        return function()
          local normalized = ({
            zr = 'zR',
            zc = 'zC',
            zm = 'zM',
          })[fold_cmd] or fold_cmd

          local function run_in_win(winid)
            local ok, msg = pcall(vim.api.nvim_win_call, winid, function()
              vim.cmd('norm! ' .. normalized)
            end)
            if ok then
              return nil
            end
            if type(msg) == 'string' and msg:match 'E490: No fold found' then
              return nil
            end
            return msg
          end

          if vim.wo.foldmethod ~= 'manual' then
            local err = run_in_win(vim.api.nvim_get_current_win())
            if err then
              vim.api.nvim_echo({ { tostring(err), 'ErrorMsg' } }, true, { err = true })
            end
            return
          end

          local view = require('diffview.lib').get_current_view()
          local sv_ok, StandardView = pcall(require, 'diffview.scene.views.standard.standard_view')
          if not (view and sv_ok and view:instanceof(StandardView.StandardView.__get())) then
            local err = run_in_win(vim.api.nvim_get_current_win())
            if err then
              vim.api.nvim_echo({ { tostring(err), 'ErrorMsg' } }, true, { err = true })
            end
            return
          end

          local err
          for _, win in ipairs(view.cur_layout.windows) do
            local win_err = run_in_win(win.id)
            if win_err then
              err = win_err
            end
          end
          if err then
            vim.api.nvim_echo({ { tostring(err), 'ErrorMsg' } }, true, { err = true })
          end
        end
      end
      return {
        enhanced_diff_hl = true,
        hooks = {
          diff_buf_read = function(bufnr)
            vim.keymap.set('n', '<leader>u', '<Nop>', { buffer = bufnr })
            for _, fold_cmd in ipairs {
              'za',
              'zA',
              'ze',
              'zE',
              'zo',
              'zc',
              'zO',
              'zC',
              'zr',
              'zm',
              'zR',
              'zM',
              'zv',
              'zx',
              'zX',
              'zn',
              'zN',
              'zi',
            } do
              vim.keymap.set('n', fold_cmd, safe_compat_fold(fold_cmd), {
                buffer = bufnr,
                desc = 'diffview_ignore',
                nowait = true,
                silent = true,
              })
            end
          end,
        },
        view = {
          default = { layout = 'diff2_horizontal' },
          merge_tool = { layout = 'diff3_mixed' },
        },
        file_panel = {
          win_config = {
            position = 'bottom',
            height = 10,
          },
        },
        keymaps = {
          view = {
            { 'n', ']f', actions.select_next_entry, { desc = 'Next changed file' } },
            { 'n', '[f', actions.select_prev_entry, { desc = 'Previous changed file' } },
            { 'n', 'f', actions.scroll_view(0.25), { desc = 'Scroll the view down' } },
            { 'n', 'b', actions.scroll_view(-0.25), { desc = 'Scroll the view up' } },
            -- Disable <leader> defaults — they steal the prefix from which-key
            { 'n', '<leader>e', false },
            { 'n', '<leader>b', false },
            { 'n', '<leader>co', false },
            { 'n', '<leader>ct', false },
            { 'n', '<leader>cb', false },
            { 'n', '<leader>ca', false },
            { 'n', '<leader>cO', false },
            { 'n', '<leader>cT', false },
            { 'n', '<leader>cB', false },
            { 'n', '<leader>cA', false },
          },
          file_panel = {
            { 'n', ']f', actions.select_next_entry, { desc = 'Next changed file' } },
            { 'n', '[f', actions.select_prev_entry, { desc = 'Previous changed file' } },
            { 'n', 'f', actions.scroll_view(0.25), { desc = 'Scroll the view down' } },
            { 'n', 'b', actions.scroll_view(-0.25), { desc = 'Scroll the view up' } },
            { 'n', '<leader>e', false },
            { 'n', '<leader>b', false },
            { 'n', '<leader>cO', false },
            { 'n', '<leader>cT', false },
            { 'n', '<leader>cB', false },
            { 'n', '<leader>cA', false },
          },
          file_history_panel = {
            { 'n', ']f', actions.select_next_entry, { desc = 'Next changed file' } },
            { 'n', '[f', actions.select_prev_entry, { desc = 'Previous changed file' } },
            { 'n', 'f', actions.scroll_view(0.25), { desc = 'Scroll the view down' } },
            { 'n', 'b', actions.scroll_view(-0.25), { desc = 'Scroll the view up' } },
            { 'n', '<leader>e', false },
            { 'n', '<leader>b', false },
          },
        },
      }
    end,
  },

  -- Octo: GitHub PR review from within Neovim
  {
    'pwntester/octo.nvim',
    cmd = { 'Octo', 'OctoCacheClear' },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    keys = {
      { '<leader>pl', '<cmd>Octo pr list<CR>', desc = '[L]ist PRs' },
      { '<leader>pf', '<cmd>Octo pr search<CR>', desc = '[F]ind PR' },
      { '<leader>psm', '<cmd>Octo pr merge squash<CR>', desc = '[S]quash [M]erge' },
      {
        '<leader>po',
        function()
          vim.ui.input({ prompt = 'PR number: ' }, function(input)
            if input and input ~= '' then
              vim.cmd('Octo pr edit ' .. input)
            end
          end)
        end,
        desc = '[O]pen by number',
      },
      { '<leader>pr', '<cmd>Octo review start<CR>', desc = '[R]eview start' },
      {
        '<leader>pe',
        function()
          local current_file = vim.fn.expand '%:p'
          if current_file ~= '' and vim.bo.buftype == '' then
            local rel = vim.fn.fnamemodify(current_file, ':.')
            if rel ~= '' and not rel:match '^/' then
              octo_cache.set_resume_target { path = rel, line = vim.fn.line '.' }
            end
          end
          vim.cmd 'Octo review resume'
        end,
        desc = 'Review r[E]sume',
      },
      { '<leader>pm', '<cmd>Octo review submit<CR>', desc = 'Review sub[M]it' },
      { '<leader>pP', '<cmd>Octo pr approve<CR>', desc = 'A[P]prove' },
      { '<leader>pa', '<cmd>Octo comment add<CR>', desc = 'Comment [A]dd', mode = { 'n', 'v' } },
      { '<leader>pc', '<cmd>Octo pr comments<CR>', desc = '[C]omments' },
      { '<leader>pC', '<cmd>Octo review close<CR>', desc = 'Review [C]lose' },
      {
        '<leader>pq',
        function()
          -- Close review layout if active
          local ok, reviews = pcall(require, 'octo.reviews')
          if ok then
            local review = reviews.get_current_review()
            if review and review.layout then
              review.layout:close()
            end
          end
          -- Close all octo buffers
          require('custom.core.review-context').close_octo_buffers()
          -- Re-trigger BufEnter so which-key re-attaches after layout teardown
          -- (closing Octo review windows/tabs can disrupt which-key's state)
          vim.schedule(function()
            vim.cmd 'doautocmd BufEnter'
          end)
        end,
        desc = '[Q]uit Octo',
      },
      { '<leader>pX', '<cmd>Octo pr close<CR>', desc = 'Close PR' },
      -- PR actions
      { '<leader>pb', '<cmd>Octo pr browser<CR>', desc = 'Open in [B]rowser' },
      { '<leader>py', '<cmd>Octo pr url<CR>', desc = '[Y]ank URL' },
      { '<leader>pk', '<cmd>Octo pr checks<CR>', desc = 'Chec[K]s' },
      { '<leader>pO', '<cmd>Octo pr checkout<CR>', desc = 'Check[O]ut' },
      { '<leader>pR', '<cmd>Octo pr ready<CR>', desc = 'Mark [R]eady' },
      { '<leader>pD', '<cmd>Octo pr draft<CR>', desc = 'Mark [D]raft' },
      -- Review/thread actions
      { '<leader>pd', '<cmd>Octo review discard<CR>', desc = 'Review [D]iscard' },
      { '<leader>pt', '<cmd>Octo thread resolve<CR>', desc = '[T]hread resolve' },
      { '<leader>pT', '<cmd>Octo thread unresolve<CR>', desc = '[T]hread unresolve' },
    },
    config = function()
      vim.treesitter.language.register('markdown', 'octo')

      require('octo').setup {
        use_local_fs = false,
        enable_builtin = false,
        default_remote = { 'upstream', 'origin' },
        picker = 'telescope',
        mappings_disable_default = true,
        mappings = {
          review_diff = {
            select_next_entry = { lhs = ']f', desc = 'move to next changed file' },
            select_prev_entry = { lhs = '[f', desc = 'move to previous changed file' },
            next_thread = { lhs = ']C', desc = 'next review thread' },
            prev_thread = { lhs = '[C', desc = 'prev review thread' },
            toggle_viewed = { lhs = '<Tab>', desc = 'toggle file viewed' },
            select_next_unviewed_entry = { lhs = ']u', desc = 'next unviewed file' },
            select_prev_unviewed_entry = { lhs = '[u', desc = 'prev unviewed file' },
          },
          file_panel = {
            select_next_entry = { lhs = ']f', desc = 'move to next changed file' },
            select_prev_entry = { lhs = '[f', desc = 'move to previous changed file' },
            select_entry = { lhs = '<CR>', desc = 'open file' },
            toggle_viewed = { lhs = '<Tab>', desc = 'toggle file viewed' },
            select_next_unviewed_entry = { lhs = ']u', desc = 'next unviewed file' },
            select_prev_unviewed_entry = { lhs = '[u', desc = 'prev unviewed file' },
          },
          review_thread = {
            select_next_entry = { lhs = ']f', desc = 'move to next changed file' },
            select_prev_entry = { lhs = '[f', desc = 'move to previous changed file' },
          },
          submit_win = {
            approve_review = { lhs = '<C-a>', desc = 'approve review', mode = { 'n', 'i' } },
            comment_review = { lhs = '<C-m>', desc = 'comment review', mode = { 'n', 'i' } },
            request_changes = { lhs = '<C-r>', desc = 'request changes review', mode = { 'n', 'i' } },
          },
          -- Required: octo.workflow_runs reads these at module load time and crashes
          -- the telescope picker if they're nil (mappings_disable_default removes them)
          runs = {
            expand_step = { lhs = 'o', desc = 'expand workflow step' },
            open_in_browser = { lhs = '<C-b>', desc = 'open workflow run in browser' },
            refresh = { lhs = '<C-r>', desc = 'refresh workflow' },
            rerun = { lhs = '<C-o>', desc = 'rerun workflow' },
            rerun_failed = { lhs = '<C-f>', desc = 'rerun failed workflow' },
            cancel = { lhs = '<C-x>', desc = 'cancel workflow' },
            copy_url = { lhs = '<C-y>', desc = 'copy url to system clipboard' },
          },
        },
      }

      octo_cache.setup()

      -- Patch mappings to pass buffer context (upstream bug: opts is nil)
      local mappings = require 'octo.mappings'
      local context = require 'octo.context'
      mappings.list_commits = context.within_octo_buffer(function(buffer)
        require('octo.picker').commits { repo = buffer.repo, number = buffer.number }
      end)
      mappings.list_changed_files = context.within_octo_buffer(function(buffer)
        require('octo.picker').changed_files { repo = buffer.repo, number = buffer.number }
      end)

      -- Review buffers are ephemeral — never prompt to save on close.
      -- Thread buffers use buftype=acwrite (upstream), so Neovim can mark
      -- them modified. Reset the flag immediately to suppress the prompt.
      vim.api.nvim_create_autocmd('BufModifiedSet', {
        pattern = 'octo://*/review/*',
        callback = function(event)
          if vim.bo[event.buf].modified then
            vim.bo[event.buf].modified = false
          end
        end,
      })

      -- Disable keymaps that don't make sense in Octo review context
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'octo',
        callback = function(event)
          vim.keymap.set('n', '<leader>u', '<Nop>', { buffer = event.buf })
        end,
      })

      -- 'l' to open file from file panel (mirrors diffview behaviour)
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'octo_panel',
        callback = function(event)
          vim.keymap.set('n', 'l', function()
            require('octo.mappings').select_entry()
          end, { buffer = event.buf, desc = 'Open file' })
        end,
      })

      -- Scroll keymaps for review diff buffers (non-modifiable, so safe to use single keys)
      local file_entry = require 'octo.reviews.file-entry'

      -- Re-enable soft wrap synchronously when :diffthis flips diff on for an
      -- octo review window. OptionSet fires inside the :diffthis call, so wrap
      -- is restored before the unwrapped state ever renders.
      vim.api.nvim_create_autocmd('OptionSet', {
        pattern = 'diff',
        callback = function()
          if not vim.api.nvim_get_option_value('diff', { win = 0 }) then
            return
          end
          local bufname = vim.api.nvim_buf_get_name(0)
          if not bufname:match '^octo://' then
            return
          end
          vim.api.nvim_set_option_value('wrap', true, { win = 0 })
          vim.api.nvim_set_option_value('linebreak', true, { win = 0 })
          vim.api.nvim_set_option_value('breakindent', true, { win = 0 })
        end,
      })

      local orig_configure = file_entry._configure_buffer
      file_entry._configure_buffer = function(bufid)
        orig_configure(bufid)
        vim.keymap.set('n', '<leader>u', '<Nop>', { buffer = bufid })
        local function scroll(fraction)
          local lines = math.floor(vim.api.nvim_win_get_height(0) * math.abs(fraction))
          local key = fraction > 0 and '<C-e>' or '<C-y>'
          vim.cmd('normal! ' .. lines .. vim.api.nvim_replace_termcodes(key, true, true, true))
        end
        vim.keymap.set('n', 'f', function()
          scroll(0.25)
        end, { buffer = bufid, desc = 'Scroll down quarter page' })
        vim.keymap.set('n', 'b', function()
          scroll(-0.25)
        end, { buffer = bufid, desc = 'Scroll up quarter page' })
        vim.keymap.set('n', 'd', function()
          scroll(0.5)
        end, { buffer = bufid, desc = 'Scroll down half page' })
        vim.keymap.set('n', 'u', function()
          scroll(-0.5)
        end, { buffer = bufid, desc = 'Scroll up half page' })
      end

      -- Mark current file as viewed when navigating forward, not backward
      local reviews = require 'octo.reviews'

      mappings.select_next_entry = function()
        local layout = reviews.get_current_layout()
        if not layout then
          return
        end
        local file = layout:get_current_file()
        if file and file.viewed_state ~= 'VIEWED' then
          file:toggle_viewed()
        end
        layout:select_next_file()
      end
      mappings.select_prev_entry = function()
        local layout = reviews.get_current_layout()
        if not layout then
          return
        end
        layout:select_prev_file()
      end

      mappings.select_next_unviewed_entry = function()
        local layout = reviews.get_current_layout()
        if not layout then
          return
        end
        local file = layout:get_current_file()
        if file and file.viewed_state ~= 'VIEWED' then
          file:toggle_viewed()
        end
        layout:select_next_unviewed_file()
      end
      mappings.select_prev_unviewed_entry = function()
        local layout = reviews.get_current_layout()
        if not layout then
          return
        end
        layout:select_prev_unviewed_file()
      end

      -- Fix left-side diff highlights: upstream only remaps DiffChange but
      -- not DiffAdd, so deleted lines on the left show green instead of red.
      local Layout = require 'octo.reviews.layout'
      local constants = require 'octo.constants'
      local orig_init_layout = Layout.init_layout
      Layout.init_layout = function(self)
        orig_init_layout(self)
        vim.api.nvim_set_hl(constants.OCTO_REVIEW_LEFT_HIGHLIGHT_NS, 'DiffAdd', { link = 'DiffDelete' })
      end
    end,
  },
}
