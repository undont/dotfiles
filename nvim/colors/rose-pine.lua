-- Rosé Pine colourscheme for Neovim
-- Matches the dotfiles rose-pine.theme exactly

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
hl('Constant', { fg = '#c4a7e7' })
hl('String', { fg = '#9ccfd8' })
hl('Character', { fg = '#9ccfd8' })
hl('Number', { fg = '#c4a7e7' })
hl('Boolean', { fg = '#c4a7e7' })
hl('Float', { fg = '#c4a7e7' })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = '#c4a7e7' })
hl('Statement', { fg = '#eb6f92' })
hl('Conditional', { fg = '#eb6f92' })
hl('Repeat', { fg = '#eb6f92' })
hl('Label', { fg = '#eb6f92' })
hl('Operator', { fg = '#f6c177' })
hl('Keyword', { fg = '#eb6f92' })
hl('Exception', { fg = '#eb6f92' })
hl('PreProc', { fg = '#eb6f92' })
hl('Include', { fg = '#eb6f92' })
hl('Define', { fg = '#eb6f92' })
hl('Macro', { fg = '#c4a7e7' })
hl('PreCondit', { fg = '#eb6f92' })
hl('Type', { fg = '#f6c177' })
hl('StorageClass', { fg = '#eb6f92' })
hl('Structure', { fg = '#f6c177' })
hl('Typedef', { fg = '#f6c177' })
hl('Special', { fg = '#eb6f92' })
hl('SpecialChar', { fg = '#eb6f92' })
hl('Tag', { fg = '#f6c177' })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#eb6f92', bold = true })

-- Diff
hl('DiffAdd', { fg = colors.green, bg = colors.line_highlight })
hl('DiffChange', { fg = colors.yellow, bg = colors.line_highlight })
hl('DiffDelete', { fg = colors.red, bg = colors.line_highlight })
hl('DiffText', { fg = colors.cyan, bg = colors.line_highlight, bold = true })

-- Git signs
hl('GitSignsAdd', { fg = colors.green })
hl('GitSignsChange', { fg = colors.yellow })
hl('GitSignsDelete', { fg = colors.red })
hl('GitSignsTopdelete', { fg = colors.red })
hl('GitSignsChangedelete', { fg = colors.orange or colors.yellow })
hl('GitSignsAddLn', { bg = '#2e3242' })
hl('GitSignsChangeLn', { bg = '#383036' })
hl('GitSignsDeleteLn', { bg = '#37263a' })
hl('GitSignsAddNr', { fg = colors.green, bg = '#2e3242' })
hl('GitSignsChangeNr', { fg = colors.yellow, bg = '#383036' })
hl('GitSignsDeleteNr', { fg = colors.red, bg = '#37263a' })

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
hl('@variable.builtin', { fg = '#c4a7e7' })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = '#f6c177' })
hl('@constant', { fg = '#c4a7e7' })
hl('@constant.builtin', { fg = '#c4a7e7' })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#9ccfd8' })
hl('@string.escape', { fg = '#eb6f92' })
hl('@string.special', { fg = '#eb6f92' })
hl('@character', { fg = '#9ccfd8' })
hl('@number', { fg = '#c4a7e7' })
hl('@boolean', { fg = '#c4a7e7' })
hl('@function', { fg = '#c4a7e7' })
hl('@function.builtin', { fg = '#c4a7e7' })
hl('@function.call', { fg = '#c4a7e7' })
hl('@function.macro', { fg = '#c4a7e7' })
hl('@method', { fg = '#c4a7e7' })
hl('@method.call', { fg = '#c4a7e7' })
hl('@constructor', { fg = '#f6c177' })
hl('@keyword', { fg = '#eb6f92' })
hl('@keyword.function', { fg = '#eb6f92' })
hl('@keyword.operator', { fg = '#eb6f92' })
hl('@keyword.return', { fg = '#eb6f92' })
hl('@conditional', { fg = '#eb6f92' })
hl('@repeat', { fg = '#eb6f92' })
hl('@label', { fg = '#eb6f92' })
hl('@operator', { fg = '#f6c177' })
hl('@exception', { fg = '#eb6f92' })
hl('@type', { fg = '#f6c177' })
hl('@type.builtin', { fg = '#f6c177' })
hl('@type.qualifier', { fg = '#eb6f92' })
hl('@property', { fg = '#f6c177' })
hl('@attribute', { fg = '#c4a7e7' })
hl('@tag', { fg = '#eb6f92' })
hl('@tag.attribute', { fg = '#f6c177' })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = '#eb6f92' })
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
