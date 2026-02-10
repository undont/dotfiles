-- Ayu Dark colourscheme for Neovim
-- Matches the dotfiles ayu-dark.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'ayu-dark'
vim.o.termguicolors = true

-- Theme colours (matching themes/ayu-dark.theme)
local colors = {
  -- Base colours
  bg_primary = '#0a0e14',
  fg_primary = '#b3b1ad',
  bg_secondary = '#151a1e',
  fg_secondary = '#626a73',

  -- Accents
  purple = '#d2a6ff',
  pink = '#f07178',
  cyan = '#39bae6',
  green = '#c2d94c',
  yellow = '#ffb454',
  red = '#ff3333',

  -- Additional shades
  selection = '#1a1f29',
  comment = '#626a73',
  line_highlight = '#0f1319',
  orange = '#ff8f40',
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
hl('CursorLineNr', { fg = '#39bae6', bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = '#f07178' })
hl('MatchParen', { fg = '#f07178', bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = '#39bae6' })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = '#39bae6' })
hl('StatusLine', { fg = '#39bae6', bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = '#39bae6', bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = '#f07178', bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = '#d2a6ff' })
hl('String', { fg = '#c2d94c' })
hl('Character', { fg = '#c2d94c' })
hl('Number', { fg = '#d2a6ff' })
hl('Boolean', { fg = '#d2a6ff' })
hl('Float', { fg = '#d2a6ff' })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = '#ffb454' })
hl('Statement', { fg = '#39bae6' })
hl('Conditional', { fg = '#39bae6' })
hl('Repeat', { fg = '#39bae6' })
hl('Label', { fg = '#39bae6' })
hl('Operator', { fg = '#39bae6' })
hl('Keyword', { fg = '#39bae6' })
hl('Exception', { fg = '#39bae6' })
hl('PreProc', { fg = '#39bae6' })
hl('Include', { fg = '#39bae6' })
hl('Define', { fg = '#39bae6' })
hl('Macro', { fg = '#d2a6ff' })
hl('PreCondit', { fg = '#39bae6' })
hl('Type', { fg = '#39bae6' })
hl('StorageClass', { fg = '#39bae6' })
hl('Structure', { fg = '#39bae6' })
hl('Typedef', { fg = '#39bae6' })
hl('Special', { fg = '#f07178' })
hl('SpecialChar', { fg = '#f07178' })
hl('Tag', { fg = '#39bae6' })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#f07178', bold = true })

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
hl('GitSignsAddLn', { bg = '#242a1f' })
hl('GitSignsChangeLn', { bg = '#2b2620' })
hl('GitSignsDeleteLn', { bg = '#2b161c' })
hl('GitSignsAddNr', { fg = colors.green, bg = '#242a1f' })
hl('GitSignsChangeNr', { fg = colors.yellow, bg = '#2b2620' })
hl('GitSignsDeleteNr', { fg = colors.red, bg = '#2b161c' })

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
hl('@variable.builtin', { fg = '#d2a6ff' })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = '#39bae6' })
hl('@constant', { fg = '#d2a6ff' })
hl('@constant.builtin', { fg = '#d2a6ff' })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#c2d94c' })
hl('@string.escape', { fg = '#f07178' })
hl('@string.special', { fg = '#f07178' })
hl('@character', { fg = '#c2d94c' })
hl('@number', { fg = '#d2a6ff' })
hl('@boolean', { fg = '#d2a6ff' })
hl('@function', { fg = '#ffb454' })
hl('@function.builtin', { fg = '#ffb454' })
hl('@function.call', { fg = '#ffb454' })
hl('@function.macro', { fg = '#d2a6ff' })
hl('@method', { fg = '#ffb454' })
hl('@method.call', { fg = '#ffb454' })
hl('@constructor', { fg = '#39bae6' })
hl('@keyword', { fg = '#39bae6' })
hl('@keyword.function', { fg = '#39bae6' })
hl('@keyword.operator', { fg = '#39bae6' })
hl('@keyword.return', { fg = '#39bae6' })
hl('@conditional', { fg = '#39bae6' })
hl('@repeat', { fg = '#39bae6' })
hl('@label', { fg = '#39bae6' })
hl('@operator', { fg = '#39bae6' })
hl('@exception', { fg = '#39bae6' })
hl('@type', { fg = '#39bae6' })
hl('@type.builtin', { fg = '#39bae6' })
hl('@type.qualifier', { fg = '#39bae6' })
hl('@property', { fg = '#39bae6' })
hl('@attribute', { fg = '#d2a6ff' })
hl('@tag', { fg = '#f07178' })
hl('@tag.attribute', { fg = '#39bae6' })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = '#f07178' })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = '#f07178', bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#39bae6' })
hl('@markup.raw', { fg = '#c2d94c' })

-- Telescope
hl('TelescopeBorder', { fg = '#39bae6', bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = '#f07178', bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = '#f07178', bold = true })
hl('TelescopePreviewTitle', { fg = '#39bae6', bold = true })
hl('TelescopeResultsTitle', { fg = '#39bae6', bold = true })
hl('TelescopeSelection', { fg = '#39bae6', bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = '#f07178', bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = '#383c3f' })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = '#f07178' })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = '#f07178', bold = true })

-- Which-key
hl('WhichKey', { fg = '#39bae6' })
hl('WhichKeyGroup', { fg = '#f07178' })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = '#39bae6', bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
