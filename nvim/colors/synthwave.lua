-- synthwave colourscheme for nvim, coloured from themes/synthwave.theme
-- cyberpunk vaporwave aesthetic

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'synthwave'
vim.o.termguicolors = true

local colors = require('core.palette').load('synthwave', {
  -- base colours
  bg_primary = 'GHOSTTY_BACKGROUND',
  fg_primary = 'GHOSTTY_FOREGROUND',
  bg_secondary = 'TMUX_BG_SECONDARY',
  fg_secondary = 'GHOSTTY_PALETTE_8',
  fg_variable = 'NVIM_FG_VARIABLE',

  -- accents
  purple = 'TMUX_ACCENT_PURPLE',
  pink = 'GHOSTTY_PALETTE_5',
  cyan = 'GHOSTTY_PALETTE_4',
  green = 'GHOSTTY_PALETTE_2',
  yellow = 'GHOSTTY_PALETTE_3',
  red = 'GHOSTTY_PALETTE_1',

  -- additional shades
  selection = 'NVIM_SELECTION',
  reference = 'NVIM_REFERENCE',
  comment = 'NVIM_COMMENT',
  line_highlight = 'NVIM_LINE_HIGHLIGHT',

  -- bright variants
  bright_cyan = 'GHOSTTY_PALETTE_12',
  bright_pink = 'GHOSTTY_PALETTE_13',
  bright_green = 'GHOSTTY_PALETTE_10',
  bright_purple = 'NVIM_BRIGHT_PURPLE',

  -- syntax roles (mirroring upstream synthwave-vscode)
  neon_cyan = 'NVIM_NEON_CYAN', -- functions, escapes
  neon_yellow = 'NVIM_NEON_YELLOW', -- keywords, operators, attributes
  neon_red = 'NVIM_NEON_RED', -- types, modules, builtins
  neon_orange = 'NVIM_NEON_ORANGE', -- strings
  salmon = 'NVIM_SALMON', -- constants, numbers
  neon_pink = 'NVIM_NEON_PINK', -- variables, properties
  neon_green = 'NVIM_NEON_GREEN', -- tags, preproc
  punct = 'NVIM_PUNCT', -- punctuation
  tree_cursor_line = 'NVIM_TREE_CURSOR_LINE',
})

-- set a highlight group
local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- editor highlights
hl('Normal', { fg = colors.fg_primary, bg = colors.bg_primary })
hl('NormalFloat', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('FloatBorder', { fg = colors.cyan, bg = colors.bg_secondary })
hl('ColorColumn', { bg = colors.line_highlight })
hl('Cursor', { fg = colors.bg_primary, bg = colors.cyan })
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

-- syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.salmon })
hl('String', { fg = colors.neon_orange })
hl('Character', { fg = colors.neon_orange })
hl('Number', { fg = colors.salmon })
hl('Boolean', { fg = colors.salmon })
hl('Float', { fg = colors.salmon })
hl('Identifier', { fg = colors.neon_pink })
hl('Function', { fg = colors.neon_cyan })
hl('Statement', { fg = colors.neon_yellow })
hl('Conditional', { fg = colors.neon_yellow })
hl('Repeat', { fg = colors.neon_yellow })
hl('Label', { fg = colors.neon_yellow })
hl('Operator', { fg = colors.neon_yellow })
hl('Keyword', { fg = colors.neon_yellow })
hl('Exception', { fg = colors.neon_yellow })
hl('PreProc', { fg = colors.neon_green })
hl('Include', { fg = colors.neon_green })
hl('Define', { fg = colors.neon_green })
hl('Macro', { fg = colors.neon_green })
hl('PreCondit', { fg = colors.neon_green })
hl('Type', { fg = colors.neon_red })
hl('StorageClass', { fg = colors.neon_yellow })
hl('Structure', { fg = colors.neon_red })
hl('Typedef', { fg = colors.neon_red })
hl('Special', { fg = colors.neon_cyan })
hl('SpecialChar', { fg = colors.neon_cyan })
hl('Tag', { fg = colors.neon_green })
hl('Delimiter', { fg = colors.punct })
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
hl('@variable.builtin', { fg = colors.neon_red, bold = true })
hl('@variable.parameter', { fg = colors.neon_pink })
hl('@variable.member', { fg = colors.neon_pink })
hl('@constant', { fg = colors.salmon })
hl('@constant.builtin', { fg = colors.salmon })
hl('@module', { fg = colors.neon_red })
hl('@string', { fg = colors.neon_orange })
hl('@string.escape', { fg = colors.neon_cyan })
hl('@string.special', { fg = colors.salmon })
hl('@character', { fg = colors.neon_orange })
hl('@number', { fg = colors.salmon })
hl('@boolean', { fg = colors.salmon })
hl('@function', { fg = colors.neon_cyan })
hl('@function.builtin', { fg = colors.neon_cyan })
hl('@function.call', { fg = colors.neon_cyan })
hl('@function.macro', { fg = colors.neon_green })
hl('@method', { fg = colors.neon_cyan })
hl('@method.call', { fg = colors.neon_cyan })
hl('@constructor', { fg = colors.neon_red })
hl('@keyword', { fg = colors.neon_yellow })
hl('@keyword.function', { fg = colors.neon_yellow })
hl('@keyword.operator', { fg = colors.neon_yellow })
hl('@keyword.return', { fg = colors.neon_yellow })
hl('@conditional', { fg = colors.neon_yellow })
hl('@repeat', { fg = colors.neon_yellow })
hl('@label', { fg = colors.neon_yellow })
hl('@operator', { fg = colors.neon_yellow })
hl('@exception', { fg = colors.neon_yellow })
hl('@type', { fg = colors.neon_red })
hl('@type.builtin', { fg = colors.neon_red })
hl('@type.qualifier', { fg = colors.neon_yellow })
hl('@property', { fg = colors.neon_pink })
hl('@attribute', { fg = colors.neon_yellow })
hl('@tag', { fg = colors.neon_green })
hl('@tag.attribute', { fg = colors.neon_yellow })
hl('@tag.delimiter', { fg = colors.neon_cyan })
hl('@punctuation.delimiter', { fg = colors.punct })
hl('@punctuation.bracket', { fg = colors.punct })
hl('@punctuation.special', { fg = colors.neon_green })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = colors.pink, bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = colors.cyan })
hl('@markup.raw', { fg = colors.yellow })

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
