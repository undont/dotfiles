-- Maple colourscheme for Neovim
-- Inspired by maple treeway - autumn colours, falling leaves, warm twilight
-- Matches the dotfiles maple.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'maple'
vim.o.termguicolors = true

-- Theme colours (matching themes/maple.theme)
local colors = {
  -- Base colours - warm bark and autumn earth
  bg_primary = '#1c1816',
  fg_primary = '#e4d5c4',
  bg_secondary = '#2a2320',
  fg_secondary = '#8a7a6a',

  -- Accents - autumn leaves and twilight
  purple = '#a67b8a', -- Twilight purple
  pink = '#cf7b6d', -- Sunset pink
  cyan = '#6a9baa', -- Autumn sky
  green = '#8aa455', -- Late summer green
  yellow = '#d4a03b', -- Maple gold (primary accent)
  red = '#c75643', -- Maple red

  -- Additional shades for visual depth
  orange = '#e07a3d', -- Bright maple orange
  selection = '#4a3a30',
  comment = '#6a5a4a',
  line_highlight = '#252018',

  -- Bright variants (turning leaves)
  bright_red = '#e07a3d',
  bright_green = '#9ab465',
  bright_yellow = '#e5b54b',
  bright_blue = '#7aabba',
  bright_purple = '#b68b9a',
  bright_cyan = '#8abaa0',

  -- Dark variants (shadows in the forest)
  dark_red = '#a54535',
  dark_green = '#6a8445',
  dark_yellow = '#b4902b',
  dark_blue = '#5a8b9a',
  dark_purple = '#8a6b7a',
  dark_cyan = '#5a8a80',
}

-- Helper function to set highlight groups
local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor highlights
hl('Normal', { fg = colors.fg_primary, bg = colors.bg_primary })
hl('NormalFloat', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('FloatBorder', { fg = colors.yellow, bg = colors.bg_secondary })
hl('ColorColumn', { bg = colors.line_highlight })
hl('Cursor', { fg = colors.bg_primary, bg = colors.yellow })
hl('CursorLine', { bg = colors.line_highlight })
hl('CursorLineNr', { fg = colors.yellow, bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = colors.orange })
hl('MatchParen', { fg = colors.orange, bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = colors.yellow })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = colors.yellow })
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

-- Syntax highlighting - warm autumn tones
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
hl('Operator', { fg = colors.orange })
hl('Keyword', { fg = colors.red })
hl('Exception', { fg = colors.red })
hl('PreProc', { fg = colors.orange })
hl('Include', { fg = colors.orange })
hl('Define', { fg = colors.orange })
hl('Macro', { fg = colors.orange })
hl('PreCondit', { fg = colors.orange })
hl('Type', { fg = colors.yellow })
hl('StorageClass', { fg = colors.red })
hl('Structure', { fg = colors.cyan })
hl('Typedef', { fg = colors.yellow })
hl('Special', { fg = colors.orange })
hl('SpecialChar', { fg = colors.purple })
hl('Tag', { fg = colors.cyan })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = colors.yellow, bg = colors.bg_secondary, bold = true })

-- Diff
hl('DiffAdd', { fg = colors.green, bg = colors.line_highlight })
hl('DiffChange', { fg = colors.yellow, bg = colors.line_highlight })
hl('DiffDelete', { fg = colors.red, bg = colors.line_highlight })
hl('DiffText', { fg = colors.cyan, bg = colors.line_highlight, bold = true })

-- Git signs
hl('GitSignsAdd', { fg = colors.green })
hl('GitSignsChange', { fg = colors.yellow })
hl('GitSignsDelete', { fg = colors.red })

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

-- Treesitter - rich autumn syntax
hl('@variable', { fg = colors.fg_primary })
hl('@variable.builtin', { fg = colors.purple })
hl('@variable.parameter', { fg = colors.pink })
hl('@variable.member', { fg = colors.fg_primary })
hl('@constant', { fg = colors.purple })
hl('@constant.builtin', { fg = colors.purple })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = colors.green })
hl('@string.escape', { fg = colors.orange })
hl('@string.special', { fg = colors.orange })
hl('@character', { fg = colors.green })
hl('@number', { fg = colors.purple })
hl('@boolean', { fg = colors.purple })
hl('@function', { fg = colors.yellow })
hl('@function.builtin', { fg = colors.bright_yellow })
hl('@function.call', { fg = colors.yellow })
hl('@function.macro', { fg = colors.orange })
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
hl('@operator', { fg = colors.orange })
hl('@exception', { fg = colors.red })
hl('@type', { fg = colors.yellow })
hl('@type.builtin', { fg = colors.yellow })
hl('@type.qualifier', { fg = colors.red })
hl('@property', { fg = colors.fg_primary })
hl('@attribute', { fg = colors.orange })
hl('@tag', { fg = colors.red })
hl('@tag.attribute', { fg = colors.yellow })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = colors.orange })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = colors.yellow, bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = colors.orange })
hl('@markup.raw', { fg = colors.green })

-- Telescope - warm forest UI
hl('TelescopeBorder', { fg = colors.yellow, bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = colors.orange, bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = colors.orange, bold = true })
hl('TelescopePreviewTitle', { fg = colors.yellow, bold = true })
hl('TelescopeResultsTitle', { fg = colors.yellow, bold = true })
hl('TelescopeSelection', { fg = colors.yellow, bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = colors.orange, bold = true })

-- Neo-tree - forest explorer
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeDirectoryIcon', { fg = colors.yellow })
hl('NeoTreeDirectoryName', { fg = colors.yellow })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = colors.orange })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = colors.orange, bold = true })

-- Which-key
hl('WhichKey', { fg = colors.yellow })
hl('WhichKeyGroup', { fg = colors.orange })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline - autumn modes
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.orange, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
