-- text-case: `:S` case-aware substitute with inccommand preview

-- fallback order when several cases read the same on the source
local method_priority = {
  'to_snake_case',
  'to_constant_case',
  'to_camel_case',
  'to_pascal_case',
  'to_dash_case',
  'to_title_dash_case',
  'to_dot_case',
  'to_path_case',
  'to_title_case',
  'to_phrase_case',
  'to_lower_phrase_case',
  'to_upper_phrase_case',
  'to_comma_case',
  'to_lower_case',
  'to_upper_case',
}

---@param method { method_name: string, apply: fun(s: string): string }
---@param dest string
---@return integer
local function rank(method, dest)
  local index = #method_priority + 1
  for i, name in ipairs(method_priority) do
    if name == method.method_name then
      index = i
    end
  end
  if dest ~= '' and method.apply(dest) == dest then
    return index
  end
  return index + #method_priority + 1
end

-- one method per distinct form of the source. upstream keeps whichever
-- `pairs()` visits last, so `setup` could come out as comma case; this
-- prefers the case `dest` is typed in, then `method_priority`
---@param methods table<string, { method_name: string, apply: fun(s: string): string }>
---@param source string
---@param dest string
---@return table<string, { method_name: string, apply: fun(s: string): string }>
local function methods_for(methods, source, dest)
  local by_form = {}
  for _, method in pairs(methods) do
    local form = method.apply(source)
    local current = by_form[form]
    if not current or rank(method, dest) < rank(current, dest) then
      by_form[form] = method
    end
  end
  local chosen = {}
  for _, method in pairs(by_form) do
    chosen[method.method_name] = method
  end
  return chosen
end

---@class PreviewMatch
---@field row integer 0-based
---@field col integer
---@field end_col integer
---@field hl_group string

---@param ns integer
---@return PreviewMatch[]
local function preview_matches(ns)
  local matches = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    local details = mark[4]
    if details then
      table.insert(matches, { row = mark[2], col = mark[3], end_col = details.end_col, hl_group = details.hl_group })
    end
  end
  return matches
end

-- the `:s` rule: the split opens unless the range is only the cursor line
---@param opts vim.api.keyset.create_user_command.command_args
---@param cursor_lnum integer
---@return boolean
local function wants_split(opts, cursor_lnum)
  return opts.line1 ~= cursor_lnum or opts.line2 ~= cursor_lnum
end

-- the first 'cmdwinheight' matched rows, the same cap as the `:s` preview
---@param matches PreviewMatch[]
---@return integer[]
local function listed_rows(matches)
  local rows, seen = {}, {}
  for _, match in ipairs(matches) do
    if #rows == vim.o.cmdwinheight then
      break
    end
    if not seen[match.row] then
      seen[match.row] = true
      table.insert(rows, match.row)
    end
  end
  return rows
end

-- lists each matched line as `|lnum| text` with its matches highlighted,
-- the same layout as the `:s` preview window
---@param preview_buf integer
---@param ns integer
---@param matches PreviewMatch[]
local function fill_preview(preview_buf, ns, matches)
  local rows = listed_rows(matches)
  if #rows == 0 then
    return
  end
  local width = #tostring(rows[#rows] + 1)
  local lines, line_index = {}, {}
  for i, row in ipairs(rows) do
    local text = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
    lines[i] = ('|%' .. width .. 'd| %s'):format(row + 1, text)
    line_index[row] = i - 1
  end
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

  local prefix = width + 3
  for _, match in ipairs(matches) do
    local index = line_index[match.row]
    if index then
      vim.hl.range(preview_buf, ns, match.hl_group, { index, prefix + match.col }, { index, prefix + match.end_col })
    end
  end
end

return {
  {
    'johmsalas/text-case.nvim',
    event = 'VeryLazy',
    config = function()
      require('textcase').setup { default_keymappings_enabled = false }

      -- upstream writes the preview into the inccommand split's scratch buffer
      -- instead of the current one (johmsalas/text-case.nvim#178), so `:S`
      -- edits the current buffer and fills the split the way `:s` does
      local substitute = require 'strings.substitute.methods'

      ---@param opts vim.api.keyset.create_user_command.command_args
      ---@param ns integer?
      local function run(opts, ns)
        local params = vim.split(opts.args, '/')
        local source, dest = params[2], params[3] or ''
        if not source or source == '' then
          return
        end
        local all = substitute.state.methods_by_method_name
        substitute.state.methods_by_method_name = methods_for(all, source, dest)
        local ok, err = pcall(substitute.incremental_substitute, opts, ns, nil)
        substitute.state.methods_by_method_name = all
        if not ok then
          error(err)
        end
      end

      vim.api.nvim_create_user_command('S', function(opts)
        run(opts, nil)
      end, {
        nargs = '?',
        range = '%',
        addr = 'lines',
        preview = function(opts, ns, preview_buf)
          if opts.args == '' then
            return 0
          end
          local cursor_lnum = vim.fn.line '.'
          run(opts, ns)
          if not preview_buf or not wants_split(opts, cursor_lnum) then
            return 1
          end
          fill_preview(preview_buf, ns, preview_matches(ns))
          return 2
        end,
      })
    end,
  },
}
