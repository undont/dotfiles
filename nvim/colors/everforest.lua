-- everforest colourscheme for nvim, coloured from themes/everforest.theme

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'everforest'
vim.o.termguicolors = true

local colors = require('core.palette').load('everforest', {
  -- base colours
  bg_primary = 'GHOSTTY_BACKGROUND',
  fg_primary = 'GHOSTTY_FOREGROUND',
  bg_secondary = 'TMUX_BG_SECONDARY',
  fg_secondary = 'NVIM_COMMENT',
  fg_variable = 'NVIM_FG_VARIABLE',

  -- accents
  purple = 'GHOSTTY_PALETTE_13',
  pink = 'GHOSTTY_PALETTE_9',
  cyan = 'GHOSTTY_PALETTE_14',
  green = 'GHOSTTY_PALETTE_10',
  yellow = 'GHOSTTY_PALETTE_11',
  red = 'GHOSTTY_PALETTE_9',

  -- additional shades
  selection = 'NVIM_SELECTION',
  reference = 'NVIM_REFERENCE',
  comment = 'NVIM_COMMENT',
  line_highlight = 'NVIM_LINE_HIGHLIGHT',
  blue = 'GHOSTTY_PALETTE_12',
  orange = 'NVIM_ORANGE',
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
hl('CursorLineNr', { fg = colors.pink, bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = colors.purple })
hl('MatchParen', { fg = colors.purple, bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = colors.pink })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = colors.pink })
hl('StatusLine', { fg = colors.pink, bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = colors.pink, bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = colors.purple, bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- syntax highlighting (role split per upstream sainnhe/everforest)
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.cyan })
hl('String', { fg = colors.green })
hl('Character', { fg = colors.green })
hl('Number', { fg = colors.purple })
hl('Boolean', { fg = colors.purple })
hl('Float', { fg = colors.purple })
hl('Identifier', { fg = colors.blue })
hl('Function', { fg = colors.green })
hl('Statement', { fg = colors.pink })
hl('Conditional', { fg = colors.pink })
hl('Repeat', { fg = colors.pink })
hl('Label', { fg = colors.orange })
hl('Operator', { fg = colors.orange })
hl('Keyword', { fg = colors.pink })
hl('Exception', { fg = colors.pink })
hl('PreProc', { fg = colors.purple })
hl('Include', { fg = colors.purple })
hl('Define', { fg = colors.purple })
hl('Macro', { fg = colors.cyan })
hl('PreCondit', { fg = colors.purple })
hl('Type', { fg = colors.yellow })
hl('StorageClass', { fg = colors.orange })
hl('Structure', { fg = colors.orange })
hl('Typedef', { fg = colors.pink })
hl('Special', { fg = colors.yellow })
hl('SpecialChar', { fg = colors.yellow })
hl('Tag', { fg = colors.orange })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = colors.purple, bold = true })

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

-- treesitter (role split per upstream sainnhe/everforest)
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = colors.purple })
hl('@variable.parameter', { fg = colors.fg_primary })
hl('@variable.member', { fg = colors.blue })
hl('@constant', { fg = colors.fg_primary })
hl('@constant.builtin', { fg = colors.purple })
hl('@module', { fg = colors.yellow })
hl('@string', { fg = colors.cyan })
hl('@string.escape', { fg = colors.green })
hl('@string.special', { fg = colors.yellow })
hl('@character', { fg = colors.cyan })
hl('@number', { fg = colors.purple })
hl('@boolean', { fg = colors.purple })
hl('@function', { fg = colors.green })
hl('@function.builtin', { fg = colors.green })
hl('@function.call', { fg = colors.green })
hl('@function.macro', { fg = colors.green })
hl('@method', { fg = colors.green })
hl('@method.call', { fg = colors.green })
hl('@constructor', { fg = colors.green })
hl('@keyword', { fg = colors.pink })
hl('@keyword.function', { fg = colors.pink })
hl('@keyword.operator', { fg = colors.orange })
hl('@keyword.return', { fg = colors.pink })
hl('@conditional', { fg = colors.pink })
hl('@repeat', { fg = colors.pink })
hl('@label', { fg = colors.orange })
hl('@operator', { fg = colors.orange })
hl('@exception', { fg = colors.pink })
hl('@type', { fg = colors.yellow })
hl('@type.builtin', { fg = colors.yellow })
hl('@type.qualifier', { fg = colors.orange })
hl('@property', { fg = colors.blue })
hl('@attribute', { fg = colors.purple })
hl('@tag', { fg = colors.orange })
hl('@tag.attribute', { fg = colors.green })
hl('@tag.delimiter', { fg = colors.green })
hl('@punctuation.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = colors.blue })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = colors.purple, bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = colors.cyan })
hl('@markup.raw', { fg = colors.green })

-- Telescope
hl('TelescopeBorder', { fg = colors.pink, bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = colors.purple, bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = colors.purple, bold = true })
hl('TelescopePreviewTitle', { fg = colors.pink, bold = true })
hl('TelescopeResultsTitle', { fg = colors.pink, bold = true })
hl('TelescopeSelection', { fg = colors.pink, bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = colors.purple, bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = colors.selection })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = colors.purple })
hl('NeoTreeGitModified', { fg = colors.orange })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = colors.purple, bold = true })

-- Which-key
hl('WhichKey', { fg = colors.pink })
hl('WhichKeyGroup', { fg = colors.purple })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = colors.pink, bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
