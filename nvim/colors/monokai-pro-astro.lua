-- monokai-pro-astro colourscheme for nvim, coloured from themes/monokai-pro-astro.theme
-- syntax roles follow upstream monokai pro: red keywords, green functions,
-- cyan types, purple numbers, yellow strings, orange parameters

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'monokai-pro-astro'
vim.o.termguicolors = true

local colors = require('core.palette').load('monokai-pro-astro', {
  bg_primary = 'GHOSTTY_BACKGROUND',
  fg_primary = 'GHOSTTY_FOREGROUND',
  bg_secondary = 'TMUX_BG_SECONDARY',
  fg_secondary = 'TMUX_FG_SECONDARY',
  fg_variable = 'NVIM_FG_VARIABLE',

  red = 'GHOSTTY_PALETTE_1',
  orange = 'GHOSTTY_PALETTE_4',
  yellow = 'GHOSTTY_PALETTE_3',
  green = 'GHOSTTY_PALETTE_2',
  cyan = 'GHOSTTY_PALETTE_6',
  purple = 'GHOSTTY_PALETTE_5',

  selection = 'NVIM_SELECTION',
  reference = 'NVIM_REFERENCE',
  comment = 'GHOSTTY_PALETTE_8',
  line_nr = 'NVIM_LINE_NR',
  ghost = 'NVIM_GHOST',
  line_highlight = 'NVIM_LINE_HIGHLIGHT',
  indent = 'NVIM_INDENT',
  tree_cursor_line = 'NVIM_TREE_CURSOR_LINE',
})

local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- editor highlights
hl('Normal', { fg = colors.fg_primary, bg = colors.bg_primary })
hl('NormalFloat', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('FloatBorder', { fg = colors.comment, bg = colors.bg_secondary })
hl('ColorColumn', { bg = colors.line_highlight })
hl('Cursor', { fg = colors.bg_primary, bg = colors.orange })
hl('CursorLine', { bg = colors.line_highlight })
hl('CursorLineNr', { fg = colors.fg_primary, bold = true })
hl('LineNr', { fg = colors.line_nr })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = colors.orange })
hl('MatchParen', { fg = colors.orange, bold = true })
hl('Question', { fg = colors.cyan })
hl('ModeMsg', { fg = colors.green, bold = true })
hl('MoreMsg', { fg = colors.green })
hl('ErrorMsg', { fg = colors.red, bold = true })
hl('WarningMsg', { fg = colors.orange })
hl('VertSplit', { fg = colors.bg_secondary })
hl('WinSeparator', { fg = colors.bg_secondary })
hl('Folded', { fg = colors.comment, bg = colors.line_highlight })
hl('FoldColumn', { fg = colors.line_nr })
hl('Pmenu', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('PmenuSel', { fg = colors.bg_primary, bg = colors.yellow })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = colors.comment })
hl('StatusLine', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = colors.fg_primary, bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = colors.yellow, bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.ghost })
hl('Whitespace', { fg = colors.indent })

-- syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.purple })
hl('String', { fg = colors.yellow })
hl('Character', { fg = colors.yellow })
hl('Number', { fg = colors.purple })
hl('Boolean', { fg = colors.purple })
hl('Float', { fg = colors.purple })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = colors.green })
hl('Statement', { fg = colors.red })
hl('Conditional', { fg = colors.red })
hl('Repeat', { fg = colors.red })
hl('Label', { fg = colors.red })
hl('Operator', { fg = colors.red })
hl('Keyword', { fg = colors.red })
hl('Exception', { fg = colors.red })
hl('PreProc', { fg = colors.red })
hl('Include', { fg = colors.red })
hl('Define', { fg = colors.red })
hl('Macro', { fg = colors.green })
hl('PreCondit', { fg = colors.red })
hl('Type', { fg = colors.cyan })
hl('StorageClass', { fg = colors.red })
hl('Structure', { fg = colors.cyan })
hl('Typedef', { fg = colors.cyan })
hl('Special', { fg = colors.cyan })
hl('SpecialChar', { fg = colors.purple })
hl('Tag', { fg = colors.red })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = colors.orange, bold = true })

-- git signs
hl('GitSignsAdd', { fg = colors.green })
hl('GitSignsChange', { fg = colors.orange })
hl('GitSignsDelete', { fg = colors.red })
hl('GitSignsTopdelete', { fg = colors.red })
hl('GitSignsChangedelete', { fg = colors.orange })

