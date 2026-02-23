-- PR review plugins: diffview, octo

return {
  -- Diffview: side-by-side diffs and file history
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles' },
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>do', '<cmd>DiffviewOpen<CR>', desc = '[D]iff [O]pen (vs index)' },
      { '<leader>dc', '<cmd>DiffviewClose<CR>', desc = '[D]iff [C]lose' },
      {
        '<leader>dh',
        function()
          local file = vim.fn.expand '%'
          if file ~= '' and vim.fn.filereadable(file) == 1 then
            vim.cmd 'DiffviewFileHistory %'
          else
            vim.cmd 'DiffviewFileHistory'
          end
        end,
        desc = '[D]iff file [H]istory',
      },
      { '<leader>dp', '<cmd>DiffviewFileHistory --range=origin/HEAD...HEAD --right-only --no-merges<CR>', desc = '[D]iff [P]R review' },
    },
    config = function(_, opts)
      require('diffview').setup(opts)

      -- Global ]f/[f: active while diffview is open, cleaned up when it closes
      local function set_nav()
        local actions = require 'diffview.actions'
        vim.keymap.set('n', ']f', actions.select_next_entry, { silent = true, desc = 'Next changed file (diffview)' })
        vim.keymap.set('n', '[f', actions.select_prev_entry, { silent = true, desc = 'Previous changed file (diffview)' })
      end

      local function clear_nav()
        pcall(vim.keymap.del, 'n', ']f')
        pcall(vim.keymap.del, 'n', '[f')
      end

      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'DiffviewFiles', 'DiffviewFileHistory' },
        callback = set_nav,
      })
      vim.api.nvim_create_autocmd('BufWinLeave', {
        callback = function()
          local ft = vim.bo.filetype
          if ft == 'DiffviewFiles' or ft == 'DiffviewFileHistory' then
            clear_nav()
          end
        end,
      })

      -- Patch diffview upstream bugs (nil guards for async race conditions)
      -- See: https://github.com/sindrets/diffview.nvim/issues/550
      local api = vim.api

      -- Patch init_layout: curwin may already be closed after layout:create()

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
      return {
        enhanced_diff_hl = true,
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
            { 'n', 'f', actions.scroll_view(0.25), { desc = 'Scroll the view down' } },
            { 'n', 'b', actions.scroll_view(-0.25), { desc = 'Scroll the view up' } },
          },
          file_panel = {
            { 'n', 'f', actions.scroll_view(0.25), { desc = 'Scroll the view down' } },
            { 'n', 'b', actions.scroll_view(-0.25), { desc = 'Scroll the view up' } },
          },
          file_history_panel = {
            { 'n', 'f', actions.scroll_view(0.25), { desc = 'Scroll the view down' } },
            { 'n', 'b', actions.scroll_view(-0.25), { desc = 'Scroll the view up' } },
          },
        },
      }
    end,
  },

  -- Octo: GitHub PR review from within Neovim
  {
    'pwntester/octo.nvim',
    cmd = 'Octo',
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
      { '<leader>pe', '<cmd>Octo review resume<CR>', desc = 'Review r[E]sume' },
      { '<leader>pm', '<cmd>Octo review submit<CR>', desc = 'Review sub[M]it' },
      { '<leader>pp', '<cmd>Octo pr approve<CR>', desc = 'A[P]prove' },
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
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'octo' then
              vim.api.nvim_buf_delete(buf, { force = true })
            end
          end
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
          },
          file_panel = {
            select_next_entry = { lhs = ']f', desc = 'move to next changed file' },
            select_prev_entry = { lhs = '[f', desc = 'move to previous changed file' },
            select_entry = { lhs = '<CR>', desc = 'open file' },
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

      -- Patch mappings to pass buffer context (upstream bug: opts is nil)
      local mappings = require 'octo.mappings'
      local context = require 'octo.context'
      mappings.list_commits = context.within_octo_buffer(function(buffer)
        require('octo.picker').commits { repo = buffer.repo, number = buffer.number }
      end)
      mappings.list_changed_files = context.within_octo_buffer(function(buffer)
        require('octo.picker').changed_files { repo = buffer.repo, number = buffer.number }
      end)

      -- Scroll keymaps for review diff buffers (non-modifiable, so safe to use single keys)
      local file_entry = require 'octo.reviews.file-entry'
      local orig_configure = file_entry._configure_buffer
      file_entry._configure_buffer = function(bufid)
        orig_configure(bufid)
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
    end,
  },
}
