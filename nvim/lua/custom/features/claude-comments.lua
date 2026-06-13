-- Claude-prompt comment-block CRUD. extracted from plugins/claude-prompt.lua.
-- buffer-local <leader>c* keymaps for any markdown file: insert templates,
-- add an exchange inside a <comment> block, toggle resolved state, navigate
-- between blocks, and delete the block under the cursor. setup(bufnr) wires
-- the keymaps; called from the claude-prompt spec's markdown autocmd

local M = {}

--- insert a LuaSnip snippet with smart spacing (blank lines only where needed)
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
      table.insert(new_lines, '') -- line where snippet expands
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

--- set up comment block keymaps (buffer-local)
function M.setup(bufnr)
  local opts = function(desc)
    return { buffer = bufnr, desc = desc }
  end

  -- insert Claude comment template
  vim.keymap.set('n', '<leader>cc', function()
    insert_snippet 'claudecomment'
  end, opts '[C]omment template')

  -- insert Claude user/exchange snippet
  -- if inside a <comment> block, adds a properly indented exchange before </comment>
  -- if outside, uses the standalone snippet with smart spacing
  vim.keymap.set('n', '<leader>cu', function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- check if we're inside a <comment> block
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

    -- detect indentation from existing <user> tags in the block
    local indent = '    '
    for i = comment_start, comment_end do
      local m = lines[i]:match '^(%s*)<user>'
      if m then
        indent = m
        break
      end
    end
    local inner_indent = indent .. '    '

    -- insert new exchange before </comment>
    local new_lines = {
      indent .. '<user>',
      inner_indent,
      indent .. '</user>',
      indent .. '<claude>',
      inner_indent .. '[ claude - reply here ]',
      indent .. '</claude>',
    }
    vim.api.nvim_buf_set_lines(0, comment_end - 1, comment_end - 1, false, new_lines)

    -- position cursor on the user content line and enter insert mode
    local cursor_row = comment_end + 1 -- the inner_indent line (1-indexed)
    vim.api.nvim_win_set_cursor(0, { cursor_row, #inner_indent })
    vim.cmd 'startinsert!'
  end, opts '[U]ser exchange snippet')

  -- toggle <comment> block state (open <-> resolved)
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
  end, opts 'Toggle comment [R]esolved')

  -- navigate to next <comment> block
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
  end, opts 'Next comment block')

  -- navigate to previous <comment> block
  vim.keymap.set('n', '<leader>c[', function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i = cursor_line - 1, 1, -1 do
      if lines[i]:match '<comment%s+state=' then
        -- skip if cursor is inside this block (no </comment> between tag and cursor)
        local closed = false
        for j = i + 1, cursor_line do
          if lines[j]:match '</comment>' then
            closed = true
            break
          end
        end
        if closed then
          vim.api.nvim_win_set_cursor(0, { i, 0 })
          return
        end
      end
    end
    vim.notify('No previous comment block', vim.log.levels.INFO)
  end, opts 'Previous comment block')

  -- delete <comment> block under cursor
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
    -- expand deletion range to include surrounding blank spacing lines.
    -- if both sides have blanks, only consume one to preserve spacing
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
  end, opts '[D]elete comment block')
end

return M
