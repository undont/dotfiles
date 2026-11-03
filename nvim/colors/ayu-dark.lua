-- ayu-dark colourscheme for nvim, coloured from themes/ayu-dark.theme

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'ayu-dark'
vim.o.termguicolors = true

local colors = require('core.palette').load('ayu-dark', {
  -- Base colours
  bg_primary = 'GHOSTTY_BACKGROUND',
  fg_primary = 'GHOSTTY_FOREGROUND',
  bg_secondary = 'TMUX_BG_SECONDARY',
  fg_secondary = 'NVIM_COMMENT',
  fg_variable = 'NVIM_FG_VARIABLE',

  -- Accents
  purple = 'TMUX_ACCENT_PURPLE',
  pink = 'GHOSTTY_PALETTE_9',
  cyan = 'TMUX_ACCENT_CYAN',
  green = 'GHOSTTY_PALETTE_10',
  yellow = 'GHOSTTY_PALETTE_11',
  red = 'TMUX_ACCENT_RED',

  -- Additional shades
  selection = 'NVIM_SELECTION',
  reference = 'NVIM_REFERENCE',
  comment = 'NVIM_COMMENT',
  line_highlight = 'NVIM_LINE_HIGHLIGHT',
  orange = 'NVIM_ORANGE',

  -- syntax roles (mirroring upstream neovim-ayu dark)
  entity = 'GHOSTTY_PALETTE_12', -- types, identifiers
  string = 'NVIM_STRING', -- strings
  accent = 'GHOSTTY_CURSOR_COLOR', -- preproc, specials
  special = 'NVIM_SPECIAL', -- delimiters, structure
  operator = 'NVIM_OPERATOR', -- operators
  parameter = 'NVIM_PARAMETER', -- function parameters
  regexp = 'GHOSTTY_PALETTE_14', -- escapes, regex
  tree_cursor_line = 'NVIM_TREE_CURSOR_LINE',
})

-- helper to set highlight groups
local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor highlights
hl('Normal', { fg = colors.fg_primary, bg = colors.bg_primary })
hl('NormalFloat', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('FloatBorder', { fg = colors.cyan, bg = colors.bg_secondary })
hl('ColorColumn', { bg = colors.line_highlight })
hl('Cursor', { fg = colors.bg_primary, bg = colors.fg_primary })
hl('CursorLine', { bg = colors.line_highlight })
hl('CursorLineNr', { fg = colors.cyan, bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = colors.pink })
hl('MatchParen', { fg = colors.pink, bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = colors.cyan })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = colors.cyan })
hl('StatusLine', { fg = colors.cyan, bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = colors.cyan, bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = colors.pink, bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.purple })
hl('String', { fg = colors.string })
hl('Character', { fg = colors.string })
hl('Number', { fg = colors.purple })
hl('Boolean', { fg = colors.purple })
hl('Float', { fg = colors.purple })
hl('Identifier', { fg = colors.entity })
hl('Function', { fg = colors.yellow })
hl('Statement', { fg = colors.orange })
hl('Conditional', { fg = colors.orange })
hl('Repeat', { fg = colors.orange })
hl('Label', { fg = colors.orange })
hl('Operator', { fg = colors.operator })
hl('Keyword', { fg = colors.orange })
hl('Exception', { fg = colors.pink })
hl('PreProc', { fg = colors.accent })
hl('Include', { fg = colors.accent })
hl('Define', { fg = colors.accent })
hl('Macro', { fg = colors.accent })
hl('PreCondit', { fg = colors.accent })
hl('Type', { fg = colors.entity })
hl('StorageClass', { fg = colors.orange })
hl('Structure', { fg = colors.special })
hl('Typedef', { fg = colors.entity })
hl('Special', { fg = colors.accent })
hl('SpecialChar', { fg = colors.regexp })
hl('Tag', { fg = colors.orange })
hl('Delimiter', { fg = colors.special })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = colors.pink, bold = true })

-- Git signs
hl('GitSignsAdd', { fg = colors.green })
hl('GitSignsChange', { fg = colors.yellow })
hl('GitSignsDelete', { fg = colors.red })
hl('GitSignsTopdelete', { fg = colors.red })
hl('GitSignsChangedelete', { fg = colors.orange or colors.yellow })

-- Diagnostics
hl('DiagnosticError', { fg = colors.red })
hl('DiagnosticWarn', { fg = colors.yellow })
hl('DiagnosticInfo', { fg = colors.cyan })
hl('DiagnosticHint', { fg = colors.purple })
hl('DiagnosticUnderlineError', { undercurl = true, sp = colors.red })
hl('DiagnosticUnderlineWarn', { undercurl = true, sp = colors.yellow })
hl('DiagnosticUnderlineInfo', { undercurl = true, sp = colors.cyan })
hl('DiagnosticUnderlineHint', { undercurl = true, sp = colors.purple })

-- LSP
hl('LspReferenceText', { bg = colors.reference })
hl('LspReferenceRead', { bg = colors.reference })
hl('LspReferenceWrite', { bg = colors.reference })

-- Treesitter
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = colors.yellow })
hl('@variable.parameter', { fg = colors.parameter })
hl('@variable.member', { fg = colors.cyan })
hl('@constant', { fg = colors.purple })
hl('@constant.builtin', { fg = colors.purple })
hl('@module', { fg = colors.yellow })
hl('@string', { fg = colors.string })
hl('@string.escape', { fg = colors.regexp })
hl('@string.special', { fg = colors.regexp })
hl('@character', { fg = colors.string })
hl('@number', { fg = colors.purple })
hl('@boolean', { fg = colors.purple })
hl('@function', { fg = colors.yellow })
hl('@function.builtin', { fg = colors.yellow })
hl('@function.call', { fg = colors.yellow })
hl('@function.macro', { fg = colors.accent })
hl('@method', { fg = colors.yellow })
hl('@method.call', { fg = colors.yellow })
hl('@constructor', { fg = colors.accent })
hl('@keyword', { fg = colors.orange })
hl('@keyword.function', { fg = colors.orange })
hl('@keyword.operator', { fg = colors.orange })
hl('@keyword.return', { fg = colors.orange })
hl('@conditional', { fg = colors.orange })
hl('@repeat', { fg = colors.orange })
hl('@label', { fg = colors.orange })
hl('@operator', { fg = colors.operator })
hl('@exception', { fg = colors.pink })
hl('@type', { fg = colors.entity })
hl('@type.builtin', { fg = colors.entity })
hl('@type.qualifier', { fg = colors.orange })
hl('@property', { fg = colors.cyan })
hl('@attribute', { fg = colors.purple })
hl('@tag', { fg = colors.orange })
hl('@tag.attribute', { fg = colors.entity })
hl('@tag.delimiter', { fg = colors.special })
hl('@punctuation.delimiter', { fg = colors.special })
hl('@punctuation.bracket', { fg = colors.special })
hl('@punctuation.special', { fg = colors.accent })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = colors.orange, bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = colors.cyan })
hl('@markup.raw', { fg = colors.string })

-- Telescope
hl('TelescopeBorder', { fg = colors.cyan, bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = colors.pink, bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = colors.pink, bold = true })
hl('TelescopePreviewTitle', { fg = colors.cyan, bold = true })
hl('TelescopeResultsTitle', { fg = colors.cyan, bold = true })
hl('TelescopeSelection', { fg = colors.cyan, bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = colors.pink, bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = colors.tree_cursor_line })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = colors.pink })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = colors.pink, bold = true })

-- Which-key
hl('WhichKey', { fg = colors.cyan })
hl('WhichKeyGroup', { fg = colors.pink })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = colors.cyan, bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
