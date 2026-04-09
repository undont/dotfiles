-- One Dark colourscheme for Neovim
-- Matches the dotfiles onedark.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'onedark'
vim.o.termguicolors = true

-- Theme colours (matching themes/onedark.theme)
local colors = {
  -- Base colours
  bg_primary = '#282c34',
  fg_primary = '#abb2bf',
  bg_secondary = '#3e4451',
  fg_secondary = '#5c6370',
  fg_variable = '#979eab',

  -- Accents
  purple = '#c678dd',
  pink = '#e06c75',
  cyan = '#56b6c2',
  green = '#98c379',
  yellow = '#e5c07b',
  red = '#be5046',

  -- Additional shades
  selection = '#3e4451',
  comment = '#5c6370',
  line_highlight = '#2c313a',
  blue = '#61afef',
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
hl('CursorLineNr', { fg = '#c678dd', bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = '#e06c75' })
hl('MatchParen', { fg = '#e06c75', bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = '#c678dd' })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = '#c678dd' })
hl('StatusLine', { fg = '#c678dd', bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = '#c678dd', bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = '#e06c75', bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = '#e5c07b' })
hl('String', { fg = '#98c379' })
hl('Character', { fg = '#98c379' })
hl('Number', { fg = '#e5c07b' })
hl('Boolean', { fg = '#e5c07b' })
hl('Float', { fg = '#e5c07b' })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = '#56b6c2' })
hl('Statement', { fg = '#c678dd' })
hl('Conditional', { fg = '#c678dd' })
hl('Repeat', { fg = '#c678dd' })
hl('Label', { fg = '#c678dd' })
hl('Operator', { fg = '#56b6c2' })
hl('Keyword', { fg = '#c678dd' })
hl('Exception', { fg = '#c678dd' })
hl('PreProc', { fg = '#c678dd' })
hl('Include', { fg = '#c678dd' })
hl('Define', { fg = '#c678dd' })
hl('Macro', { fg = '#e5c07b' })
hl('PreCondit', { fg = '#c678dd' })
hl('Type', { fg = '#56b6c2' })
hl('StorageClass', { fg = '#c678dd' })
hl('Structure', { fg = '#56b6c2' })
hl('Typedef', { fg = '#56b6c2' })
hl('Special', { fg = '#e06c75' })
hl('SpecialChar', { fg = '#e06c75' })
hl('Tag', { fg = '#56b6c2' })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#e06c75', bold = true })

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
hl('@variable.builtin', { fg = '#e5c07b' })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = '#56b6c2' })
hl('@constant', { fg = '#e5c07b' })
hl('@constant.builtin', { fg = '#e5c07b' })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#98c379' })
hl('@string.escape', { fg = '#e06c75' })
hl('@string.special', { fg = '#e06c75' })
hl('@character', { fg = '#98c379' })
hl('@number', { fg = '#e5c07b' })
hl('@boolean', { fg = '#e5c07b' })
hl('@function', { fg = '#56b6c2' })
hl('@function.builtin', { fg = '#56b6c2' })
hl('@function.call', { fg = '#56b6c2' })
hl('@function.macro', { fg = '#e5c07b' })
hl('@method', { fg = '#56b6c2' })
hl('@method.call', { fg = '#56b6c2' })
hl('@constructor', { fg = '#56b6c2' })
hl('@keyword', { fg = '#c678dd' })
hl('@keyword.function', { fg = '#c678dd' })
hl('@keyword.operator', { fg = '#c678dd' })
hl('@keyword.return', { fg = '#c678dd' })
hl('@conditional', { fg = '#c678dd' })
hl('@repeat', { fg = '#c678dd' })
hl('@label', { fg = '#c678dd' })
hl('@operator', { fg = '#56b6c2' })
hl('@exception', { fg = '#c678dd' })
hl('@type', { fg = '#56b6c2' })
hl('@type.builtin', { fg = '#56b6c2' })
hl('@type.qualifier', { fg = '#c678dd' })
hl('@property', { fg = '#56b6c2' })
hl('@attribute', { fg = '#e5c07b' })
hl('@tag', { fg = '#e06c75' })
hl('@tag.attribute', { fg = '#56b6c2' })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = '#e06c75' })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = '#e06c75', bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#56b6c2' })
hl('@markup.raw', { fg = '#98c379' })

-- Telescope
hl('TelescopeBorder', { fg = '#c678dd', bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = '#e06c75', bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = '#e06c75', bold = true })
hl('TelescopePreviewTitle', { fg = '#c678dd', bold = true })
hl('TelescopeResultsTitle', { fg = '#c678dd', bold = true })
hl('TelescopeSelection', { fg = '#c678dd', bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = '#e06c75', bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = '#5a606b' })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = '#e06c75' })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = '#e06c75', bold = true })

-- Which-key
hl('WhichKey', { fg = '#c678dd' })
hl('WhichKeyGroup', { fg = '#e06c75' })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = '#c678dd', bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
