-- nightfox colourscheme for nvim, coloured from themes/nightfox.theme

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'nightfox'
vim.o.termguicolors = true

local colors = require('core.palette').load('nightfox', {
  -- base colours
  bg_primary = 'GHOSTTY_BACKGROUND',
  fg_primary = 'GHOSTTY_FOREGROUND',
  bg_secondary = 'TMUX_BG_SECONDARY',
  fg_secondary = 'NVIM_COMMENT',
  fg_variable = 'NVIM_FG_VARIABLE',

  -- accents
  purple = 'TMUX_ACCENT_PURPLE',
  pink = 'TMUX_ACCENT_PINK',
  cyan = 'GHOSTTY_PALETTE_2',
  green = 'TMUX_ACCENT_GREEN',
  yellow = 'GHOSTTY_PALETTE_3',
  red = 'NVIM_RED',

  -- additional shades
  selection = 'NVIM_SELECTION',
  reference = 'NVIM_REFERENCE',
  comment = 'NVIM_COMMENT',
  line_highlight = 'NVIM_LINE_HIGHLIGHT',
  blue = 'NVIM_BLUE',
  orange = 'NVIM_ORANGE',

  -- syntax roles (mirroring upstream nightfox.nvim)
  magenta = 'NVIM_MAGENTA', -- keywords
  magenta_bright = 'GHOSTTY_PALETTE_13', -- conditionals, loops
  blue_bright = 'GHOSTTY_PALETTE_12', -- functions
  cyan_base = 'GHOSTTY_PALETTE_6', -- identifiers, constructors
  cyan_bright = 'NVIM_CYAN_BRIGHT', -- builtin types, parameters, modules
  string_green = 'GHOSTTY_PALETTE_2', -- strings
  orange_bright = 'NVIM_ORANGE_BRIGHT', -- constants
  yellow_bright = 'GHOSTTY_PALETTE_11', -- regex, escapes
  pink_bright = 'NVIM_PINK_BRIGHT', -- preproc
  punct = 'NVIM_PUNCT', -- operators, punctuation
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
hl('Cursor', { fg = colors.bg_primary, bg = colors.fg_primary })
hl('CursorLine', { bg = colors.line_highlight })
hl('CursorLineNr', { fg = colors.purple, bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = colors.purple })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = colors.purple })
hl('StatusLine', { fg = colors.purple, bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = colors.purple, bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = colors.pink, bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.orange_bright })
hl('String', { fg = colors.string_green })
hl('Character', { fg = colors.string_green })
hl('Number', { fg = colors.orange })
hl('Boolean', { fg = colors.orange })
hl('Float', { fg = colors.orange })
hl('Identifier', { fg = colors.cyan_base })
hl('Function', { fg = colors.blue_bright })
hl('Statement', { fg = colors.magenta })
hl('Conditional', { fg = colors.magenta_bright })
hl('Repeat', { fg = colors.magenta_bright })
hl('Label', { fg = colors.magenta_bright })
hl('Operator', { fg = colors.punct })
hl('Keyword', { fg = colors.magenta })
hl('Exception', { fg = colors.magenta })
hl('PreProc', { fg = colors.pink_bright })
hl('Include', { fg = colors.pink_bright })
hl('Define', { fg = colors.pink_bright })
hl('Macro', { fg = colors.pink_bright })
hl('PreCondit', { fg = colors.pink_bright })
hl('Type', { fg = colors.yellow })
hl('StorageClass', { fg = colors.yellow })
hl('Structure', { fg = colors.yellow })
hl('Typedef', { fg = colors.yellow })
hl('Special', { fg = colors.blue_bright })
hl('SpecialChar', { fg = colors.blue_bright })
hl('Tag', { fg = colors.blue_bright })
hl('Delimiter', { fg = colors.punct })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = colors.pink, bold = true })

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
hl('LspReferenceText', { bg = colors.reference })
hl('LspReferenceRead', { bg = colors.reference })
hl('LspReferenceWrite', { bg = colors.reference })

-- treesitter
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = colors.red })
hl('@variable.parameter', { fg = colors.cyan_bright })
hl('@variable.member', { fg = colors.blue })
hl('@constant', { fg = colors.orange_bright })
hl('@constant.builtin', { fg = colors.orange_bright })
hl('@module', { fg = colors.cyan_bright })
hl('@string', { fg = colors.string_green })
hl('@string.escape', { fg = colors.yellow_bright, bold = true })
hl('@string.special', { fg = colors.blue_bright })
hl('@character', { fg = colors.string_green })
hl('@number', { fg = colors.orange })
hl('@boolean', { fg = colors.orange })
hl('@function', { fg = colors.blue_bright })
hl('@function.builtin', { fg = colors.red })
hl('@function.call', { fg = colors.blue_bright })
hl('@function.macro', { fg = colors.red })
hl('@method', { fg = colors.blue_bright })
hl('@method.call', { fg = colors.blue_bright })
hl('@constructor', { fg = colors.cyan_base })
hl('@keyword', { fg = colors.magenta })
hl('@keyword.function', { fg = colors.magenta })
hl('@keyword.operator', { fg = colors.punct })
hl('@keyword.return', { fg = colors.red })
hl('@conditional', { fg = colors.magenta_bright })
hl('@repeat', { fg = colors.magenta_bright })
hl('@label', { fg = colors.magenta_bright })
hl('@operator', { fg = colors.punct })
hl('@exception', { fg = colors.magenta })
hl('@type', { fg = colors.yellow })
hl('@type.builtin', { fg = colors.cyan_bright })
hl('@type.qualifier', { fg = colors.magenta })
hl('@property', { fg = colors.blue })
hl('@attribute', { fg = colors.orange_bright })
hl('@tag', { fg = colors.magenta })
hl('@tag.attribute', { fg = colors.blue_bright })
hl('@tag.delimiter', { fg = colors.cyan_bright })
hl('@punctuation.delimiter', { fg = colors.punct })
hl('@punctuation.bracket', { fg = colors.punct })
hl('@punctuation.special', { fg = colors.cyan_bright })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = colors.pink, bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = colors.cyan })
hl('@markup.raw', { fg = colors.green })

-- Telescope
hl('TelescopeBorder', { fg = colors.purple, bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = colors.pink, bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = colors.pink, bold = true })
hl('TelescopePreviewTitle', { fg = colors.purple, bold = true })
hl('TelescopeResultsTitle', { fg = colors.purple, bold = true })
hl('TelescopeSelection', { fg = colors.purple, bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = colors.pink, bold = true })

-- neo-tree
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

-- which-key
hl('WhichKey', { fg = colors.purple })
hl('WhichKeyGroup', { fg = colors.pink })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
