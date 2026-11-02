-- catppuccin-mocha colourscheme for nvim, coloured from themes/catppuccin-mocha.theme

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'catppuccin-mocha'
vim.o.termguicolors = true

local colors = require('core.palette').load('catppuccin-mocha', {
  -- base colours
  bg_primary = 'GHOSTTY_BACKGROUND',
  fg_primary = 'GHOSTTY_FOREGROUND',
  bg_secondary = 'TMUX_BG_SECONDARY',
  fg_secondary = 'NVIM_COMMENT',
  fg_variable = 'NVIM_FG_VARIABLE',

  -- accents
  purple = 'TMUX_ACCENT_PURPLE',
  pink = 'GHOSTTY_PALETTE_5',
  cyan = 'TMUX_ACCENT_CYAN',
  green = 'GHOSTTY_PALETTE_2',
  yellow = 'GHOSTTY_PALETTE_3',
  red = 'GHOSTTY_PALETTE_9',

  -- additional shades
  selection = 'GHOSTTY_SELECTION_BG',
  reference = 'NVIM_REFERENCE',
  comment = 'NVIM_COMMENT',
  line_highlight = 'NVIM_LINE_HIGHLIGHT',
  blue = 'GHOSTTY_PALETTE_12',

  -- syntax roles (mirroring upstream catppuccin/nvim mocha)
  peach = 'NVIM_PEACH', -- constants, numbers, builtin functions
  maroon = 'NVIM_MAROON', -- function parameters
  lavender = 'NVIM_LAVENDER', -- properties, members
  teal = 'GHOSTTY_PALETTE_6', -- characters, tag delimiters
  flamingo = 'NVIM_FLAMINGO', -- identifiers
  sapphire = 'NVIM_SAPPHIRE', -- labels
  overlay2 = 'NVIM_OVERLAY2', -- punctuation
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
hl('Constant', { fg = colors.peach })
hl('String', { fg = colors.green })
hl('Character', { fg = colors.teal })
hl('Number', { fg = colors.peach })
hl('Boolean', { fg = colors.peach })
hl('Float', { fg = colors.peach })
hl('Identifier', { fg = colors.flamingo })
hl('Function', { fg = colors.blue })
hl('Statement', { fg = colors.purple })
hl('Conditional', { fg = colors.purple })
hl('Repeat', { fg = colors.purple })
hl('Label', { fg = colors.sapphire })
hl('Operator', { fg = colors.cyan })
hl('Keyword', { fg = colors.purple })
hl('Exception', { fg = colors.purple })
hl('PreProc', { fg = colors.pink })
hl('Include', { fg = colors.purple })
hl('Define', { fg = colors.pink })
hl('Macro', { fg = colors.purple })
hl('PreCondit', { fg = colors.pink })
hl('Type', { fg = colors.yellow })
hl('StorageClass', { fg = colors.yellow })
hl('Structure', { fg = colors.yellow })
hl('Typedef', { fg = colors.yellow })
hl('Special', { fg = colors.pink })
hl('SpecialChar', { fg = colors.pink })
hl('Tag', { fg = colors.lavender, bold = true })
hl('Delimiter', { fg = colors.overlay2 })
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
hl('@variable.parameter', { fg = colors.maroon })
hl('@variable.member', { fg = colors.lavender })
hl('@constant', { fg = colors.peach })
hl('@constant.builtin', { fg = colors.peach })
hl('@module', { fg = colors.yellow })
hl('@string', { fg = colors.green })
hl('@string.escape', { fg = colors.pink })
hl('@string.special', { fg = colors.pink })
hl('@character', { fg = colors.teal })
hl('@number', { fg = colors.peach })
hl('@boolean', { fg = colors.peach })
hl('@function', { fg = colors.blue })
hl('@function.builtin', { fg = colors.peach })
hl('@function.call', { fg = colors.blue })
hl('@function.macro', { fg = colors.pink })
hl('@method', { fg = colors.blue })
hl('@method.call', { fg = colors.blue })
hl('@constructor', { fg = colors.yellow })
hl('@keyword', { fg = colors.purple })
hl('@keyword.function', { fg = colors.purple })
hl('@keyword.operator', { fg = colors.purple })
hl('@keyword.return', { fg = colors.purple })
hl('@conditional', { fg = colors.purple })
hl('@repeat', { fg = colors.purple })
hl('@label', { fg = colors.sapphire })
hl('@operator', { fg = colors.cyan })
hl('@exception', { fg = colors.purple })
hl('@type', { fg = colors.yellow })
hl('@type.builtin', { fg = colors.purple })
hl('@type.qualifier', { fg = colors.purple })
hl('@property', { fg = colors.lavender })
hl('@attribute', { fg = colors.peach })
hl('@tag', { fg = colors.blue })
hl('@tag.attribute', { fg = colors.yellow })
hl('@tag.delimiter', { fg = colors.teal })
hl('@punctuation.delimiter', { fg = colors.overlay2 })
hl('@punctuation.bracket', { fg = colors.overlay2 })
hl('@punctuation.special', { fg = colors.pink })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = colors.pink, bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = colors.yellow })
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
