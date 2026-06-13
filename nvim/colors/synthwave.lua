-- synthwave colourscheme for nvim
-- matches the dotfiles synthwave theme exactly
-- cyberpunk vaporwave aesthetic

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'synthwave'
vim.o.termguicolors = true

-- theme colours (matching themes/synthwave.theme)
local colors = {
  -- base colours
  bg_primary = '#1a1226',
  fg_primary = '#e4dfed',
  bg_secondary = '#2a1f3d',
  fg_secondary = '#9d8ec7',
  fg_variable = '#d2cbe4',

  -- accents
  purple = '#b794f6',
  pink = '#ff2e97',
  cyan = '#00d9ff',
  green = '#39ff14',
  yellow = '#ffd700',
  red = '#ff003c',

  -- additional shades
  selection = '#3d2861',
  comment = '#6b5a82',
  line_highlight = '#241735',

  -- bright variants
  bright_cyan = '#5cefff',
  bright_pink = '#ff5ac8',
  bright_green = '#6bff59',
  bright_purple = '#d6acff',
}

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
hl('Constant', { fg = colors.purple })
hl('String', { fg = colors.yellow })
hl('Character', { fg = colors.yellow })
hl('Number', { fg = colors.purple })
hl('Boolean', { fg = colors.purple })
hl('Float', { fg = colors.purple })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = colors.green })
hl('Statement', { fg = colors.pink })
hl('Conditional', { fg = colors.pink })
hl('Repeat', { fg = colors.pink })
hl('Label', { fg = colors.pink })
hl('Operator', { fg = colors.cyan })
hl('Keyword', { fg = colors.pink })
hl('Exception', { fg = colors.pink })
hl('PreProc', { fg = colors.pink })
hl('Include', { fg = colors.pink })
hl('Define', { fg = colors.pink })
hl('Macro', { fg = colors.purple })
hl('PreCondit', { fg = colors.pink })
hl('Type', { fg = colors.cyan })
hl('StorageClass', { fg = colors.pink })
hl('Structure', { fg = colors.cyan })
hl('Typedef', { fg = colors.cyan })
hl('Special', { fg = colors.bright_pink })
hl('SpecialChar', { fg = colors.bright_pink })
hl('Tag', { fg = colors.cyan })
hl('Delimiter', { fg = colors.fg_primary })
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
hl('LspReferenceText', { bg = colors.selection })
hl('LspReferenceRead', { bg = colors.selection })
hl('LspReferenceWrite', { bg = colors.selection })

-- Treesitter
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = colors.purple })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = colors.cyan })
hl('@constant', { fg = colors.purple })
hl('@constant.builtin', { fg = colors.purple })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = colors.yellow })
hl('@string.escape', { fg = colors.bright_pink })
hl('@string.special', { fg = colors.bright_pink })
hl('@character', { fg = colors.yellow })
hl('@number', { fg = colors.purple })
hl('@boolean', { fg = colors.purple })
hl('@function', { fg = colors.green })
hl('@function.builtin', { fg = colors.green })
hl('@function.call', { fg = colors.green })
hl('@function.macro', { fg = colors.purple })
hl('@method', { fg = colors.green })
hl('@method.call', { fg = colors.green })
hl('@constructor', { fg = colors.cyan })
hl('@keyword', { fg = colors.pink })
hl('@keyword.function', { fg = colors.pink })
hl('@keyword.operator', { fg = colors.pink })
hl('@keyword.return', { fg = colors.pink })
hl('@conditional', { fg = colors.pink })
hl('@repeat', { fg = colors.pink })
hl('@label', { fg = colors.pink })
hl('@operator', { fg = colors.cyan })
hl('@exception', { fg = colors.pink })
hl('@type', { fg = colors.cyan })
hl('@type.builtin', { fg = colors.cyan })
hl('@type.qualifier', { fg = colors.pink })
hl('@property', { fg = colors.cyan })
hl('@attribute', { fg = colors.purple })
hl('@tag', { fg = colors.pink })
hl('@tag.attribute', { fg = colors.cyan })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = colors.bright_pink })
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
hl('NeoTreeCursorLine', { bg = '#49405a' })
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
