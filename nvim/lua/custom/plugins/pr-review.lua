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
      { '<leader>dh', '<cmd>DiffviewFileHistory %<CR>', desc = '[D]iff file [H]istory' },
      { '<leader>dp', '<cmd>DiffviewFileHistory --range=origin/HEAD...HEAD --right-only --no-merges<CR>', desc = '[D]iff [P]R review' },
    },
    config = function(_, opts)
      require('diffview').setup(opts)

      -- Patch sync_scroll to guard against invalid window ids (upstream bug)
      -- See: https://github.com/sindrets/diffview.nvim/issues/550
      local Layout = require 'diffview.scene.layout'
      local api = vim.api
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
      { '<leader>pl', '<cmd>Octo pr list<CR>', desc = '[P]R [L]ist' },
      { '<leader>pf', '<cmd>Octo pr search<CR>', desc = '[P]R [F]ind' },
      { '<leader>psm', '<cmd>Octo pr merge squash<CR>', desc = '[P]R [S]quash [M]erge' },
      {
        '<leader>po',
        function()
          vim.ui.input({ prompt = 'PR number: ' }, function(input)
            if input and input ~= '' then
              vim.cmd('Octo pr edit ' .. input)
            end
          end)
        end,
        desc = '[P]R [O]pen by number',
      },
      { '<leader>pr', '<cmd>Octo review start<CR>', desc = '[P]R [R]eview start' },
      { '<leader>pe', '<cmd>Octo review resume<CR>', desc = '[P]R review r[E]sume' },
      { '<leader>pm', '<cmd>Octo review submit<CR>', desc = '[P]R review sub[M]it' },
      { '<leader>pp', '<cmd>Octo pr approve<CR>', desc = '[P]R a[P]prove' },
      { '<leader>pa', '<cmd>Octo comment add<CR>', desc = '[P]R comment [A]dd', mode = { 'n', 'v' } },
      { '<leader>pc', '<cmd>Octo pr comments<CR>', desc = '[P]R [C]omments' },
      { '<leader>pC', '<cmd>Octo review close<CR>', desc = '[P]R review [C]lose' },
      { '<leader>pX', '<cmd>Octo pr close<CR>', desc = '[P]R close' },
      -- PR actions
      { '<leader>pb', '<cmd>Octo pr browser<CR>', desc = '[P]R [B]rowser' },
      { '<leader>py', '<cmd>Octo pr url<CR>', desc = '[P]R [Y]ank URL' },
      { '<leader>pk', '<cmd>Octo pr checks<CR>', desc = '[P]R chec[K]s' },
      { '<leader>pO', '<cmd>Octo pr checkout<CR>', desc = '[P]R check[O]ut' },
      { '<leader>pR', '<cmd>Octo pr ready<CR>', desc = '[P]R [R]eady' },
      { '<leader>pD', '<cmd>Octo pr draft<CR>', desc = '[P]R [D]raft' },
      -- Review/thread actions
      { '<leader>pd', '<cmd>Octo review discard<CR>', desc = '[P]R review [D]iscard' },
      { '<leader>pt', '<cmd>Octo thread resolve<CR>', desc = '[P]R [T]hread resolve' },
      { '<leader>pT', '<cmd>Octo thread unresolve<CR>', desc = '[P]R [T]hread unresolve' },
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
