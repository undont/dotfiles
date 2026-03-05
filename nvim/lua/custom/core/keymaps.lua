-- Core keymaps (non-plugin specific)
-- Plugin-specific keymaps are defined with their plugins

local M = {}

function M.setup()
  -- Clear search highlight
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Build
  vim.keymap.set('n', '<leader>q', function()
    require('custom.core.build').run()
  end, { desc = 'Build project' })

  -- File explorer
  vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>', { desc = 'File [E]xplorer' })

  -- Git UI
  vim.keymap.set('n', '<leader>g', '<cmd>LazyGit<CR>', { desc = 'Lazy[G]it' })

  -- Theme reload
  vim.keymap.set('n', '<leader>tr', function()
    require('custom.core.theme').reload(true)
  end, { desc = '[R]eload theme' })

  -- Shift+Enter → Enter (Ghostty sends Alt+Enter / \x1b\r)
  vim.keymap.set({ 'i', 'n', 'v', 'c' }, '<M-CR>', '<CR>')

  -- Terminal mode escape
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- Window navigation
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Window zoom (toggle via tab)
  vim.keymap.set('n', '<leader>z', function()
    if vim.t.zoomed then
      vim.cmd 'tab close'
    else
      vim.cmd 'tab split'
      vim.t.zoomed = true
    end
  end, { desc = 'Toggle [Z]oom' })

  -- Window resize (small increments)
  vim.keymap.set('n', '<leader>wh', '<cmd>vertical resize -5<CR>', { desc = 'Resize [H] left' })
  vim.keymap.set('n', '<leader>wl', '<cmd>vertical resize +5<CR>', { desc = 'Resize [L] right' })
  vim.keymap.set('n', '<leader>wj', '<cmd>resize -5<CR>', { desc = 'Resize [J] down' })
  vim.keymap.set('n', '<leader>wk', '<cmd>resize +5<CR>', { desc = 'Resize [K] up' })

  -- Window resize (maximise in a direction)
  vim.keymap.set('n', '<leader>wH', '<cmd>vertical resize 1<CR>', { desc = 'Maximise [H] left (shrink width)' })
  vim.keymap.set('n', '<leader>wL', '<cmd>vertical resize 999<CR>', { desc = 'Maximise [L] right (expand width)' })
  vim.keymap.set('n', '<leader>wJ', '<cmd>resize 1<CR>', { desc = 'Maximise [J] down (shrink height)' })
  vim.keymap.set('n', '<leader>wK', '<cmd>resize 999<CR>', { desc = 'Maximise [K] up (expand height)' })

  -- Line navigation: m/M for beginning/end of line, gm for marks
  vim.keymap.set({ 'n', 'v', 'o' }, 'm', '^', { desc = 'First non-blank character' })
  vim.keymap.set({ 'n', 'v', 'o' }, 'M', '$', { desc = 'End of line' })
  vim.keymap.set('n', 'gm', 'm', { desc = 'Set mark' })

  -- macOS-style navigation (Opt+arrows = word, Cmd+arrows = line)
  vim.keymap.set('i', '<M-BS>', '<C-w>', { desc = 'Delete word backward (Opt+Backspace)' })
  vim.keymap.set('i', '<D-BS>', '<C-u>', { desc = 'Delete to beginning of line (Cmd+Backspace)' })
  vim.keymap.set({ 'n', 'v' }, '<M-Right>', 'w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set({ 'n', 'v' }, '<M-Left>', 'b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set({ 'n', 'v' }, '<M-f>', 'w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set({ 'n', 'v' }, '<M-b>', 'b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-Left>', '<C-o>b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-Right>', '<C-o>w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set('i', '<M-b>', '<C-o>b', { desc = 'Move word left (Opt+Left)' })
  vim.keymap.set('i', '<M-f>', '<C-o>w', { desc = 'Move word right (Opt+Right)' })
  vim.keymap.set('i', '<Home>', '<C-o>0', { desc = 'Beginning of line (Cmd+Left)' })
  vim.keymap.set('i', '<End>', '<C-o>$', { desc = 'End of line (Cmd+Right)' })

  -- Helper: insert snippet with smart spacing (blank lines only where needed)
  local function insert_snippet(trigger)
    local ls = require 'luasnip'
    local snippets = ls.get_snippets 'all'
    for _, snip in ipairs(snippets) do
      if snip.trigger == trigger then
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local line_count = vim.api.nvim_buf_line_count(0)
        local cur_line = vim.api.nvim_get_current_line()
        local next_line = row < line_count and vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or nil

        local new_lines = {}
        if cur_line:match '%S' then
          table.insert(new_lines, '') -- blank line before for spacing
        end
        table.insert(new_lines, '') -- line where snippet will expand
        if next_line and next_line:match '%S' then
          table.insert(new_lines, '') -- blank line after for spacing
        end

        vim.api.nvim_buf_set_lines(0, row, row, false, new_lines)
        local snippet_row = row + (cur_line:match '%S' and 2 or 1)
        vim.api.nvim_win_set_cursor(0, { snippet_row, 0 })
        vim.cmd 'undojoin'
        ls.snip_expand(snip)
        return
      end
    end
  end

  -- LuaSnip: Insert Claude comment template
  vim.keymap.set('n', '<leader>cc', function()
    insert_snippet 'claudecomment'
  end, { desc = '[C]omment template' })

  -- LuaSnip: Insert Claude user/exchange snippet
  -- If inside a <comment> block, adds a properly indented exchange before </comment>
  -- If outside, uses the standalone snippet with smart spacing
  vim.keymap.set('n', '<leader>cu', function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- Check if we're inside a <comment> block
    local comment_start, comment_end
    for i = row, 1, -1 do
      if lines[i]:match '<comment%s+state=' then
        comment_start = i
        break
      end
      if lines[i]:match '</comment>' then
        break
      end
    end
    if comment_start then
      for i = comment_start, #lines do
        if lines[i]:match '</comment>' then
          if row <= i then
            comment_end = i
          end
          break
        end
      end
    end

    if not comment_end then
      insert_snippet 'cu'
      return
    end

    -- Detect indentation from existing <user> tags in the block
    local indent = '    '
    for i = comment_start, comment_end do
      local m = lines[i]:match '^(%s*)<user>'
      if m then
        indent = m
        break
      end
    end
    local inner_indent = indent .. '    '

    -- Insert new exchange before </comment>
    local new_lines = {
      indent .. '<user>',
      inner_indent,
      indent .. '</user>',
      indent .. '<claude>',
      inner_indent .. '[ claude - reply here ]',
      indent .. '</claude>',
    }
    vim.api.nvim_buf_set_lines(0, comment_end - 1, comment_end - 1, false, new_lines)

    -- Position cursor on the user content line and enter insert mode
    local cursor_row = comment_end + 1 -- the inner_indent line (1-indexed)
    vim.api.nvim_win_set_cursor(0, { cursor_row, #inner_indent })
    vim.cmd 'startinsert!'
  end, { desc = '[U]ser exchange snippet' })

  -- Toggle <comment> block state (open <-> resolved)
  vim.keymap.set('n', '<leader>cr', function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local comment_line
    for i = cursor_line, 1, -1 do
      if lines[i]:match '<comment%s+state=' then
        comment_line = i
        break
      end
      if i < cursor_line and lines[i]:match '</comment>' then
        break
      end
    end
    if not comment_line then
      vim.notify('No comment block at cursor', vim.log.levels.WARN)
      return
    end
    for i = comment_line, #lines do
      if lines[i]:match '</comment>' then
        if cursor_line > i then
          vim.notify('No comment block at cursor', vim.log.levels.WARN)
          return
        end
        break
      end
    end
    local line = lines[comment_line]
    local new_line
    if line:match 'state="open"' then
      new_line = line:gsub('state="open"', 'state="resolved"')
    elseif line:match 'state="resolved"' then
      new_line = line:gsub('state="resolved"', 'state="open"')
    else
      vim.notify('Unknown comment state', vim.log.levels.WARN)
      return
    end
    vim.api.nvim_buf_set_lines(0, comment_line - 1, comment_line, false, { new_line })
  end, { desc = 'Toggle comment [R]esolved' })

  -- Navigate to next/previous <comment> block
  vim.keymap.set('n', '<leader>c]', function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i = cursor_line + 1, #lines do
      if lines[i]:match '<comment%s+state=' then
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        return
      end
    end
    vim.notify('No next comment block', vim.log.levels.INFO)
  end, { desc = 'Next comment block' })

  vim.keymap.set('n', '<leader>c[', function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i = cursor_line - 1, 1, -1 do
      if lines[i]:match '<comment%s+state=' then
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        return
      end
    end
    vim.notify('No previous comment block', vim.log.levels.INFO)
  end, { desc = 'Previous comment block' })

  -- Delete <comment> block under cursor
  vim.keymap.set('n', '<leader>cd', function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local comment_start
    for i = cursor_line, 1, -1 do
      if lines[i]:match '<comment%s+state=' then
        comment_start = i
        break
      end
      if i < cursor_line and lines[i]:match '</comment>' then
        break
      end
    end
    if not comment_start then
      vim.notify('No comment block at cursor', vim.log.levels.WARN)
      return
    end
    local comment_end
    for i = comment_start, #lines do
      if lines[i]:match '</comment>' then
        if cursor_line > i then
          vim.notify('No comment block at cursor', vim.log.levels.WARN)
          return
        end
        comment_end = i
        break
      end
    end
    if not comment_end then
      vim.notify('No closing </comment> tag found', vim.log.levels.WARN)
      return
    end
    -- Expand deletion range to include surrounding blank spacing lines
    -- If both sides have blanks, only consume one to preserve spacing
    local del_start = comment_start
    local del_end = comment_end
    local blank_above = del_start > 1 and not lines[del_start - 1]:match '%S'
    local blank_below = del_end < #lines and not lines[del_end + 1]:match '%S'
    if blank_above then
      del_start = del_start - 1
    end
    if blank_below and not blank_above then
      del_end = del_end + 1
    end
    vim.api.nvim_buf_set_lines(0, del_start - 1, del_end, false, {})
    local new_line = math.max(1, del_start - 1)
    local line_count = vim.api.nvim_buf_line_count(0)
    vim.api.nvim_win_set_cursor(0, { math.min(new_line, line_count), 0 })
  end, { desc = '[D]elete comment block' })

  -- Refresh: wipe all buffers, restart LSP, re-source config, reset layout
  vim.keymap.set('n', '<leader>lR', function()
    local cur_file = vim.fn.expand '%:p'

    -- Close all splits so the window fills the terminal before wiping buffers
    vim.cmd 'only'

    -- Stop all LSP clients
    vim.lsp.stop_client(vim.lsp.get_clients(), true)

    -- Wipe all buffers (closes diffview, stale scratch buffers, etc.)
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end

    -- Re-source config
    vim.cmd 'source $MYVIMRC'

    -- Reopen the file we were editing and let LSP re-attach
    vim.defer_fn(function()
      if cur_file ~= '' and vim.fn.filereadable(cur_file) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(cur_file))
      end
      -- Equalise any remaining splits to fill the full terminal
      vim.cmd 'wincmd ='
      vim.notify('Neovim refreshed', vim.log.levels.INFO)
    end, 200)
  end, { desc = '[R]efresh Neovim (clear buffers, restart LSP, reset layout)' })

  -- LuaSnip navigation keymaps
  vim.keymap.set({ 'i', 's' }, '<C-k>', function()
    local ls = require 'luasnip'
    if ls.expand_or_jumpable() then
      ls.expand_or_jump()
    end
  end, { desc = 'LuaSnip: Expand or jump to next placeholder' })

  vim.keymap.set({ 'i', 's' }, '<C-j>', function()
    local ls = require 'luasnip'
    if ls.jumpable(-1) then
      ls.jump(-1)
    end
  end, { desc = 'LuaSnip: Jump to previous placeholder' })
end

return M
