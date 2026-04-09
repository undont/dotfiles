-- Kanagawa colourscheme for Neovim
-- Matches the dotfiles kanagawa.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'kanagawa'
vim.o.termguicolors = true

-- Theme colours (matching themes/kanagawa.theme)
local colors = {
  -- Base colours
  bg_primary = '#1f1f28',
  fg_primary = '#dcd7ba',
  bg_secondary = '#2a2a37',
  fg_secondary = '#54546d',
  fg_variable = '#bab6a7',

  -- Accents
  purple = '#957fb8',
  pink = '#d27e99',
  cyan = '#7fb4ca',
  green = '#98bb6c',
  yellow = '#e6c384',
  red = '#c34043',

  -- Additional shades
  selection = '#2d4f67',
  comment = '#727169',
  line_highlight = '#25252f',
  blue = '#7e9cd8',
  orange = '#ffa066',
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
hl('CursorLineNr', { fg = '#957fb8', bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = '#d27e99' })
hl('MatchParen', { fg = '#d27e99', bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = '#957fb8' })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = '#957fb8' })
hl('StatusLine', { fg = '#957fb8', bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = '#957fb8', bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = '#d27e99', bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = '#e6c384' })
hl('String', { fg = '#98bb6c' })
hl('Character', { fg = '#98bb6c' })
hl('Number', { fg = '#e6c384' })
hl('Boolean', { fg = '#e6c384' })
hl('Float', { fg = '#e6c384' })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = '#7fb4ca' })
hl('Statement', { fg = '#957fb8' })
hl('Conditional', { fg = '#957fb8' })
hl('Repeat', { fg = '#957fb8' })
hl('Label', { fg = '#957fb8' })
hl('Operator', { fg = '#7fb4ca' })
hl('Keyword', { fg = '#957fb8' })
hl('Exception', { fg = '#957fb8' })
hl('PreProc', { fg = '#957fb8' })
hl('Include', { fg = '#957fb8' })
hl('Define', { fg = '#957fb8' })
hl('Macro', { fg = '#e6c384' })
hl('PreCondit', { fg = '#957fb8' })
hl('Type', { fg = '#7fb4ca' })
hl('StorageClass', { fg = '#957fb8' })
hl('Structure', { fg = '#7fb4ca' })
hl('Typedef', { fg = '#7fb4ca' })
hl('Special', { fg = '#d27e99' })
hl('SpecialChar', { fg = '#d27e99' })
hl('Tag', { fg = '#7fb4ca' })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#d27e99', bold = true })

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
hl('@variable.builtin', { fg = '#e6c384' })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = '#7fb4ca' })
hl('@constant', { fg = '#e6c384' })
hl('@constant.builtin', { fg = '#e6c384' })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#98bb6c' })
hl('@string.escape', { fg = '#d27e99' })
hl('@string.special', { fg = '#d27e99' })
hl('@character', { fg = '#98bb6c' })
hl('@number', { fg = '#e6c384' })
hl('@boolean', { fg = '#e6c384' })
hl('@function', { fg = '#7fb4ca' })
hl('@function.builtin', { fg = '#7fb4ca' })
hl('@function.call', { fg = '#7fb4ca' })
hl('@function.macro', { fg = '#e6c384' })
hl('@method', { fg = '#7fb4ca' })
hl('@method.call', { fg = '#7fb4ca' })
hl('@constructor', { fg = '#7fb4ca' })
hl('@keyword', { fg = '#957fb8' })
hl('@keyword.function', { fg = '#957fb8' })
hl('@keyword.operator', { fg = '#957fb8' })
hl('@keyword.return', { fg = '#957fb8' })
hl('@conditional', { fg = '#957fb8' })
hl('@repeat', { fg = '#957fb8' })
hl('@label', { fg = '#957fb8' })
hl('@operator', { fg = '#7fb4ca' })
hl('@exception', { fg = '#957fb8' })
hl('@type', { fg = '#7fb4ca' })
hl('@type.builtin', { fg = '#7fb4ca' })
hl('@type.qualifier', { fg = '#957fb8' })
hl('@property', { fg = '#7fb4ca' })
hl('@attribute', { fg = '#e6c384' })
hl('@tag', { fg = '#d27e99' })
hl('@tag.attribute', { fg = '#7fb4ca' })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = '#d27e99' })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = '#d27e99', bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#7fb4ca' })
hl('@markup.raw', { fg = '#98bb6c' })

-- Telescope
hl('TelescopeBorder', { fg = '#957fb8', bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = '#d27e99', bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = '#d27e99', bold = true })
hl('TelescopePreviewTitle', { fg = '#957fb8', bold = true })
hl('TelescopeResultsTitle', { fg = '#957fb8', bold = true })
hl('TelescopeSelection', { fg = '#957fb8', bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = '#d27e99', bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = '#494955' })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = '#d27e99' })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = '#d27e99', bold = true })

-- Which-key
hl('WhichKey', { fg = '#957fb8' })
hl('WhichKeyGroup', { fg = '#d27e99' })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = '#957fb8', bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
