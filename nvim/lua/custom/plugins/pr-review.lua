-- PR review plugins: diffview, octo

-- Unified review mode: toggle Octo's side-by-side diff into a single-pane
-- view with gitsigns-style line/number highlights and inline deleted lines.
-- Parses the PR patch data directly so it works on virtual buffers without
-- needing use_local_fs or a checked-out branch.
local unified = {
  active = true, -- unified mode is the default
  orig_show_diff = nil, -- set once during Octo config
}

local ns_unified = vim.api.nvim_create_namespace 'octo_unified_hl'

-- Parse a file's patch and apply add/delete highlights to the right buffer
local function apply_patch_highlights(file, right_bufnr)
  if not right_bufnr or not vim.api.nvim_buf_is_valid(right_bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(right_bufnr, ns_unified, 0, -1)

  -- New/added files: highlight every line green
  if file.status == 'A' or file.status == 'added' then
    local count = vim.api.nvim_buf_line_count(right_bufnr)
    for i = 0, count - 1 do
      pcall(vim.api.nvim_buf_set_extmark, right_bufnr, ns_unified, i, 0, {
        line_hl_group = 'GitSignsAddLn',
        number_hl_group = 'GitSignsAddNr',
      })
    end
    return
  end

  if not file.patch then
    return
  end

  -- Parse each hunk from the patch
  local hunk_strings = vim.split(file.patch:gsub('^@@', ''), '\n@@')
  for _, hunk in ipairs(hunk_strings) do
    local lines = vim.split(hunk, '\n')
    local header = lines[1]
    local _, _, right_start = string.find(header, '%+(%d+)')
    if not right_start then
      goto continue
    end
    right_start = tonumber(right_start)

    local right_line = right_start
    local pending_deletes = {}
    local in_modification = false
    for j = 2, #lines do
      local prefix = lines[j]:sub(1, 1)
      if prefix == '+' then
        -- Flush pending deletes above this line so they appear before the add
        if #pending_deletes > 0 then
          in_modification = true
          local anchor = math.max(right_line - 1, 0)
          pcall(vim.api.nvim_buf_set_extmark, right_bufnr, ns_unified, anchor, 0, {
            virt_lines = pending_deletes,
            virt_lines_above = true,
          })
          pending_deletes = {}
        end
        -- Added line with JetBrains-style gutter bar
        pcall(vim.api.nvim_buf_set_extmark, right_bufnr, ns_unified, right_line - 1, 0, {
          line_hl_group = 'OctoReviewAddLn',
          sign_text = '▎',
          sign_hl_group = in_modification and 'GitSignsChange' or 'GitSignsAdd',
        })
        right_line = right_line + 1
      elseif prefix == '-' then
        -- Deleted line: collect and show as virtual text
        table.insert(pending_deletes, { { lines[j]:sub(2), 'OctoReviewDeleteVirtLn' } })
      else
        -- Context or end-of-hunk: flush any pending deletes, reset modification state
        if #pending_deletes > 0 then
          local anchor = math.max(right_line - 1, 0)
          pcall(vim.api.nvim_buf_set_extmark, right_bufnr, ns_unified, anchor, 0, {
            virt_lines = pending_deletes,
            virt_lines_above = true,
          })
          pending_deletes = {}
        end
        in_modification = false
        if prefix == ' ' then
          right_line = right_line + 1
        end
      end
    end
    -- Flush remaining deletes at end of hunk
    if #pending_deletes > 0 then
      local anchor = math.max(right_line - 2, 0)
      pcall(vim.api.nvim_buf_set_extmark, right_bufnr, ns_unified, anchor, 0, {
        virt_lines = pending_deletes,
      })
    end
    ::continue::
  end
end

local function clear_patch_highlights(right_bufnr)
  if right_bufnr and vim.api.nvim_buf_is_valid(right_bufnr) then
    vim.api.nvim_buf_clear_namespace(right_bufnr, ns_unified, 0, -1)
  end
end

-- Navigate to next/prev hunk (contiguous group of changed lines)
local function navigate_change(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-indexed

  -- Collect all changed lines from extmarks
  local all_marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_unified, 0, -1, {})
  if #all_marks == 0 then
    return
  end

  local line_set = {}
  for _, mark in ipairs(all_marks) do
    line_set[mark[2]] = true
  end
  local lines = {}
  for line, _ in pairs(line_set) do
    table.insert(lines, line)
  end
  table.sort(lines)

  -- Group into hunks: collect the first line of each contiguous range
  local hunk_starts = { lines[1] }
  for i = 2, #lines do
    if lines[i] > lines[i - 1] + 1 then
      table.insert(hunk_starts, lines[i])
    end
  end

  if direction == 'next' then
    for _, start in ipairs(hunk_starts) do
      if start > cursor_line then
        vim.api.nvim_win_set_cursor(0, { start + 1, 0 })
        return
      end
    end
  else
    for i = #hunk_starts, 1, -1 do
      if hunk_starts[i] < cursor_line then
        vim.api.nvim_win_set_cursor(0, { hunk_starts[i] + 1, 0 })
        return
      end
    end
  end
end

-- Set up ]c/[c navigation on a review diff buffer
local function set_hunk_nav_keymaps(bufnr)
  vim.keymap.set('n', ']c', function()
    navigate_change 'next'
  end, { buffer = bufnr, silent = true, desc = 'Next changed line' })
  vim.keymap.set('n', '[c', function()
    navigate_change 'prev'
  end, { buffer = bufnr, silent = true, desc = 'Previous changed line' })
end

local function clear_hunk_nav_keymaps(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.keymap.del, 'n', ']c', { buffer = bufnr })
    pcall(vim.keymap.del, 'n', '[c', { buffer = bufnr })
  end
end

-- Apply unified mode to the current layout state
local function apply_unified_to_layout(layout)
  local file = layout:get_current_file()
  -- Shrink left window to 1 column so it stays valid but invisible
  if vim.api.nvim_win_is_valid(layout.left_winid) then
    vim.api.nvim_win_set_width(layout.left_winid, 1)
    vim.api.nvim_win_call(layout.left_winid, function()
      vim.cmd 'diffoff'
      vim.wo.scrollbind = false
      vim.wo.cursorbind = false
    end)
  end

  -- Right window: disable diff, apply patch highlights and hunk nav
  if vim.api.nvim_win_is_valid(layout.right_winid) then
    vim.api.nvim_set_current_win(layout.right_winid)
    vim.cmd 'diffoff'
    vim.wo.scrollbind = false
    vim.wo.cursorbind = false
    if file then
      apply_patch_highlights(file, file.right_bufid)
      set_hunk_nav_keymaps(file.right_bufid)
    end
  end
end

-- Toggle between Octo's side-by-side diff and unified view
local function toggle_unified_review()
  local reviews_ok, reviews = pcall(require, 'octo.reviews')
  if not reviews_ok then
    return
  end

  local review = reviews.get_current_review()
  if not review or not review.layout then
    vim.notify('No active Octo review', vim.log.levels.WARN)
    return
  end

  local layout = review.layout

  -- Flip the mode
  unified.active = not unified.active

  if unified.active then
    apply_unified_to_layout(layout)
  else
    -- Switch to side-by-side: clear highlights and keymaps, restore left, re-enable diff
    local file = layout:get_current_file()
    if file then
      clear_patch_highlights(file.right_bufid)
      clear_hunk_nav_keymaps(file.right_bufid)
    end

    if vim.api.nvim_win_is_valid(layout.left_winid) then
      vim.api.nvim_win_set_width(layout.left_winid, math.floor(vim.o.columns / 2))
    end

    -- Re-enable vim diff via the original show_diff
    if file and unified.orig_show_diff then
      unified.orig_show_diff(file)
    end
  end
end

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
            toggle_unified = { lhs = '<localleader>u', desc = 'toggle unified diff view' },
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

      -- Patch FileEntry.show_diff once so unified mode works on every file switch
      local FileEntry = require('octo.reviews.file-entry').FileEntry
      unified.orig_show_diff = FileEntry.show_diff
      FileEntry.show_diff = function(self)
        -- Always run the original to load/attach buffers properly
        unified.orig_show_diff(self)
        if not unified.active then
          return
        end
        -- Apply unified layout after a tick (buffers need to settle)
        vim.defer_fn(function()
          local reviews = require 'octo.reviews'
          local review = reviews.get_current_review()
          if review and review.layout then
            apply_unified_to_layout(review.layout)
          end
        end, 50)
      end

      -- Register unified review toggle on the Octo mappings module
      local mappings = require 'octo.mappings'
      mappings.toggle_unified = toggle_unified_review

      -- Patch mappings to pass buffer context (upstream bug: opts is nil)
      local context = require 'octo.context'
      mappings.list_commits = context.within_octo_buffer(function(buffer)
        require('octo.picker').commits { repo = buffer.repo, number = buffer.number }
      end)
      mappings.list_changed_files = context.within_octo_buffer(function(buffer)
        require('octo.picker').changed_files { repo = buffer.repo, number = buffer.number }
      end)

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

      -- Reset unified mode to default when review tab closes
      vim.api.nvim_create_autocmd('TabClosed', {
        callback = function()
          unified.active = true
        end,
      })
    end,
  },
}
