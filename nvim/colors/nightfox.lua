-- Nightfox colourscheme for Neovim
-- Matches the dotfiles nightfox.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'nightfox'
vim.o.termguicolors = true

-- Theme colours (matching themes/nightfox.theme)
local colors = {
  -- Base colours
  bg_primary = '#192330',
  fg_primary = '#cdcecf',
  bg_secondary = '#212e3f',
  fg_secondary = '#71839b',
  fg_variable = '#b6bbc2',

  -- Accents
  purple = '#c792ea',
  pink = '#d67ad2',
  cyan = '#81b29a',
  green = '#a3be8c',
  yellow = '#dbc074',
  red = '#c94f6d',

  -- Additional shades
  selection = '#2b3b51',
  comment = '#71839b',
  line_highlight = '#1e2a38',
  blue = '#719cd6',
  orange = '#f4a261',
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
hl('CursorLineNr', { fg = '#c792ea', bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = '#d67ad2' })
hl('MatchParen', { fg = '#d67ad2', bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = '#c792ea' })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = '#c792ea' })
hl('StatusLine', { fg = '#c792ea', bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = '#c792ea', bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = '#d67ad2', bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = '#dbc074' })
hl('String', { fg = '#a3be8c' })
hl('Character', { fg = '#a3be8c' })
hl('Number', { fg = '#dbc074' })
hl('Boolean', { fg = '#dbc074' })
hl('Float', { fg = '#dbc074' })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = '#81b29a' })
hl('Statement', { fg = '#c792ea' })
hl('Conditional', { fg = '#c792ea' })
hl('Repeat', { fg = '#c792ea' })
hl('Label', { fg = '#c792ea' })
hl('Operator', { fg = '#81b29a' })
hl('Keyword', { fg = '#c792ea' })
hl('Exception', { fg = '#c792ea' })
hl('PreProc', { fg = '#c792ea' })
hl('Include', { fg = '#c792ea' })
hl('Define', { fg = '#c792ea' })
hl('Macro', { fg = '#dbc074' })
hl('PreCondit', { fg = '#c792ea' })
hl('Type', { fg = '#81b29a' })
hl('StorageClass', { fg = '#c792ea' })
hl('Structure', { fg = '#81b29a' })
hl('Typedef', { fg = '#81b29a' })
hl('Special', { fg = '#d67ad2' })
hl('SpecialChar', { fg = '#d67ad2' })
hl('Tag', { fg = '#81b29a' })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#d67ad2', bold = true })

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
hl('@variable.builtin', { fg = '#dbc074' })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = '#81b29a' })
hl('@constant', { fg = '#dbc074' })
hl('@constant.builtin', { fg = '#dbc074' })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#a3be8c' })
hl('@string.escape', { fg = '#d67ad2' })
hl('@string.special', { fg = '#d67ad2' })
hl('@character', { fg = '#a3be8c' })
hl('@number', { fg = '#dbc074' })
hl('@boolean', { fg = '#dbc074' })
hl('@function', { fg = '#81b29a' })
hl('@function.builtin', { fg = '#81b29a' })
hl('@function.call', { fg = '#81b29a' })
hl('@function.macro', { fg = '#dbc074' })
hl('@method', { fg = '#81b29a' })
hl('@method.call', { fg = '#81b29a' })
hl('@constructor', { fg = '#81b29a' })
hl('@keyword', { fg = '#c792ea' })
hl('@keyword.function', { fg = '#c792ea' })
hl('@keyword.operator', { fg = '#c792ea' })
hl('@keyword.return', { fg = '#c792ea' })
hl('@conditional', { fg = '#c792ea' })
hl('@repeat', { fg = '#c792ea' })
hl('@label', { fg = '#c792ea' })
hl('@operator', { fg = '#81b29a' })
hl('@exception', { fg = '#c792ea' })
hl('@type', { fg = '#81b29a' })
hl('@type.builtin', { fg = '#81b29a' })
hl('@type.qualifier', { fg = '#c792ea' })
hl('@property', { fg = '#81b29a' })
hl('@attribute', { fg = '#dbc074' })
hl('@tag', { fg = '#d67ad2' })
hl('@tag.attribute', { fg = '#81b29a' })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = '#d67ad2' })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = '#d67ad2', bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#81b29a' })
hl('@markup.raw', { fg = '#a3be8c' })

-- Telescope
hl('TelescopeBorder', { fg = '#c792ea', bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = '#d67ad2', bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = '#d67ad2', bold = true })
hl('TelescopePreviewTitle', { fg = '#c792ea', bold = true })
hl('TelescopeResultsTitle', { fg = '#c792ea', bold = true })
hl('TelescopeSelection', { fg = '#c792ea', bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = '#d67ad2', bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = '#424d5b' })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = '#d67ad2' })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = '#d67ad2', bold = true })

-- Which-key
hl('WhichKey', { fg = '#c792ea' })
hl('WhichKeyGroup', { fg = '#d67ad2' })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = '#c792ea', bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
