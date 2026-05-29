-- Readable views for compiled object/library files.
--
-- Opening a `.o`/`.a`/`.dylib`/`.so` normally shows raw binary noise. This
-- intercepts the read and renders a decoded, read-only view instead: the
-- symbol table by default (what you reach for when chasing an undefined-symbol
-- link error), with disassembly and a hex dump a keypress away.
--
--   s  symbols      (nm, demangled)
--   d  disassembly  (otool on macOS, objdump elsewhere)
--   x  hex dump     (xxd; capped for large files)

local M = {}

-- Cap rendered output so opening a large dylib can't lock up the editor.
local MAX_LINES = 50000
local HEX_BYTES = 131072 -- 128 KiB

local function has(bin)
  return vim.fn.executable(bin) == 1
end

--- Build the shell command for a given view, or nil if no tool is available.
local function view_command(view, path)
  local p = vim.fn.shellescape(path)
  if view == 'symbols' then
    if not has 'nm' then
      return nil
    end
    -- c++filt demangles C++/Obj-C++ symbols (e.g. TagLib::FileRef); other
    -- symbols pass through untouched. Swift names stay mostly legible.
    return 'nm ' .. p .. (has 'c++filt' and ' | c++filt' or '')
  elseif view == 'disasm' then
    if has 'otool' then
      return 'otool -tVh ' .. p
    elseif has 'objdump' then
      return 'objdump -d ' .. p
    end
    return nil
  elseif view == 'hex' then
    if not has 'xxd' then
      return nil
    end
    return 'xxd -l ' .. HEX_BYTES .. ' ' .. p
  end
end

--- Collect a header (type + architectures) common to every view.
local function header(path)
  local lines = {}
  if has 'file' then
    local desc = vim.fn.systemlist('file -b ' .. vim.fn.shellescape(path))[1]
    if desc then
      table.insert(lines, desc)
    end
  end
  if has 'lipo' then
    local archs = vim.fn.systemlist('lipo -archs ' .. vim.fn.shellescape(path))
    if vim.v.shell_error == 0 and archs[1] then
      table.insert(lines, 'arch: ' .. table.concat(archs, ' '))
    end
  end
  return lines
end

local function render(buf, path, view)
  local lines = header(path)
  table.insert(lines, ('── %s %s'):format(view, ('─'):rep(48)))
  table.insert(lines, '')

  local cmd = view_command(view, path)
  if not cmd then
    table.insert(lines, ('(%s view unavailable: required tool not found)'):format(view))
  else
    local out = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 and #out == 0 then
      table.insert(lines, '(command failed: ' .. cmd .. ')')
    end
    if #out > MAX_LINES then
      out = vim.list_slice(out, 1, MAX_LINES)
      table.insert(out, ('… truncated at %d lines'):format(MAX_LINES))
    end
    vim.list_extend(lines, out)
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  -- 'asm' gives the disassembly real highlighting; the others read fine plain.
  vim.bo[buf].filetype = (view == 'disasm') and 'asm' or ''
end

function M.setup()
  vim.api.nvim_create_autocmd('BufReadCmd', {
    group = vim.api.nvim_create_augroup('binary-object-view', { clear = true }),
    pattern = { '*.o', '*.a', '*.dylib', '*.so' },
    desc = 'Render object/library files as decoded symbol/disasm/hex views',
    callback = function(ev)
      local path = vim.fn.fnamemodify(ev.match, ':p')
      local buf = ev.buf

      -- nowrite + no swap so the decoded text can never be flushed back over
      -- the binary (the auto-save autocmd also skips non-empty buftypes).
      vim.bo[buf].swapfile = false
      vim.bo[buf].buftype = 'nowrite'
      vim.bo[buf].undolevels = -1

      local function show(view)
        render(buf, path, view)
      end

      for key, view in pairs { s = 'symbols', d = 'disasm', x = 'hex' } do
        vim.keymap.set('n', key, function()
          show(view)
        end, { buffer = buf, desc = 'Object view: ' .. view })
      end

      show 'symbols'
    end,
  })
end

return M
