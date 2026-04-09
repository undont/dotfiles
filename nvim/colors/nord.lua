-- Nord colourscheme for Neovim
-- Matches the dotfiles nord.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'nord'
vim.o.termguicolors = true

-- Theme colours (matching themes/nord.theme)
local colors = {
  -- Base colours
  bg_primary = '#2e3440',
  fg_primary = '#eceff4',
  bg_secondary = '#3b4252',
  fg_secondary = '#4c566a',
  fg_variable = '#c4c9d2',

  -- Accents
  purple = '#b48ead',
  pink = '#d08770',
  cyan = '#88c0d0',
  green = '#a3be8c',
  yellow = '#ebcb8b',
  red = '#bf616a',

  -- Additional shades
  selection = '#434c5e',
  comment = '#616e88',
  line_highlight = '#333a47',
  blue = '#81a1c1',
  frost_blue = '#5e81ac',
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
hl('CursorLineNr', { fg = '#88c0d0', bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = '#b48ead' })
hl('MatchParen', { fg = '#b48ead', bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = '#88c0d0' })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = '#88c0d0' })
hl('StatusLine', { fg = '#88c0d0', bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = '#88c0d0', bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = '#b48ead', bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = '#b48ead' })
hl('String', { fg = '#a3be8c' })
hl('Character', { fg = '#a3be8c' })
hl('Number', { fg = '#b48ead' })
hl('Boolean', { fg = '#b48ead' })
hl('Float', { fg = '#b48ead' })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = '#88c0d0' })
hl('Statement', { fg = '#88c0d0' })
hl('Conditional', { fg = '#88c0d0' })
hl('Repeat', { fg = '#88c0d0' })
hl('Label', { fg = '#88c0d0' })
hl('Operator', { fg = '#88c0d0' })
hl('Keyword', { fg = '#88c0d0' })
hl('Exception', { fg = '#88c0d0' })
hl('PreProc', { fg = '#88c0d0' })
hl('Include', { fg = '#88c0d0' })
hl('Define', { fg = '#88c0d0' })
hl('Macro', { fg = '#b48ead' })
hl('PreCondit', { fg = '#88c0d0' })
hl('Type', { fg = '#88c0d0' })
hl('StorageClass', { fg = '#88c0d0' })
hl('Structure', { fg = '#88c0d0' })
hl('Typedef', { fg = '#88c0d0' })
hl('Special', { fg = '#b48ead' })
hl('SpecialChar', { fg = '#b48ead' })
hl('Tag', { fg = '#88c0d0' })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#b48ead', bold = true })

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
hl('@variable.builtin', { fg = '#b48ead' })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = '#88c0d0' })
hl('@constant', { fg = '#b48ead' })
hl('@constant.builtin', { fg = '#b48ead' })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#a3be8c' })
hl('@string.escape', { fg = '#b48ead' })
hl('@string.special', { fg = '#b48ead' })
hl('@character', { fg = '#a3be8c' })
hl('@number', { fg = '#b48ead' })
hl('@boolean', { fg = '#b48ead' })
hl('@function', { fg = '#88c0d0' })
hl('@function.builtin', { fg = '#88c0d0' })
hl('@function.call', { fg = '#88c0d0' })
hl('@function.macro', { fg = '#b48ead' })
hl('@method', { fg = '#88c0d0' })
hl('@method.call', { fg = '#88c0d0' })
hl('@constructor', { fg = '#88c0d0' })
hl('@keyword', { fg = '#88c0d0' })
hl('@keyword.function', { fg = '#88c0d0' })
hl('@keyword.operator', { fg = '#88c0d0' })
hl('@keyword.return', { fg = '#88c0d0' })
hl('@conditional', { fg = '#88c0d0' })
hl('@repeat', { fg = '#88c0d0' })
hl('@label', { fg = '#88c0d0' })
hl('@operator', { fg = '#88c0d0' })
hl('@exception', { fg = '#88c0d0' })
hl('@type', { fg = '#88c0d0' })
hl('@type.builtin', { fg = '#88c0d0' })
hl('@type.qualifier', { fg = '#88c0d0' })
hl('@property', { fg = '#88c0d0' })
hl('@attribute', { fg = '#b48ead' })
hl('@tag', { fg = '#b48ead' })
hl('@tag.attribute', { fg = '#88c0d0' })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = '#b48ead' })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = '#b48ead', bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#88c0d0' })
hl('@markup.raw', { fg = '#a3be8c' })

-- Telescope
hl('TelescopeBorder', { fg = '#88c0d0', bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = '#b48ead', bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = '#b48ead', bold = true })
hl('TelescopePreviewTitle', { fg = '#88c0d0', bold = true })
hl('TelescopeResultsTitle', { fg = '#88c0d0', bold = true })
hl('TelescopeSelection', { fg = '#88c0d0', bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = '#b48ead', bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = '#585e6b' })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = '#b48ead' })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = '#b48ead', bold = true })

-- Which-key
hl('WhichKey', { fg = '#88c0d0' })
hl('WhichKeyGroup', { fg = '#b48ead' })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = '#88c0d0', bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
