-- tokyonight-night colourscheme for nvim, coloured from themes/tokyo-night.theme

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'tokyonight-night'
vim.o.termguicolors = true

local colors = require('core.palette').load('tokyo-night', {
  -- base colours
  bg_primary = 'GHOSTTY_BACKGROUND',
  fg_primary = 'GHOSTTY_FOREGROUND',
  bg_secondary = 'TMUX_BG_SECONDARY',
  fg_secondary = 'NVIM_COMMENT',
  fg_variable = 'NVIM_FG_VARIABLE',

  -- accents
  purple = 'GHOSTTY_PALETTE_5',
  pink = 'NVIM_PINK',
  cyan = 'GHOSTTY_PALETTE_6',
  green = 'GHOSTTY_PALETTE_2',
  yellow = 'GHOSTTY_PALETTE_3',
  red = 'GHOSTTY_PALETTE_1',

  -- additional shades
  selection = 'NVIM_SELECTION',
  reference = 'NVIM_REFERENCE',
  comment = 'NVIM_COMMENT',
  line_highlight = 'NVIM_LINE_HIGHLIGHT',
  blue = 'GHOSTTY_PALETTE_4',
  orange = 'NVIM_ORANGE',

  -- syntax roles (mirroring upstream tokyonight night)
  blue1 = 'NVIM_BLUE1', -- types, specials
  blue5 = 'NVIM_BLUE5', -- operators, punctuation
  green1 = 'NVIM_GREEN1', -- properties, members
  fg_dark = 'GHOSTTY_PALETTE_7', -- brackets
  deep_purple = 'NVIM_DEEP_PURPLE', -- keywords (upstream purple; the purple slot above holds upstream magenta)
  tree_cursor_line = 'NVIM_TREE_CURSOR_LINE',
})

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
hl('Constant', { fg = colors.orange })
hl('String', { fg = colors.green })
hl('Character', { fg = colors.green })
hl('Number', { fg = colors.orange })
hl('Boolean', { fg = colors.orange })
hl('Float', { fg = colors.orange })
hl('Identifier', { fg = colors.purple })
hl('Function', { fg = colors.blue })
hl('Statement', { fg = colors.purple })
hl('Conditional', { fg = colors.purple })
hl('Repeat', { fg = colors.purple })
hl('Label', { fg = colors.purple })
hl('Operator', { fg = colors.blue5 })
hl('Keyword', { fg = colors.cyan })
hl('Exception', { fg = colors.purple })
hl('PreProc', { fg = colors.cyan })
hl('Include', { fg = colors.cyan })
hl('Define', { fg = colors.cyan })
hl('Macro', { fg = colors.cyan })
hl('PreCondit', { fg = colors.cyan })
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
hl('@variable.parameter', { fg = colors.yellow })
hl('@variable.member', { fg = colors.green1 })
hl('@constant', { fg = colors.orange })
hl('@constant.builtin', { fg = colors.blue1 })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = colors.green })
hl('@string.escape', { fg = colors.purple })
hl('@string.special', { fg = colors.blue1 })
hl('@character', { fg = colors.green })
hl('@number', { fg = colors.orange })
hl('@boolean', { fg = colors.orange })
hl('@function', { fg = colors.blue })
hl('@function.builtin', { fg = colors.blue1 })
hl('@function.call', { fg = colors.blue })
hl('@function.macro', { fg = colors.cyan })
hl('@method', { fg = colors.blue })
hl('@method.call', { fg = colors.blue })
hl('@constructor', { fg = colors.purple })
hl('@keyword', { fg = colors.deep_purple })
hl('@keyword.function', { fg = colors.purple })
hl('@keyword.operator', { fg = colors.blue5 })
hl('@keyword.return', { fg = colors.deep_purple })
hl('@conditional', { fg = colors.purple })
hl('@repeat', { fg = colors.purple })
hl('@label', { fg = colors.blue })
hl('@operator', { fg = colors.blue5 })
hl('@exception', { fg = colors.purple })
hl('@type', { fg = colors.blue1 })
hl('@type.builtin', { fg = colors.blue1 })
hl('@type.qualifier', { fg = colors.deep_purple })
hl('@property', { fg = colors.green1 })
hl('@attribute', { fg = colors.cyan })
hl('@tag', { fg = colors.purple })
hl('@tag.attribute', { fg = colors.green1 })
hl('@tag.delimiter', { fg = colors.blue1 })
hl('@punctuation.delimiter', { fg = colors.blue5 })
hl('@punctuation.bracket', { fg = colors.fg_dark })
hl('@punctuation.special', { fg = colors.blue5 })
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
hl('WhichKey', { fg = colors.purple })
hl('WhichKeyGroup', { fg = colors.pink })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
