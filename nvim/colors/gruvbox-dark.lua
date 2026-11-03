-- gruvbox-dark colourscheme for nvim, coloured from themes/gruvbox-dark.theme

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'gruvbox-dark'
vim.o.termguicolors = true

local colors = require('core.palette').load('gruvbox-dark', {
  -- base colours
  bg_primary = 'GHOSTTY_BACKGROUND',
  fg_primary = 'GHOSTTY_FOREGROUND',
  bg_secondary = 'TMUX_BG_SECONDARY',
  fg_secondary = 'NVIM_COMMENT',
  fg_variable = 'NVIM_FG_VARIABLE',

  -- accents
  purple = 'NVIM_PURPLE',
  pink = 'GHOSTTY_PALETTE_13',
  cyan = 'GHOSTTY_PALETTE_14',
  green = 'GHOSTTY_PALETTE_10',
  yellow = 'GHOSTTY_PALETTE_11',
  red = 'GHOSTTY_PALETTE_9',

  -- additional shades for visual consistency
  selection = 'NVIM_SELECTION',
  reference = 'NVIM_REFERENCE',
  comment = 'NVIM_COMMENT',
  line_highlight = 'GHOSTTY_SELECTION_BG',

  -- bright variants from terminal palette
  bright_red = 'GHOSTTY_PALETTE_9',
  bright_green = 'GHOSTTY_PALETTE_10',
  bright_yellow = 'GHOSTTY_PALETTE_11',
  bright_blue = 'GHOSTTY_PALETTE_12',
  bright_purple = 'GHOSTTY_PALETTE_13',
  bright_cyan = 'GHOSTTY_PALETTE_14',

  -- dark variants from terminal palette
  dark_red = 'NVIM_DARK_RED',
  dark_green = 'GHOSTTY_PALETTE_2',
  dark_yellow = 'GHOSTTY_PALETTE_3',
  dark_blue = 'NVIM_DARK_BLUE',
  dark_purple = 'NVIM_PURPLE',
  dark_cyan = 'GHOSTTY_PALETTE_6',

  -- syntax roles (mirroring upstream gruvbox.nvim dark)
  orange = 'NVIM_ORANGE', -- operators, builtins, specials
  punct = 'NVIM_PUNCT', -- fg3, subtle punctuation (upstream uses it for brackets in several langs)
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
hl('CursorLineNr', { fg = colors.yellow, bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = colors.green })
hl('MatchParen', { fg = colors.green, bold = true })
hl('Question', { fg = colors.yellow })
hl('ModeMsg', { fg = colors.green, bold = true })
hl('MoreMsg', { fg = colors.green })
hl('ErrorMsg', { fg = colors.red, bold = true })
hl('WarningMsg', { fg = colors.yellow })
hl('VertSplit', { fg = colors.bg_secondary })
hl('WinSeparator', { fg = colors.bg_secondary })
hl('Folded', { fg = colors.comment, bg = colors.line_highlight })
hl('FoldColumn', { fg = colors.comment })
hl('Pmenu', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('PmenuSel', { fg = colors.bg_primary, bg = colors.green })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = colors.green })
hl('StatusLine', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = colors.fg_primary, bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = colors.yellow, bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.bright_purple })
hl('String', { fg = colors.green })
hl('Character', { fg = colors.bright_purple })
hl('Number', { fg = colors.bright_purple })
hl('Boolean', { fg = colors.bright_purple })
hl('Float', { fg = colors.bright_purple })
hl('Identifier', { fg = colors.bright_blue })
hl('Function', { fg = colors.green, bold = true })
hl('Statement', { fg = colors.red })
hl('Conditional', { fg = colors.red })
hl('Repeat', { fg = colors.red })
hl('Label', { fg = colors.red })
hl('Operator', { fg = colors.orange })
hl('Keyword', { fg = colors.red })
hl('Exception', { fg = colors.red })
hl('PreProc', { fg = colors.cyan })
hl('Include', { fg = colors.cyan })
hl('Define', { fg = colors.cyan })
hl('Macro', { fg = colors.cyan })
hl('PreCondit', { fg = colors.cyan })
hl('Type', { fg = colors.yellow })
hl('StorageClass', { fg = colors.orange })
hl('Structure', { fg = colors.cyan })
hl('Typedef', { fg = colors.yellow })
hl('Special', { fg = colors.orange })
hl('SpecialChar', { fg = colors.orange })
hl('Tag', { fg = colors.orange })
-- upstream funnels Delimiter to orange; fg3 keeps punctuation subtle
hl('Delimiter', { fg = colors.punct })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = colors.yellow, bg = colors.bg_secondary, bold = true })

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

-- Treesitter
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = colors.orange })
hl('@variable.parameter', { fg = colors.bright_blue })
hl('@variable.member', { fg = colors.bright_blue })
hl('@constant', { fg = colors.bright_purple })
hl('@constant.builtin', { fg = colors.orange })
hl('@module', { fg = colors.fg_primary })
hl('@string', { fg = colors.green })
hl('@string.escape', { fg = colors.orange })
hl('@string.special', { fg = colors.orange })
hl('@character', { fg = colors.bright_purple })
hl('@number', { fg = colors.bright_purple })
hl('@boolean', { fg = colors.bright_purple })
hl('@function', { fg = colors.green, bold = true })
hl('@function.builtin', { fg = colors.orange })
hl('@function.call', { fg = colors.green, bold = true })
hl('@function.macro', { fg = colors.cyan })
hl('@method', { fg = colors.green, bold = true })
hl('@method.call', { fg = colors.green, bold = true })
hl('@constructor', { fg = colors.orange })
hl('@keyword', { fg = colors.red })
hl('@keyword.function', { fg = colors.red })
hl('@keyword.operator', { fg = colors.red })
hl('@keyword.return', { fg = colors.red })
hl('@conditional', { fg = colors.red })
hl('@repeat', { fg = colors.red })
hl('@label', { fg = colors.red })
hl('@operator', { fg = colors.orange })
hl('@exception', { fg = colors.red })
hl('@type', { fg = colors.yellow })
hl('@type.builtin', { fg = colors.yellow })
hl('@type.qualifier', { fg = colors.yellow })
hl('@property', { fg = colors.bright_blue })
hl('@attribute', { fg = colors.cyan })
hl('@tag', { fg = colors.orange })
hl('@tag.attribute', { fg = colors.bright_blue })
hl('@tag.delimiter', { fg = colors.punct })
hl('@punctuation.delimiter', { fg = colors.punct })
hl('@punctuation.bracket', { fg = colors.punct })
hl('@punctuation.special', { fg = colors.orange })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = colors.yellow, bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = colors.red })
hl('@markup.raw', { fg = colors.green })

-- Telescope
hl('TelescopeBorder', { fg = colors.green, bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = colors.green, bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = colors.green, bold = true })
hl('TelescopePreviewTitle', { fg = colors.cyan, bold = true })
hl('TelescopeResultsTitle', { fg = colors.cyan, bold = true })
hl('TelescopeSelection', { fg = colors.yellow, bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = colors.green, bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = colors.tree_cursor_line })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = colors.green })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = colors.green, bold = true })

-- Which-key
hl('WhichKey', { fg = colors.green })
hl('WhichKeyGroup', { fg = colors.cyan })
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
