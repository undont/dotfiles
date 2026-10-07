-- go editing helpers: struct tag add/remove (gomodifytags) and iferr block (iferr)

local M = {}

--- resolve a mason-installed binary, falling back to PATH
---@param name string
---@return string|nil
local function bin(name)
  local p = vim.fn.stdpath 'data' .. '/mason/bin/' .. name
  if vim.fn.executable(p) == 1 then
    return p
  end
  if vim.fn.executable(name) == 1 then
    return name
  end
  return nil
end

--- 0-based byte offset of the cursor, matching gomodifytags -offset / iferr -pos
---@return integer
local function cursor_offset()
  return vim.fn.wordcount().cursor_bytes
end

--- guru-style modified archive (path, byte count, content) so the tools see
--- unsaved buffer state rather than what's on disk
---@param bufnr integer
---@param path string
---@return string
local function modified_archive(bufnr, path)
  local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n') .. '\n'
  return path .. '\n' .. #content .. '\n' .. content
end

--- run gomodifytags over the struct under the cursor and apply the result
---@param mod string '-add-tags' | '-remove-tags' | '-clear-tags'
---@param tags string|nil comma-separated tag names (nil for -clear-tags)
local function modify_tags(mod, tags)
  local cmd_bin = bin 'gomodifytags'
  if not cmd_bin then
    vim.notify('gomodifytags not found (install via :Mason)', vim.log.levels.ERROR)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)

  local cmd = { cmd_bin, '-modified', '-file', path, '-offset', tostring(cursor_offset()), '-format', 'json', mod }
  if tags then
    table.insert(cmd, tags)
  end

  local res = vim.system(cmd, { stdin = modified_archive(bufnr, path) }):wait()
  if res.code ~= 0 then
    vim.notify('gomodifytags: ' .. vim.trim(res.stderr or 'failed'), vim.log.levels.ERROR)
    return
  end

  local ok, decoded = pcall(vim.json.decode, res.stdout)
  if not ok or type(decoded) ~= 'table' or not decoded.lines then
    vim.notify('gomodifytags: unexpected output', vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, decoded.start - 1, decoded['end'], false, decoded.lines)
end

--- generate an `if err != nil` block after the cursor line, indented to match
local function iferr()
  local cmd_bin = bin 'iferr'
  if not cmd_bin then
    vim.notify('iferr not found (install via :Mason)', vim.log.levels.ERROR)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n') .. '\n'

  local res = vim.system({ cmd_bin, '-pos', tostring(cursor_offset()) }, { stdin = content }):wait()
  if res.code ~= 0 then
    vim.notify('iferr: ' .. vim.trim(res.stderr or 'failed'), vim.log.levels.ERROR)
    return
  end

  local out = vim.split(res.stdout or '', '\n', { trimempty = true })
  if #out == 0 then
    return
  end

  local indent = vim.api.nvim_get_current_line():match '^%s*' or ''
  for i, line in ipairs(out) do
    out[i] = line == '' and '' or indent .. line
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(bufnr, row, row, false, out)
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('custom-go-helpers', { clear = true }),
    pattern = 'go',
    callback = function(args)
      local function map(lhs, rhs, desc)
        vim.keymap.set('n', lhs, rhs, { buffer = args.buf, desc = 'Go: ' .. desc })
      end

      map('<leader>la', function()
        modify_tags('-add-tags', 'json')
      end, '[A]dd json tags')
      map('<leader>lc', function()
        modify_tags('-clear-tags', nil)
      end, '[C]lear struct tags')
      map('<leader>le', iferr, 'if [E]rr block')

      vim.api.nvim_buf_create_user_command(args.buf, 'GoAddTags', function(o)
        modify_tags('-add-tags', #o.fargs > 0 and table.concat(o.fargs, ',') or 'json')
      end, { nargs = '*', desc = 'Add struct tags (default json)' })

      vim.api.nvim_buf_create_user_command(args.buf, 'GoRmTags', function(o)
        if #o.fargs > 0 then
          modify_tags('-remove-tags', table.concat(o.fargs, ','))
        else
          modify_tags('-clear-tags', nil)
        end
      end, { nargs = '*', desc = 'Remove struct tags (all if no args)' })

      vim.api.nvim_buf_create_user_command(args.buf, 'GoIfErr', iferr, { desc = 'Generate if err != nil block' })
    end,
  })
end

return M
