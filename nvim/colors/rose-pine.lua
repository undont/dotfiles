-- Rosé Pine colourscheme for nvim
-- matches the dotfiles rose-pine.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'rose-pine'
vim.o.termguicolors = true

-- Theme colours (matching themes/rose-pine.theme)
local colors = {
  -- Base colours
  bg_primary = '#191724',
  fg_primary = '#e0def4',
  bg_secondary = '#26233a',
  fg_secondary = '#6e6a86',
  fg_variable = '#c4c1d8',

  -- Accents
  purple = '#c4a7e7',
  pink = '#eb6f92',
  cyan = '#31748f',
  green = '#9ccfd8',
  yellow = '#f6c177',
  red = '#eb6f92',

  -- Additional shades
  selection = '#2a2740',
  comment = '#6e6a86',
  line_highlight = '#1f1d2e',
  rose = '#ebbcba',
  subtle = '#908caa',

  -- syntax roles (mirroring upstream rose-pine main)
  gold = '#f6c177', -- strings, numbers, constants
  foam = '#9ccfd8', -- types, properties, tags
  iris = '#c4a7e7', -- parameters, attributes, macros
  pine = '#31748f', -- keywords, statements
  love = '#eb6f92', -- builtin variables
}

-- helper to set highlight groups
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
hl('CursorLineNr', { fg = '#eb6f92', bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = '#eb6f92' })
hl('MatchParen', { fg = '#eb6f92', bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = '#eb6f92' })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = '#eb6f92' })
hl('StatusLine', { fg = '#eb6f92', bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = '#eb6f92', bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = '#eb6f92', bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.gold })
hl('String', { fg = colors.gold })
hl('Character', { fg = colors.gold })
hl('Number', { fg = colors.gold })
hl('Boolean', { fg = colors.rose })
hl('Float', { fg = colors.gold })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = colors.rose })
hl('Statement', { fg = colors.pine, bold = true })
hl('Conditional', { fg = colors.pine })
hl('Repeat', { fg = colors.pine })
hl('Label', { fg = colors.foam })
hl('Operator', { fg = colors.subtle })
hl('Keyword', { fg = colors.pine })
hl('Exception', { fg = colors.pine })
hl('PreProc', { fg = colors.iris })
hl('Include', { fg = colors.pine })
hl('Define', { fg = colors.iris })
hl('Macro', { fg = colors.iris })
hl('PreCondit', { fg = colors.iris })
hl('Type', { fg = colors.foam })
hl('StorageClass', { fg = colors.foam })
hl('Structure', { fg = colors.foam })
hl('Typedef', { fg = colors.foam })
hl('Special', { fg = colors.foam })
hl('SpecialChar', { fg = colors.foam })
hl('Tag', { fg = colors.foam })
hl('Delimiter', { fg = colors.subtle })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.rose })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#eb6f92', bold = true })

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
hl('@variable.builtin', { fg = colors.love, bold = true })
hl('@variable.parameter', { fg = colors.iris })
hl('@variable.member', { fg = colors.foam })
hl('@constant', { fg = colors.gold })
hl('@constant.builtin', { fg = colors.gold, bold = true })
hl('@module', { fg = colors.fg_primary })
hl('@string', { fg = colors.gold })
hl('@string.escape', { fg = colors.pine })
hl('@string.special', { fg = colors.gold })
hl('@character', { fg = colors.gold })
hl('@number', { fg = colors.gold })
hl('@boolean', { fg = colors.rose })
hl('@function', { fg = colors.rose })
hl('@function.builtin', { fg = colors.rose, bold = true })
hl('@function.call', { fg = colors.rose })
hl('@function.macro', { fg = colors.rose })
hl('@method', { fg = colors.rose })
hl('@method.call', { fg = colors.iris })
hl('@constructor', { fg = colors.foam })
hl('@keyword', { fg = colors.pine })
hl('@keyword.function', { fg = colors.pine })
hl('@keyword.operator', { fg = colors.subtle })
hl('@keyword.return', { fg = colors.pine })
hl('@conditional', { fg = colors.pine })
hl('@repeat', { fg = colors.pine })
hl('@label', { fg = colors.foam })
hl('@operator', { fg = colors.subtle })
hl('@exception', { fg = colors.pine })
hl('@type', { fg = colors.foam })
hl('@type.builtin', { fg = colors.foam, bold = true })
hl('@type.qualifier', { fg = colors.pine })
hl('@property', { fg = colors.foam })
hl('@attribute', { fg = colors.iris })
hl('@tag', { fg = colors.foam })
hl('@tag.attribute', { fg = colors.iris })
hl('@tag.delimiter', { fg = colors.subtle })
hl('@punctuation.delimiter', { fg = colors.subtle })
hl('@punctuation.bracket', { fg = colors.subtle })
hl('@punctuation.special', { fg = colors.subtle })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = '#eb6f92', bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#f6c177' })
hl('@markup.raw', { fg = '#9ccfd8' })

-- Telescope
hl('TelescopeBorder', { fg = '#eb6f92', bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = '#eb6f92', bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = '#eb6f92', bold = true })
hl('TelescopePreviewTitle', { fg = '#eb6f92', bold = true })
hl('TelescopeResultsTitle', { fg = '#eb6f92', bold = true })
hl('TelescopeSelection', { fg = '#eb6f92', bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = '#eb6f92', bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = '#464457' })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = '#eb6f92' })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = '#eb6f92', bold = true })

-- Which-key
hl('WhichKey', { fg = '#eb6f92' })
hl('WhichKeyGroup', { fg = '#eb6f92' })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = '#eb6f92', bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
