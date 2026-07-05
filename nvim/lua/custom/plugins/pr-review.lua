-- PR review plugin: octo

local octo_cache = require 'custom.features.octo-review-cache'

return {
  -- Octo: GitHub PR review from within nvim
  {
    'pwntester/octo.nvim',
    cmd = { 'Octo', 'OctoCacheClear' },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    -- launcher keymaps moved to differ (custom.plugins.differ owns <leader>p*).
    -- octo stays installed as a fallback for pr search, issues, and any differ
    -- pr rough edge; reach it via :Octo (e.g. :Octo pr search)
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
          -- required: octo.workflow_runs reads these at module load time and crashes
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

      -- patch mappings to pass buffer context (upstream bug: opts is nil)
      local mappings = require 'octo.mappings'
      local context = require 'octo.context'
      mappings.list_commits = context.within_octo_buffer(function(buffer)
        require('octo.picker').commits { repo = buffer.repo, number = buffer.number }
      end)
      mappings.list_changed_files = context.within_octo_buffer(function(buffer)
        require('octo.picker').changed_files { repo = buffer.repo, number = buffer.number }
      end)

      -- review buffers are ephemeral; never prompt to save on close.
      -- thread buffers use buftype=acwrite (upstream), so nvim can mark
      -- them modified. reset the flag immediately to suppress the prompt
      vim.api.nvim_create_autocmd('BufModifiedSet', {
        pattern = 'octo://*/review/*',
        callback = function(event)
          if vim.bo[event.buf].modified then
            vim.bo[event.buf].modified = false
          end
        end,
      })

      -- disable keymaps that don't make sense in Octo review context
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'octo',
        callback = function(event)
          vim.keymap.set('n', '<leader>u', '<Nop>', { buffer = event.buf })
        end,
      })

      -- 'l' to open file from file panel
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'octo_panel',
        callback = function(event)
          vim.keymap.set('n', 'l', function()
            require('octo.mappings').select_entry()
          end, { buffer = event.buf, desc = 'Open file' })
        end,
      })

      -- scroll keymaps for review diff buffers (non-modifiable, so safe to use single keys)
      local file_entry = require 'octo.reviews.file-entry'

      -- re-enable soft wrap synchronously when :diffthis flips diff on for an
      -- octo review window. OptionSet fires inside the :diffthis call, so wrap
      -- is restored before the unwrapped state ever renders
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

      -- mark current file as viewed when navigating forward, not backward
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

      -- fix left-side diff highlights: upstream only remaps DiffChange but
      -- not DiffAdd, so deleted lines on the left show green instead of red
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
