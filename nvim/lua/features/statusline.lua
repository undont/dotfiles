-- mini.statusline content + section overrides. setup() requires the
-- mini.statusline singleton itself so lua_ls keeps the library's section_*
-- signatures

local M = {}

-- neotest's diagnostic namespace, resolved by name so neotest isn't loaded
local neotest_ns = vim.api.nvim_create_namespace 'neotest'

-- a language server with the definition capability is attached to the current
-- buffer. copilot, stylua and tailwindcss attach without it
local function lsp_attached()
  return #vim.lsp.get_clients { bufnr = 0, method = 'textDocument/definition' } > 0
end

-- modified/readonly flag suffix, shared by the active content closure and the
-- inactive section_filename override
local function flags()
  return (vim.bo.modified and ' [+]' or '') .. (vim.bo.readonly and ' [RO]' or '')
end

-- an empty section returns nothing, so it leaves no gap
local function block(text, group)
  if text == '' then
    return ''
  end
  return string.format('%%#%s# %s ', group, text)
end

-- display width of a statusline-formatted string, excluding highlight
-- escapes (%#Name#) and structural items (%<, %=, %*)
local function sl_width(s)
  s = s:gsub('%%#[^#]*#', ''):gsub('%%[<=*]', ''):gsub('%%%%', '%%')
  return vim.fn.strdisplaywidth(s)
end

-- path relative to the git root, ~-relative outside a repo. the root is
-- cached per buffer (false = looked up, none found)
local function project_relative_path()
  local full = vim.fn.expand '%:p'
  if full == '' then
    return vim.fn.expand '%:t'
  end
  local root = vim.b._sl_git_root
  if root == nil then
    root = vim.fs.root(full, '.git') or false
    vim.b._sl_git_root = root
  end
  if root and full:sub(1, #root + 1) == root .. '/' then
    return full:sub(#root + 2)
  end
  local home = vim.uv.os_homedir()
  if home and full:sub(1, #home) == home then
    return '~' .. full:sub(#home + 1)
  end
  return full
end

-- section colours derived from groups the active theme defines. the git
-- branch gets a solid background block; diff counts and diagnostics are
-- foreground only (StatusLine.bg == Devinfo.bg in every theme)
local function derive_statusline_hl()
  local function get(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false })
  end
  local function fg(name)
    return get(name).fg
  end

  -- the mode block's fg is bg_primary in every theme and survives
  -- transparency stripping
  local accent = fg 'Type' or fg 'Function'
  local dark = get('MiniStatuslineModeNormal').fg
  vim.api.nvim_set_hl(0, 'MiniStatuslineBranch', { fg = dark, bg = accent, bold = true })

  local groups = {
    MiniStatuslineDiffAdd = fg 'GitSignsAdd' or fg 'DiffAdd',
    MiniStatuslineDiffChange = fg 'GitSignsChange' or fg 'DiffChange',
    MiniStatuslineDiffDelete = fg 'GitSignsDelete' or fg 'DiffDelete',
    MiniStatuslineDiagError = fg 'DiagnosticError',
    MiniStatuslineDiagWarn = fg 'DiagnosticWarn',
    MiniStatuslineDiagInfo = fg 'DiagnosticInfo',
    MiniStatuslineDiagHint = fg 'DiagnosticHint',
    MiniStatuslineTestFail = fg 'NeotestFailed' or fg 'DiagnosticError',
    MiniStatuslineLspOk = fg 'DiagnosticOk' or fg 'GitSignsAdd',
  }
  for name, colour in pairs(groups) do
    vim.api.nvim_set_hl(0, name, { fg = colour })
  end
end

function M.setup()
  local statusline = require 'mini.statusline'

  statusline.setup {
    use_icons = vim.g.have_nerd_font,
    content = {
      -- mini's default active content plus a macro recording indicator:
      -- cmdheight=0 and ui2 hide the native "recording @a" message
      active = function()
        local mode, mode_hl = statusline.section_mode { trunc_width = 120 }
        local macro = vim.fn.reg_recording()
        local git = statusline.section_git { trunc_width = 40 }
        local diff = statusline.section_diff { trunc_width = 75 }
        local diagnostics = statusline.section_diagnostics { trunc_width = 75 }
        local fileinfo = statusline.section_fileinfo { trunc_width = 120 }
        local location = statusline.section_location { trunc_width = 75 }
        local search = statusline.section_searchcount { trunc_width = 75 }

        local changes = table.concat(
          vim.tbl_filter(function(s)
            return s ~= ''
          end, { diff, diagnostics }),
          ' '
        )

        local loc = table.concat(
          vim.tbl_filter(function(s)
            return s ~= ''
          end, { search, location }),
          ' '
        )

        local left = table.concat {
          block(mode, mode_hl),
          macro ~= '' and block('● @' .. macro, 'MiniStatuslineModeReplace') or '',
          block(git, 'MiniStatuslineBranch'),
          block(changes, 'MiniStatuslineDevinfo'),
        }
        local right = table.concat {
          block(fileinfo, 'MiniStatuslineFileinfo'),
          block(loc, mode_hl),
        }

        -- the project-relative path is shown in full while it fits; past the
        -- budget, parent dirs collapse to initials. the budget is the window
        -- width (laststatus=2) minus every other section, this block's padding
        -- and the flags
        local filename
        if vim.bo.buftype == 'terminal' then
          filename = '%t'
        else
          local fl = flags()
          local path = project_relative_path()
          local width = vim.api.nvim_win_get_width(vim.g.statusline_winid or 0)
          local budget = math.max(12, width - sl_width(left) - sl_width(right) - sl_width(fl) - 2)
          if vim.fn.strdisplaywidth(path) > budget then
            path = vim.fn.pathshorten(path)
          end
          filename = path .. fl
        end

        -- the filename group is set again before %= so the gap fills neutral
        -- when the filename section is empty (qf, [No Name], terminal)
        return left .. '%<' .. block(filename, 'MiniStatuslineFilename') .. '%#MiniStatuslineFilename#%=' .. right
      end,
    },
  }

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('mini-statusline-colours', { clear = true }),
    callback = derive_statusline_hl,
  })
  derive_statusline_hl()

  vim.api.nvim_create_autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
    group = vim.api.nvim_create_augroup('mini-statusline-macro', { clear = true }),
    callback = function()
      vim.cmd.redrawstatus()
    end,
  })

  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_location = function()
    local loc = '%2l:%-2v'
    if vim.t.zoomed then
      loc = loc .. ' Z'
    end
    return loc
  end

  -- inactive windows only; the active line builds its own path
  ---@diagnostic disable-next-line: duplicate-set-field, unused-local
  statusline.section_filename = function(args)
    if vim.bo.buftype == 'terminal' then
      return '%t'
    end
    return project_relative_path() .. flags()
  end

  -- compact diff (+N, ~N, -N), each count coloured inline
  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_diff = function(args)
    if statusline.is_truncated(args.trunc_width) then
      return ''
    end
    local s = vim.b.gitsigns_status_dict
    if not s then
      return ''
    end
    local parts = {}
    if (s.added or 0) > 0 then
      table.insert(parts, '%#MiniStatuslineDiffAdd#+' .. s.added)
    end
    if (s.changed or 0) > 0 then
      table.insert(parts, '%#MiniStatuslineDiffChange#~' .. s.changed)
    end
    if (s.removed or 0) > 0 then
      table.insert(parts, '%#MiniStatuslineDiffDelete#-' .. s.removed)
    end
    if #parts == 0 then
      return ''
    end
    return table.concat(parts, ' ') .. '%#MiniStatuslineDevinfo#'
  end

  -- per-severity diagnostic counts (E/W/I/H), each coloured inline
  local diag_specs = {
    { vim.diagnostic.severity.ERROR, 'MiniStatuslineDiagError', 'E' },
    { vim.diagnostic.severity.WARN, 'MiniStatuslineDiagWarn', 'W' },
    { vim.diagnostic.severity.INFO, 'MiniStatuslineDiagInfo', 'I' },
    { vim.diagnostic.severity.HINT, 'MiniStatuslineDiagHint', 'H' },
  }
  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_diagnostics = function(args)
    if statusline.is_truncated(args.trunc_width) or vim.diagnostic.count == nil then
      return ''
    end
    local counts = vim.diagnostic.count(0)
    -- neotest publishes failed tests into its own namespace as ERROR
    -- diagnostics. they are subtracted from E/W/I/H and counted under ✗
    local tests = vim.diagnostic.count(0, { namespace = neotest_ns })
    local parts = {}
    for _, spec in ipairs(diag_specs) do
      local n = (counts[spec[1]] or 0) - (tests[spec[1]] or 0)
      if n > 0 then
        table.insert(parts, string.format('%%#%s#%s%d', spec[2], spec[3], n))
      end
    end
    local failed = 0
    for _, n in pairs(tests) do
      failed = failed + n
    end
    if failed > 0 then
      table.insert(parts, string.format('%%#MiniStatuslineTestFail#✗%d', failed))
    end
    if #parts == 0 then
      return ''
    end
    return table.concat(parts, ' ') .. '%#MiniStatuslineDevinfo#'
  end

  -- display names; the icon is looked up by the real filetype
  local ft_display = { cs = 'csharp' }

  -- mini's default format with the filetype glyph tinted by its mini.icons
  -- highlight group; the text stays neutral
  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_fileinfo = function(args)
    -- differ diff buffers have the private `differdiff` filetype and keep the
    -- source filetype in b:differ_filetype. the var is read directly: a
    -- require('differ...') would load the lazy plugin
    local differ_ft = vim.b.differ_filetype
    local ft = (type(differ_ft) == 'string' and differ_ft ~= '') and differ_ft or vim.bo.filetype
    if ft == '' then
      return ''
    end
    local label = ft_display[ft] or ft
    -- lsp tick, redrawn by mini.statusline's own LspAttach/LspDetach tracking
    local lsp = lsp_attached() and ' %#MiniStatuslineLspOk#✓%#MiniStatuslineFileinfo#' or ''
    local icon = ''
    if vim.g.have_nerd_font and _G.MiniIcons ~= nil then
      local glyph, hl = MiniIcons.get('filetype', ft)
      if glyph and glyph ~= '' then
        icon = string.format('%%#%s#%s%%#MiniStatuslineFileinfo# ', hl, glyph)
      end
    end
    if statusline.is_truncated(args.trunc_width) or vim.bo.buftype ~= '' then
      return icon .. label .. lsp
    end
    -- encoding and line-ending are shown only when they differ from utf-8/unix
    local parts = { label .. lsp }
    local encoding = vim.bo.fileencoding ~= '' and vim.bo.fileencoding or vim.o.encoding
    if encoding ~= '' and encoding ~= 'utf-8' then
      table.insert(parts, encoding)
    end
    local format = vim.bo.fileformat
    if format ~= '' and format ~= 'unix' then
      table.insert(parts, '[' .. format .. ']')
    end
    local bytes = math.max(vim.fn.line2byte(vim.fn.line '$' + 1) - 1, 0)
    if bytes < 1024 then
      table.insert(parts, string.format('%dB', bytes))
    elseif bytes < 1048576 then
      table.insert(parts, string.format('%.2fKiB', bytes / 1024))
    else
      table.insert(parts, string.format('%.2fMiB', bytes / 1048576))
    end
    return icon .. table.concat(parts, ' ')
  end

  -- truncate branch name to ticket ID (e.g. "feature/ACME-123-some-desc" -> "ACME-123")
  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_git = function(args)
    if statusline.is_truncated(args.trunc_width) then
      return ''
    end
    local head = vim.b.gitsigns_head or ''
    if head == '' then
      return ''
    end
    local ticket = head:match '[A-Z]+-[0-9]+'
    local branch = ticket or head
    local icon = vim.g.have_nerd_font and (MiniIcons.get('os', 'git') .. ' ') or 'Git: '
    return icon .. branch
  end
end

return M
