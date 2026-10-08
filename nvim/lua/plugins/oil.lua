-- oil: file explorer with git status

-- close oil, restoring the dashboard if oil was opened from it. the snacks
-- dashboard is bufhidden=wipe, so oil.close() lands on a blank `enew` buffer
local function oil_close()
  require('oil').close()
  local buf = vim.api.nvim_get_current_buf()
  local empty = vim.api.nvim_buf_get_name(buf) == ''
    and vim.bo[buf].buftype == ''
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''
  if empty and Snacks and Snacks.dashboard then
    -- open() merges partial opts with the configured dashboard defaults
    ---@diagnostic disable-next-line: missing-fields
    Snacks.dashboard.open { win = vim.api.nvim_get_current_win() }
  end
end

-- oil hides its per-line entry IDs (the `/006 ` prefix) with window-local
-- `conceallevel`/`concealcursor`, so an oil buffer shown in a window that
-- never ran oil's set_win_options shows the IDs. oil's set_win_options reads
-- `nvim_get_current_win()` inside an `nvim_buf_call`, which does not switch
-- the window, so it can set the wrong one on a fresh open. the options are
-- set on the resolved oil window one tick after it becomes visible
vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
  pattern = 'oil://*',
  callback = function()
    local win = vim.api.nvim_get_current_win()
    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(win) then
        return
      end
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype ~= 'oil' then
        return
      end
      vim.api.nvim_set_option_value('conceallevel', 3, { scope = 'local', win = win })
      vim.api.nvim_set_option_value('concealcursor', 'nvic', { scope = 'local', win = win })
    end)
  end,
})

-- oil-git-status links these once at setup, and every colourscheme runs
-- `hi clear`, so they are relinked on ColorScheme
local oil_git_status_links = {
  Added = 'GitSignsAdd',
  Untracked = 'GitSignsAdd',
  Modified = 'GitSignsChange',
  Renamed = 'GitSignsChange',
  Copied = 'GitSignsChange',
  TypeChanged = 'GitSignsChange',
  Deleted = 'GitSignsDelete',
  Unmerged = 'DiagnosticError',
}

local function link_oil_git_status_hl()
  for status, target in pairs(oil_git_status_links) do
    vim.api.nvim_set_hl(0, 'OilGitStatusIndex' .. status, { link = target })
    vim.api.nvim_set_hl(0, 'OilGitStatusWorkingTree' .. status, { link = target })
  end
end

return {
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    -- oil's directory-hijack autocmd must exist before `nvim <dir>` is processed
    lazy = false,
    keys = {
      { '-', '<cmd>Oil<CR>', desc = 'Oil: Open parent directory' },
    },
    -- vim.g.oil_opts (set in local.lua) deep-merges over these defaults
    opts = function()
      return vim.tbl_deep_extend('force', {
        default_file_explorer = true,
        columns = { 'icon' },
        -- oil-git-status draws index and working-tree status in one column each.
        -- the empty `statuscolumn` opts out of statuscol's (see plugins/statuscol.lua),
        -- whose single-cell sign segment would drop one of the two
        win_options = { signcolumn = 'yes:2', statuscolumn = '' },
        -- `sort` names the `notedate` column registered in config below
        view_options = { show_hidden = true, sort = require('features.dated-notes').oil_sort },
        keymaps = {
          ['-'] = { mode = 'n', callback = oil_close },
          ['<BS>'] = { 'actions.parent', mode = 'n' },
          ['gi'] = { 'actions.select', mode = 'n' },
          ['go'] = { 'actions.parent', mode = 'n' },
        },
      }, vim.g.oil_opts or {})
    end,
    config = function(_, opts)
      require('oil').setup(opts)
      require('features.dated-notes').setup_oil()
    end,
  },

  {
    'refractalize/oil-git-status.nvim',
    dependencies = { 'stevearc/oil.nvim' },
    config = function()
      require('oil-git-status').setup { show_ignored = false }
      link_oil_git_status_hl()
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('oil-git-status-hl', { clear = true }),
        callback = link_oil_git_status_hl,
      })
    end,
  },
}
