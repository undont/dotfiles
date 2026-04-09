-- Gruvbox Dark colourscheme for Neovim
-- Matches the dotfiles gruvbox-dark.theme exactly
-- Custom implementation to match terminal colours precisely

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'gruvbox-dark'
vim.o.termguicolors = true

-- Theme colours (matching themes/gruvbox-dark.theme)
local colors = {
  -- Base colours
  bg_primary = '#282828',
  fg_primary = '#ebdbb2',
  bg_secondary = '#3c3836',
  fg_secondary = '#928374',
  fg_variable = '#d5c5a2',

  -- Accents
  purple = '#b16286',
  pink = '#d3869b',
  cyan = '#8ec07c',
  green = '#b8bb26',
  yellow = '#fabd2f',
  red = '#fb4934',

  -- Additional shades for visual consistency
  selection = '#504945',
  comment = '#928374',
  line_highlight = '#3c3836',

  -- Bright variants from terminal palette
  bright_red = '#fb4934',
  bright_green = '#b8bb26',
  bright_yellow = '#fabd2f',
  bright_blue = '#83a598',
  bright_purple = '#d3869b',
  bright_cyan = '#8ec07c',

  -- Dark variants from terminal palette
  dark_red = '#cc241d',
  dark_green = '#98971a',
  dark_yellow = '#d79921',
  dark_blue = '#458588',
  dark_purple = '#b16286',
  dark_cyan = '#689d6a',
}

-- Helper function to set highlight groups
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

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.purple })
hl('String', { fg = colors.green })
hl('Character', { fg = colors.green })
hl('Number', { fg = colors.purple })
hl('Boolean', { fg = colors.purple })
hl('Float', { fg = colors.purple })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = colors.yellow })
hl('Statement', { fg = colors.red })
hl('Conditional', { fg = colors.red })
hl('Repeat', { fg = colors.red })
hl('Label', { fg = colors.red })
hl('Operator', { fg = colors.fg_primary })
hl('Keyword', { fg = colors.red })
hl('Exception', { fg = colors.red })
hl('PreProc', { fg = colors.cyan })
hl('Include', { fg = colors.cyan })
hl('Define', { fg = colors.cyan })
hl('Macro', { fg = colors.cyan })
hl('PreCondit', { fg = colors.cyan })
hl('Type', { fg = colors.yellow })
hl('StorageClass', { fg = colors.red })
hl('Structure', { fg = colors.cyan })
hl('Typedef', { fg = colors.yellow })
hl('Special', { fg = colors.cyan })
hl('SpecialChar', { fg = colors.purple })
hl('Tag', { fg = colors.green })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = colors.yellow, bg = colors.bg_secondary, bold = true })

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
hl('LspReferenceText', { bg = colors.selection })
hl('LspReferenceRead', { bg = colors.selection })
hl('LspReferenceWrite', { bg = colors.selection })

-- Treesitter
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = colors.purple })
hl('@variable.parameter', { fg = colors.cyan })
hl('@variable.member', { fg = colors.fg_primary })
hl('@constant', { fg = colors.purple })
hl('@constant.builtin', { fg = colors.purple })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = colors.green })
hl('@string.escape', { fg = colors.purple })
hl('@string.special', { fg = colors.cyan })
hl('@character', { fg = colors.green })
hl('@number', { fg = colors.purple })
hl('@boolean', { fg = colors.purple })
hl('@function', { fg = colors.yellow })
hl('@function.builtin', { fg = colors.cyan })
hl('@function.call', { fg = colors.yellow })
hl('@function.macro', { fg = colors.cyan })
hl('@method', { fg = colors.yellow })
hl('@method.call', { fg = colors.yellow })
hl('@constructor', { fg = colors.yellow })
hl('@keyword', { fg = colors.red })
hl('@keyword.function', { fg = colors.red })
hl('@keyword.operator', { fg = colors.red })
hl('@keyword.return', { fg = colors.red })
hl('@conditional', { fg = colors.red })
hl('@repeat', { fg = colors.red })
hl('@label', { fg = colors.red })
hl('@operator', { fg = colors.fg_primary })
hl('@exception', { fg = colors.red })
hl('@type', { fg = colors.yellow })
hl('@type.builtin', { fg = colors.yellow })
hl('@type.qualifier', { fg = colors.red })
hl('@property', { fg = colors.fg_primary })
hl('@attribute', { fg = colors.cyan })
hl('@tag', { fg = colors.cyan })
hl('@tag.attribute', { fg = colors.yellow })
hl('@tag.delimiter', { fg = colors.fg_secondary })
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
hl('NeoTreeCursorLine', { bg = '#595554' })
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
