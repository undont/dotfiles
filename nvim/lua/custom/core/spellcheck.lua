-- Spell autocorrect utilities
-- Provides single-word, line, and buffer-wide autocorrect using Vim's spellsuggest.

local M = {}

--- Apply the first spell suggestion to the misspelled word nearest the cursor.
---@return boolean true if a word was corrected
function M.apply_first_suggestion()
  local bad_word = vim.fn.spellbadword()[1]
  if bad_word == nil or bad_word == '' then
    return false
  end

  local suggestions = vim.fn.spellsuggest(bad_word, 1)
  local replacement = suggestions[1]
  if replacement == nil or replacement == '' then
    return false
  end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local start_col = col + 1
  local finish_col = start_col + #bad_word - 1

  while start_col > 1 and line:sub(start_col, finish_col) ~= bad_word do
    start_col = start_col - 1
    finish_col = start_col + #bad_word - 1
  end

  if line:sub(start_col, finish_col) ~= bad_word then
    start_col = col + 1
    finish_col = start_col + #bad_word - 1
    while finish_col <= #line and line:sub(start_col, finish_col) ~= bad_word do
      start_col = start_col + 1
      finish_col = start_col + #bad_word - 1
    end
  end

  if line:sub(start_col, finish_col) ~= bad_word then
    return false
  end

  vim.api.nvim_buf_set_text(0, row - 1, start_col - 1, row - 1, finish_col, { replacement })
  vim.api.nvim_win_set_cursor(0, { row, start_col - 1 })
  return true
end

--- Autocorrect all misspelled words in a line range.
---@param start_line integer 1-indexed start line
---@param end_line integer 1-indexed end line (inclusive)
---@return integer fixed number of words corrected
function M.autocorrect_range(start_line, end_line)
  local view = vim.fn.winsaveview()
  local wrapscan = vim.o.wrapscan
  local fixed = 0

  vim.o.wrapscan = false
  vim.api.nvim_win_set_cursor(0, { start_line, 0 })

  local prev_row, prev_col = -1, -1
  while true do
    local bad_word = vim.fn.spellbadword()[1]
    if bad_word == nil or bad_word == '' then
      vim.cmd 'keepjumps normal! ]s'
    end

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    if row < start_line or row > end_line then
      break
    end

    -- Guard against cursor not advancing (no more misspellings in range)
    if row == prev_row and col == prev_col then
      break
    end
    prev_row, prev_col = row, col

    bad_word = vim.fn.spellbadword()[1]
    if bad_word ~= nil and bad_word ~= '' then
      if M.apply_first_suggestion() then
        fixed = fixed + 1
      else
        local line = vim.api.nvim_get_current_line()
        local next_col = math.min(#line, col + math.max(#bad_word, 1))
        vim.api.nvim_win_set_cursor(0, { row, next_col })
      end
    else
      break
    end
  end

  vim.fn.winrestview(view)
  vim.o.wrapscan = wrapscan
  return fixed
end

return M
