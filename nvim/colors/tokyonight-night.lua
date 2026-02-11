-- Tokyo Night colourscheme for Neovim
-- Matches the dotfiles tokyonight-night.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'tokyonight-night'
vim.o.termguicolors = true

-- Theme colours (matching themes/tokyonight-night.theme)
local colors = {
  -- Base colours
  bg_primary = '#1a1b26',
  fg_primary = '#c0caf5',
  bg_secondary = '#24283b',
  fg_secondary = '#565f89',

  -- Accents
  purple = '#bb9af7',
  pink = '#ff007c',
  cyan = '#7dcfff',
  green = '#9ece6a',
  yellow = '#e0af68',
  red = '#f7768e',

  -- Additional shades
  selection = '#283457',
  comment = '#565f89',
  line_highlight = '#1e2030',
  blue = '#7aa2f7',
  orange = '#ff9e64',
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

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = '#bb9af7' })
hl('String', { fg = '#9ece6a' })
hl('Character', { fg = '#9ece6a' })
hl('Number', { fg = '#bb9af7' })
hl('Boolean', { fg = '#bb9af7' })
hl('Float', { fg = '#bb9af7' })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = '#7dcfff' })
hl('Statement', { fg = '#bb9af7' })
hl('Conditional', { fg = '#bb9af7' })
hl('Repeat', { fg = '#bb9af7' })
hl('Label', { fg = '#bb9af7' })
hl('Operator', { fg = '#7dcfff' })
hl('Keyword', { fg = '#bb9af7' })
hl('Exception', { fg = '#bb9af7' })
hl('PreProc', { fg = '#bb9af7' })
hl('Include', { fg = '#bb9af7' })
hl('Define', { fg = '#bb9af7' })
hl('Macro', { fg = '#bb9af7' })
hl('PreCondit', { fg = '#bb9af7' })
hl('Type', { fg = '#7dcfff' })
hl('StorageClass', { fg = '#bb9af7' })
hl('Structure', { fg = '#7dcfff' })
hl('Typedef', { fg = '#7dcfff' })
hl('Special', { fg = '#ff007c' })
hl('SpecialChar', { fg = '#ff007c' })
hl('Tag', { fg = '#7dcfff' })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#ff007c', bold = true })

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
hl('@variable', { fg = colors.fg_primary })
hl('@variable.builtin', { fg = '#bb9af7' })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = '#7dcfff' })
hl('@constant', { fg = '#bb9af7' })
hl('@constant.builtin', { fg = '#bb9af7' })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#9ece6a' })
hl('@string.escape', { fg = '#ff007c' })
hl('@string.special', { fg = '#ff007c' })
hl('@character', { fg = '#9ece6a' })
hl('@number', { fg = '#bb9af7' })
hl('@boolean', { fg = '#bb9af7' })
hl('@function', { fg = '#7dcfff' })
hl('@function.builtin', { fg = '#7dcfff' })
hl('@function.call', { fg = '#7dcfff' })
hl('@function.macro', { fg = '#bb9af7' })
hl('@method', { fg = '#7dcfff' })
hl('@method.call', { fg = '#7dcfff' })
hl('@constructor', { fg = '#7dcfff' })
hl('@keyword', { fg = '#bb9af7' })
hl('@keyword.function', { fg = '#bb9af7' })
hl('@keyword.operator', { fg = '#bb9af7' })
hl('@keyword.return', { fg = '#bb9af7' })
hl('@conditional', { fg = '#bb9af7' })
hl('@repeat', { fg = '#bb9af7' })
hl('@label', { fg = '#bb9af7' })
hl('@operator', { fg = '#7dcfff' })
hl('@exception', { fg = '#bb9af7' })
hl('@type', { fg = '#7dcfff' })
hl('@type.builtin', { fg = '#7dcfff' })
hl('@type.qualifier', { fg = '#bb9af7' })
hl('@property', { fg = '#7dcfff' })
hl('@attribute', { fg = '#bb9af7' })
hl('@tag', { fg = '#ff007c' })
hl('@tag.attribute', { fg = '#7dcfff' })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = '#ff007c' })
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
