-- Tokyo Night colourscheme for nvim
-- matches the dotfiles tokyonight-night.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'tokyonight-night'
vim.o.termguicolors = true

-- theme colours (matching themes/tokyonight-night.theme)
local colors = {
  -- base colours
  bg_primary = '#1a1b26',
  fg_primary = '#c0caf5',
  bg_secondary = '#24283b',
  fg_secondary = '#565f89',
  fg_variable = '#a6afda',

  -- accents
  purple = '#bb9af7',
  pink = '#ff007c',
  cyan = '#7dcfff',
  green = '#9ece6a',
  yellow = '#e0af68',
  red = '#f7768e',

  -- additional shades
  selection = '#283457',
  comment = '#565f89',
  line_highlight = '#1e2030',
  blue = '#7aa2f7',
  orange = '#ff9e64',

  -- syntax roles (mirroring upstream tokyonight night)
  blue1 = '#2ac3de', -- types, specials
  blue5 = '#89ddff', -- operators, punctuation
  green1 = '#73daca', -- properties, members
  fg_dark = '#a9b1d6', -- brackets
  deep_purple = '#9d7cd8', -- keywords (upstream purple; the purple slot above holds upstream magenta)
}

-- helper to set highlight groups
local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- editor highlights
hl('Normal', { fg = colors.fg_primary, bg = colors.bg_primary })
hl('NormalFloat', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('FloatBorder', { fg = colors.cyan, bg = colors.bg_secondary })
hl('ColorColumn', { bg = colors.line_highlight })
hl('Cursor', { fg = colors.bg_primary, bg = colors.fg_primary })
hl('CursorLine', { bg = colors.line_highlight })
hl('CursorLineNr', { fg = '#bb9af7', bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = '#ff007c' })
hl('MatchParen', { fg = '#ff007c', bold = true })
hl('Question', { fg = colors.cyan })
hl('ModeMsg', { fg = colors.green, bold = true })
hl('MoreMsg', { fg = colors.green })
hl('ErrorMsg', { fg = colors.red, bold = true })
hl('WarningMsg', { fg = colors.yellow })
hl('VertSplit', { fg = colors.bg_secondary })
hl('WinSeparator', { fg = colors.bg_secondary })
hl('Folded', { fg = colors.comment, bg = colors.line_highlight })
hl('FoldColumn', { fg = colors.comment })
hl('Pmenu', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('PmenuSel', { fg = colors.bg_primary, bg = '#bb9af7' })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = '#bb9af7' })
hl('StatusLine', { fg = '#bb9af7', bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = '#bb9af7', bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = '#ff007c', bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.orange })
hl('String', { fg = '#9ece6a' })
hl('Character', { fg = '#9ece6a' })
hl('Number', { fg = colors.orange })
hl('Boolean', { fg = colors.orange })
hl('Float', { fg = colors.orange })
hl('Identifier', { fg = '#bb9af7' })
hl('Function', { fg = colors.blue })
hl('Statement', { fg = '#bb9af7' })
hl('Conditional', { fg = '#bb9af7' })
hl('Repeat', { fg = '#bb9af7' })
hl('Label', { fg = '#bb9af7' })
hl('Operator', { fg = colors.blue5 })
hl('Keyword', { fg = '#7dcfff' })
hl('Exception', { fg = '#bb9af7' })
hl('PreProc', { fg = '#7dcfff' })
hl('Include', { fg = '#7dcfff' })
hl('Define', { fg = '#7dcfff' })
hl('Macro', { fg = '#7dcfff' })
hl('PreCondit', { fg = '#7dcfff' })
hl('Type', { fg = colors.blue1 })
hl('StorageClass', { fg = colors.blue1 })
hl('Structure', { fg = colors.blue1 })
hl('Typedef', { fg = colors.blue1 })
hl('Special', { fg = colors.blue1 })
hl('SpecialChar', { fg = colors.blue1 })
hl('Tag', { fg = colors.blue1 })
hl('Delimiter', { fg = colors.blue1 })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#ff007c', bold = true })