-- diagnostics
hl('DiagnosticError', { fg = colors.red })
hl('DiagnosticWarn', { fg = colors.orange })
hl('DiagnosticInfo', { fg = colors.cyan })
hl('DiagnosticHint', { fg = colors.purple })
hl('DiagnosticUnderlineError', { undercurl = true, sp = colors.red })
hl('DiagnosticUnderlineWarn', { undercurl = true, sp = colors.orange })
hl('DiagnosticUnderlineInfo', { undercurl = true, sp = colors.cyan })
hl('DiagnosticUnderlineHint', { undercurl = true, sp = colors.purple })

-- LSP
hl('LspReferenceText', { bg = colors.reference })
hl('LspReferenceRead', { bg = colors.reference })
hl('LspReferenceWrite', { bg = colors.reference })

-- treesitter
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = colors.orange })
hl('@variable.parameter', { fg = colors.orange })
hl('@variable.member', { fg = colors.fg_primary })
hl('@constant', { fg = colors.purple })
hl('@constant.builtin', { fg = colors.purple })
hl('@module', { fg = colors.red })
hl('@string', { fg = colors.yellow })
hl('@string.escape', { fg = colors.purple })
hl('@string.regexp', { fg = colors.orange })
hl('@string.special', { fg = colors.purple })
hl('@character', { fg = colors.yellow })
hl('@number', { fg = colors.purple })
hl('@boolean', { fg = colors.purple })
hl('@function', { fg = colors.green })
hl('@function.builtin', { fg = colors.red })
hl('@function.call', { fg = colors.green })
hl('@function.macro', { fg = colors.green })
hl('@method', { fg = colors.green })
hl('@method.call', { fg = colors.green })
hl('@constructor', { fg = colors.cyan })
hl('@keyword', { fg = colors.red })
hl('@keyword.function', { fg = colors.red })
hl('@keyword.operator', { fg = colors.red })
hl('@keyword.return', { fg = colors.red })
hl('@conditional', { fg = colors.red })
hl('@repeat', { fg = colors.red })
hl('@label', { fg = colors.red })
hl('@operator', { fg = colors.fg_primary })
hl('@exception', { fg = colors.red })
hl('@type', { fg = colors.cyan })
hl('@type.builtin', { fg = colors.cyan })
hl('@type.qualifier', { fg = colors.red })
hl('@property', { fg = colors.fg_primary })
hl('@attribute', { fg = colors.cyan })
hl('@tag', { fg = colors.red })
hl('@tag.attribute', { fg = colors.cyan })
hl('@tag.delimiter', { fg = colors.comment })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = colors.red })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = colors.yellow, bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = colors.red })
hl('@markup.raw', { fg = colors.yellow })

-- Telescope
hl('TelescopeBorder', { fg = colors.comment, bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = colors.red, bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = colors.red, bold = true })
hl('TelescopePreviewTitle', { fg = colors.green, bold = true })
hl('TelescopeResultsTitle', { fg = colors.cyan, bold = true })
hl('TelescopeSelection', { fg = colors.yellow, bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = colors.orange, bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = colors.tree_cursor_line })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = colors.green })
hl('NeoTreeGitModified', { fg = colors.orange })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.line_nr })
hl('NeoTreeRootName', { fg = colors.red, bold = true })

-- Which-key
hl('WhichKey', { fg = colors.cyan })
hl('WhichKeyGroup', { fg = colors.red })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.cyan, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.orange, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })

-- Copilot
hl('CopilotSuggestion', { fg = colors.ghost, italic = true })

-- indent-blankline
hl('IblIndent', { fg = colors.indent })
hl('IblScope', { fg = colors.cyan })

-- Neotest
hl('NeotestPassed', { fg = colors.green })
hl('NeotestFailed', { fg = colors.red })
hl('NeotestRunning', { fg = colors.yellow })
hl('NeotestSkipped', { fg = colors.comment })
hl('NeotestTest', { fg = colors.fg_primary })
hl('NeotestNamespace', { fg = colors.cyan })
hl('NeotestFile', { fg = colors.cyan })
hl('NeotestDir', { fg = colors.cyan })
hl('NeotestAdapterName', { fg = colors.red, bold = true })
hl('NeotestBorder', { fg = colors.comment })
hl('NeotestIndent', { fg = colors.line_nr })
hl('NeotestFocused', { bold = true, underline = true })
hl('NeotestMarked', { fg = colors.orange, bold = true })
hl('NeotestWinSelect', { fg = colors.cyan, bold = true })

-- Flash
hl('FlashBackdrop', { fg = colors.comment })
hl('FlashLabel', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('FlashMatch', { fg = colors.bg_primary, bg = colors.yellow })
hl('FlashCurrent', { fg = colors.bg_primary, bg = colors.green })

-- Fidget
hl('FidgetTitle', { fg = colors.green, bold = true })
hl('FidgetTask', { fg = colors.comment })
