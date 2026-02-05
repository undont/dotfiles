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
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = { layout = 'diff2_horizontal' },
        merge_tool = { layout = 'diff3_mixed' },
      },
    },
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
      { '<leader>ps', '<cmd>Octo pr search<CR>', desc = '[P]R [S]earch' },
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
      { '<leader>pc', '<cmd>Octo pr comments<CR>', desc = '[P]R [C]omments' },
    },
    config = function()
      -- Register markdown/markdown_inline treesitter parsers for Octo buffers
      vim.treesitter.language.register('markdown', 'octo')

      require('octo').setup {
        use_local_fs = false,
        enable_builtin = true,
        default_remote = { 'upstream', 'origin' },
        picker = 'telescope',
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

      -- Mark current file as viewed before navigating to next/prev
      local reviews = require 'octo.reviews'
      local function mark_viewed_and_navigate(select_fn)
        local layout = reviews.get_current_layout()
        if not layout then
          return
        end
        local file = layout:get_current_file()
        if file and file.viewed_state ~= 'VIEWED' then
          file:toggle_viewed()
        end
        select_fn(layout)
      end

      mappings.select_next_entry = function()
        mark_viewed_and_navigate(function(layout)
          layout:select_next_file()
        end)
      end
      mappings.select_prev_entry = function()
        mark_viewed_and_navigate(function(layout)
          layout:select_prev_file()
        end)
      end
    end,
  },
}