-- git signs
hl('GitSignsAdd', { fg = colors.green })
hl('GitSignsChange', { fg = colors.yellow })
hl('GitSignsDelete', { fg = colors.red })
hl('GitSignsTopdelete', { fg = colors.red })
hl('GitSignsChangedelete', { fg = colors.orange or colors.yellow })

-- diagnostics
hl('DiagnosticError', { fg = colors.red })
hl('DiagnosticWarn', { fg = colors.yellow })
hl('DiagnosticInfo', { fg = colors.cyan })
hl('DiagnosticHint', { fg = colors.purple })
hl('DiagnosticUnderlineError', { undercurl = true, sp = colors.red })
hl('DiagnosticUnderlineWarn', { undercurl = true, sp = colors.yellow })
hl('DiagnosticUnderlineInfo', { undercurl = true, sp = colors.cyan })
hl('DiagnosticUnderlineHint', { undercurl = true, sp = colors.purple })

-- LSP
hl('LspReferenceText', { bg = colors.selection })
hl('LspReferenceRead', { bg = colors.selection })
hl('LspReferenceWrite', { bg = colors.selection })

-- treesitter
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = colors.red })
hl('@variable.parameter', { fg = colors.yellow })
hl('@variable.member', { fg = colors.green1 })
hl('@constant', { fg = colors.orange })
hl('@constant.builtin', { fg = colors.blue1 })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#9ece6a' })
hl('@string.escape', { fg = '#bb9af7' })
hl('@string.special', { fg = colors.blue1 })
hl('@character', { fg = '#9ece6a' })
hl('@number', { fg = colors.orange })
hl('@boolean', { fg = colors.orange })
hl('@function', { fg = colors.blue })
hl('@function.builtin', { fg = colors.blue1 })
hl('@function.call', { fg = colors.blue })
hl('@function.macro', { fg = '#7dcfff' })
hl('@method', { fg = colors.blue })
hl('@method.call', { fg = colors.blue })
hl('@constructor', { fg = '#bb9af7' })
hl('@keyword', { fg = colors.deep_purple })
hl('@keyword.function', { fg = '#bb9af7' })
hl('@keyword.operator', { fg = colors.blue5 })
hl('@keyword.return', { fg = colors.deep_purple })
hl('@conditional', { fg = '#bb9af7' })
hl('@repeat', { fg = '#bb9af7' })
hl('@label', { fg = colors.blue })
hl('@operator', { fg = colors.blue5 })
hl('@exception', { fg = '#bb9af7' })
hl('@type', { fg = colors.blue1 })
hl('@type.builtin', { fg = colors.blue1 })
hl('@type.qualifier', { fg = colors.deep_purple })
hl('@property', { fg = colors.green1 })
hl('@attribute', { fg = '#7dcfff' })
hl('@tag', { fg = '#bb9af7' })
hl('@tag.attribute', { fg = colors.green1 })
hl('@tag.delimiter', { fg = colors.blue1 })
hl('@punctuation.delimiter', { fg = colors.blue5 })
hl('@punctuation.bracket', { fg = colors.fg_dark })
hl('@punctuation.special', { fg = colors.blue5 })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = '#ff007c', bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#7dcfff' })
hl('@markup.raw', { fg = '#9ece6a' })

-- Telescope
hl('TelescopeBorder', { fg = '#bb9af7', bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = '#ff007c', bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = '#ff007c', bold = true })
hl('TelescopePreviewTitle', { fg = '#bb9af7', bold = true })
hl('TelescopeResultsTitle', { fg = '#bb9af7', bold = true })
hl('TelescopeSelection', { fg = '#bb9af7', bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = '#ff007c', bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = '#444858' })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = '#ff007c' })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = '#ff007c', bold = true })

-- Which-key
hl('WhichKey', { fg = '#bb9af7' })
hl('WhichKeyGroup', { fg = '#ff007c' })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = '#bb9af7', bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
