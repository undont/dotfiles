-- Git-related plugins

-- Fugitive window management: track the single edit window alongside the status pane
local function get_fugitive_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'fugitive' then
      return win
    end
  end
  return nil
end

-- Find the edit window (non-fugitive, non-tree window in the same tab)
local function get_edit_win()
  local fugitive_win = get_fugitive_win()
  if not fugitive_win then
    return nil
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= fugitive_win then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      -- Only match normal file buffers, skip neo-tree/other special buffers
      if vim.bo[buf].buftype == '' and ft ~= 'neo-tree' and ft ~= 'NvimTree' then
        return win
      end
    end
  end
  return nil
end

-- Namespace for highlighting new/untracked files entirely green
local ns_new_file = vim.api.nvim_create_namespace 'fugitive_new_file_hl'

-- Apply green highlights to every line for new/untracked files
local function highlight_new_file(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_new_file, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for i = 0, line_count - 1 do
    vim.api.nvim_buf_set_extmark(bufnr, ns_new_file, i, 0, {
      line_hl_group = 'GitSignsAddLn',
      number_hl_group = 'GitSignsAddNr',
    })
  end
end

local function clear_new_file_highlights(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr or vim.api.nvim_get_current_buf(), ns_new_file, 0, -1)
end

-- Enable gitsigns review mode (line + number highlights)
local function enable_review_mode(status_char)
  local gs = require 'gitsigns'

  -- Compare against HEAD so both staged and unstaged changes show as hunks
  gs.change_base 'HEAD'

  -- Enable per-buffer: numhl, linehl
  gs.toggle_numhl(true)
  gs.toggle_linehl(true)

  -- For new/untracked files, gitsigns won't show diffs — highlight all lines green
  if status_char and (status_char == '?' or status_char == 'A') then
    highlight_new_file(vim.api.nvim_get_current_buf())
  end
end

-- Disable gitsigns review mode
local function disable_review_mode()
  local ok, gs = pcall(require, 'gitsigns')
  if not ok then
    return
  end
  gs.toggle_numhl(false)
  gs.toggle_linehl(false)
  -- Reset base back to index (default)
  gs.reset_base()
  clear_new_file_highlights(vim.api.nvim_get_current_buf())
end

-- Open a file from fugitive status in the edit pane (reuse or create)
local function fugitive_open_file()
  local fugitive_win = vim.api.nvim_get_current_win()
  local edit_win = get_edit_win()

  -- Parse file path and status from the current line in fugitive status
  local line = vim.api.nvim_get_current_line()
  -- Match status char(s) followed by space then filename
  local status_char, file = line:match '^%s*([MADRCU?!]+)%s+(.+)$'
  if not file then
    return
  end

  -- Strip trailing whitespace
  file = file:gsub('%s+$', '')

  -- If it's a directory or deleted file, skip to the next valid file entry
  local status = line:match '^%s*([MADRCU?!]+)%s'
  if file:sub(-1) == '/' or status == 'D' then
    local next_line = vim.fn.search('^\\s*[MARCU?!]\\+\\s\\+.*[^/]$', 'W')
    if next_line > 0 then
      fugitive_open_file()
    end
    return
  end

  -- Resolve to absolute path relative to repo root
  local git_dir = vim.fn.FugitiveWorkTree()
  if git_dir ~= '' then
    file = git_dir .. '/' .. file
  end

  -- Only open actual readable files
  if vim.fn.filereadable(file) ~= 1 then
    return
  end

  -- Disable review mode on old buffer before switching
  if edit_win then
    vim.api.nvim_set_current_win(edit_win)
    disable_review_mode()
    vim.cmd('edit ' .. vim.fn.fnameescape(file))
  else
    vim.cmd('rightbelow vsplit ' .. vim.fn.fnameescape(file))
  end

  -- Enable review mode on the newly opened buffer
  vim.schedule(function()
    enable_review_mode(status_char)
    if vim.api.nvim_win_is_valid(fugitive_win) then
      vim.api.nvim_win_set_width(fugitive_win, 40)
    end
  end)
end

-- Navigate to next/prev file in fugitive and open it in the edit pane
local function navigate_fugitive_file(direction)
  local fugitive_win = get_fugitive_win()
  if not fugitive_win then
    vim.notify('No fugitive status window open', vim.log.levels.WARN)
    return
  end

  -- Focus fugitive
  vim.api.nvim_set_current_win(fugitive_win)

  local search_flags = direction == 'next' and 'W' or 'bW'
  local found = vim.fn.search('^[MADRCU?! ]\\s', search_flags)

  if found > 0 then
    fugitive_open_file()
  end
end

return {
  -- LazyGit integration
  {
    'kdheepak/lazygit.nvim',
    lazy = true,
    cmd = {
      'LazyGit',
      'LazyGitConfig',
      'LazyGitCurrentFile',
      'LazyGitFilter',
      'LazyGitFilterCurrentFile',
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
  },

  -- Fugitive: Git integration with custom status workflow
  {
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G', 'Gvdiffsplit', 'Gvsplit', 'Gdiffsplit', 'Gread', 'Gwrite', 'GBrowse' },
    keys = {
      { '<leader>vs', '<cmd>Git<CR>', desc = '[V]cs [S]tatus' },
      { '<leader>vb', '<cmd>Git blame<CR>', desc = '[V]cs [B]lame' },
      { '<leader>vd', '<cmd>Gvdiffsplit<CR>', desc = '[V]cs [D]iff split' },
    },
    config = function()
      -- Make navigate_fugitive_file available globally for gitsigns ]f/[f
      _G._fugitive_navigate = navigate_fugitive_file

      -- Custom keymaps for fugitive status buffer
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'fugitive',
        callback = function(ev)
          local opts = { buffer = ev.buf, silent = true }

          -- Set status window to 40 columns wide
          vim.api.nvim_win_set_width(0, 40)

          -- Jump cursor to the first file entry
          vim.fn.cursor(1, 1)
          vim.fn.search('^[MADRCU?! ]\\s', 'W')

          -- ]c / [c: navigate between changed entries (no wrap)
          vim.keymap.set('n', ']c', function()
            vim.fn.search('^[MADRCU?! ]\\s', 'W')
          end, vim.tbl_extend('force', opts, { desc = 'Next changed entry' }))
          vim.keymap.set('n', '[c', function()
            vim.fn.search('^[MADRCU?! ]\\s', 'bW')
          end, vim.tbl_extend('force', opts, { desc = 'Previous changed entry' }))

          -- ]f / [f: navigate between files and open in edit pane
          vim.keymap.set('n', ']f', function()
            vim.fn.search('^\\s*[MARCU?!]\\+\\s\\+.*[^/]$', 'W')
          end, vim.tbl_extend('force', opts, { desc = 'Next changed file' }))
          vim.keymap.set('n', '[f', function()
            vim.fn.search('^\\s*[MARCU?!]\\+\\s\\+.*[^/]$', 'bW')
          end, vim.tbl_extend('force', opts, { desc = 'Previous changed file' }))

          -- l: open file under cursor in the edit pane (reuse existing)
          vim.keymap.set('n', 'l', fugitive_open_file, opts)

          -- E: exit fugitive and edit the currently open file normally
          --    :q / :wq on the file will return to fugitive
          vim.keymap.set('n', 'E', function()
            local edit_win = get_edit_win()
            if edit_win then
              local edit_buf = vim.api.nvim_win_get_buf(edit_win)
              vim.api.nvim_win_call(edit_win, disable_review_mode)
              vim.cmd 'close'
              vim.api.nvim_set_current_win(edit_win)

              -- When quitting the edit buffer, reopen fugitive instead of exiting
              vim.api.nvim_create_autocmd('QuitPre', {
                buffer = edit_buf,
                once = true,
                callback = function()
                  -- Open fugitive in a split so :q closes the edit window, not Neovim
                  vim.cmd 'vertical Git'
                  vim.cmd 'wincmd p'
                end,
              })
            else
              vim.cmd 'close'
            end
          end, vim.tbl_extend('force', opts, { desc = 'Exit fugitive and edit file' }))
        end,
      })

      -- In file buffers opened alongside fugitive, set up h to go back
      vim.api.nvim_create_autocmd('BufEnter', {
        callback = function()
          local fugitive_win = get_fugitive_win()
          if fugitive_win and vim.bo.filetype ~= 'fugitive' then
            vim.keymap.set('n', 'h', function()
              if vim.api.nvim_win_is_valid(fugitive_win) then
                disable_review_mode()
                vim.api.nvim_set_current_win(fugitive_win)
              end
            end, { buffer = true, silent = true, desc = 'Back to fugitive status' })
          end
        end,
      })

      -- Global ]f/[f mappings: active while fugitive is open, cleaned up when it closes.
      -- Global avoids race conditions with buffer-local maps and lazy plugin loading.
      local function set_global_fugitive_nav()
        vim.keymap.set('n', ']f', function()
          if get_fugitive_win() then
            navigate_fugitive_file 'next'
          end
        end, { silent = true, desc = 'Next changed file (fugitive)' })

        vim.keymap.set('n', '[f', function()
          if get_fugitive_win() then
            navigate_fugitive_file 'prev'
          end
        end, { silent = true, desc = 'Previous changed file (fugitive)' })
      end

      local function clear_global_fugitive_nav()
        pcall(vim.keymap.del, 'n', ']f')
        pcall(vim.keymap.del, 'n', '[f')
      end

      -- Set global nav when fugitive opens
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'fugitive',
        callback = set_global_fugitive_nav,
      })

      -- Clean up when fugitive window closes
      vim.api.nvim_create_autocmd('BufWinLeave', {
        callback = function()
          if vim.bo.filetype == 'fugitive' then
            local edit_win = get_edit_win()
            if edit_win then
              vim.api.nvim_win_call(edit_win, disable_review_mode)
            end
            clear_global_fugitive_nav()
          end
        end,
      })
    end,
  },
}
