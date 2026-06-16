-- Everforest colourscheme for nvim
-- matches the dotfiles everforest.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'everforest'
vim.o.termguicolors = true

-- theme colours (matching themes/everforest.theme)
local colors = {
  -- base colours
  bg_primary = '#272e33',
  fg_primary = '#d3c6aa',
  bg_secondary = '#2e383c',
  fg_secondary = '#859289',
  fg_variable = '#bcc8ad',

  -- accents
  purple = '#d699b6',
  pink = '#e67e80',
  cyan = '#83c092',
  green = '#a7c080',
  yellow = '#dbbc7f',
  red = '#e67e80',

  -- additional shades
  selection = '#374145',
  comment = '#859289',
  line_highlight = '#2b3338',
  blue = '#7fbbb3',
  orange = '#e69875',
}

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
hl('CursorLineNr', { fg = '#e67e80', bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = '#d699b6' })
hl('MatchParen', { fg = '#d699b6', bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = '#e67e80' })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = '#e67e80' })
hl('StatusLine', { fg = '#e67e80', bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = '#e67e80', bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = '#d699b6', bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = '#d699b6' })
hl('String', { fg = '#a7c080' })
hl('Character', { fg = '#a7c080' })
hl('Number', { fg = '#d699b6' })
hl('Boolean', { fg = '#d699b6' })
hl('Float', { fg = '#d699b6' })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = '#dbbc7f' })
hl('Statement', { fg = '#e67e80' })
hl('Conditional', { fg = '#e67e80' })
hl('Repeat', { fg = '#e67e80' })
hl('Label', { fg = '#e67e80' })
hl('Operator', { fg = '#83c092' })
hl('Keyword', { fg = '#e67e80' })
hl('Exception', { fg = '#e67e80' })
hl('PreProc', { fg = '#e67e80' })
hl('Include', { fg = '#e67e80' })
hl('Define', { fg = '#e67e80' })
hl('Macro', { fg = '#d699b6' })
hl('PreCondit', { fg = '#e67e80' })
hl('Type', { fg = '#83c092' })
hl('StorageClass', { fg = '#e67e80' })
hl('Structure', { fg = '#83c092' })
hl('Typedef', { fg = '#83c092' })
hl('Special', { fg = '#d699b6' })
hl('SpecialChar', { fg = '#d699b6' })
hl('Tag', { fg = '#83c092' })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#d699b6', bold = true })

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
hl('LspReferenceText', { bg = colors.selection })
hl('LspReferenceRead', { bg = colors.selection })
hl('LspReferenceWrite', { bg = colors.selection })

-- treesitter
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = '#d699b6' })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = '#83c092' })
hl('@constant', { fg = '#d699b6' })
hl('@constant.builtin', { fg = '#d699b6' })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#a7c080' })
hl('@string.escape', { fg = '#d699b6' })
hl('@string.special', { fg = '#d699b6' })
hl('@character', { fg = '#a7c080' })
hl('@number', { fg = '#d699b6' })
hl('@boolean', { fg = '#d699b6' })
hl('@function', { fg = '#dbbc7f' })
hl('@function.builtin', { fg = '#dbbc7f' })
hl('@function.call', { fg = '#dbbc7f' })
hl('@function.macro', { fg = '#d699b6' })
hl('@method', { fg = '#dbbc7f' })
hl('@method.call', { fg = '#dbbc7f' })
hl('@constructor', { fg = '#83c092' })
hl('@keyword', { fg = '#e67e80' })
hl('@keyword.function', { fg = '#e67e80' })
hl('@keyword.operator', { fg = '#e67e80' })
hl('@keyword.return', { fg = '#e67e80' })
hl('@conditional', { fg = '#e67e80' })
hl('@repeat', { fg = '#e67e80' })
hl('@label', { fg = '#e67e80' })
hl('@operator', { fg = '#83c092' })
hl('@exception', { fg = '#e67e80' })
hl('@type', { fg = '#83c092' })
hl('@type.builtin', { fg = '#83c092' })
hl('@type.qualifier', { fg = '#e67e80' })
hl('@property', { fg = '#83c092' })
hl('@attribute', { fg = '#d699b6' })
hl('@tag', { fg = '#d699b6' })
hl('@tag.attribute', { fg = '#83c092' })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = '#d699b6' })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = '#d699b6', bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#83c092' })
hl('@markup.raw', { fg = '#a7c080' })

-- Telescope
hl('TelescopeBorder', { fg = '#e67e80', bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = '#d699b6', bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = '#d699b6', bold = true })
hl('TelescopePreviewTitle', { fg = '#e67e80', bold = true })
hl('TelescopeResultsTitle', { fg = '#e67e80', bold = true })
hl('TelescopeSelection', { fg = '#e67e80', bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = '#d699b6', bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = colors.selection })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = '#d699b6' })
hl('NeoTreeGitModified', { fg = colors.orange })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = '#d699b6', bold = true })

-- Which-key
hl('WhichKey', { fg = '#e67e80' })
hl('WhichKeyGroup', { fg = '#d699b6' })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = '#e67e80', bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
