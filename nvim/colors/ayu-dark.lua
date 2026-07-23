-- Ayu Dark colourscheme for nvim
-- matches the dotfiles ayu-dark.theme exactly

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
  fg_variable = '#b8e3f2',

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

  -- syntax roles (mirroring upstream neovim-ayu dark)
  entity = '#59c2ff', -- types, identifiers
  string = '#aad94c', -- strings
  accent = '#e6b450', -- preproc, specials
  special = '#e6b673', -- delimiters, structure
  operator = '#f29668', -- operators
  parameter = '#cb9ff8', -- function parameters
  regexp = '#95e6cb', -- escapes, regex
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
hl('String', { fg = colors.string })
hl('Character', { fg = colors.string })
hl('Number', { fg = '#d2a6ff' })
hl('Boolean', { fg = '#d2a6ff' })
hl('Float', { fg = '#d2a6ff' })
hl('Identifier', { fg = colors.entity })
hl('Function', { fg = '#ffb454' })
hl('Statement', { fg = colors.orange })
hl('Conditional', { fg = colors.orange })
hl('Repeat', { fg = colors.orange })
hl('Label', { fg = colors.orange })
hl('Operator', { fg = colors.operator })
hl('Keyword', { fg = colors.orange })
hl('Exception', { fg = '#f07178' })
hl('PreProc', { fg = colors.accent })
hl('Include', { fg = colors.accent })
hl('Define', { fg = colors.accent })
hl('Macro', { fg = colors.accent })
hl('PreCondit', { fg = colors.accent })
hl('Type', { fg = colors.entity })
hl('StorageClass', { fg = colors.orange })
hl('Structure', { fg = colors.special })
hl('Typedef', { fg = colors.entity })
hl('Special', { fg = colors.accent })
hl('SpecialChar', { fg = colors.regexp })
hl('Tag', { fg = colors.orange })
hl('Delimiter', { fg = colors.special })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#f07178', bold = true })

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
hl('@variable.builtin', { fg = '#ffb454' })
hl('@variable.parameter', { fg = colors.parameter })
hl('@variable.member', { fg = '#39bae6' })
hl('@constant', { fg = '#d2a6ff' })
hl('@constant.builtin', { fg = '#d2a6ff' })
hl('@module', { fg = '#ffb454' })
hl('@string', { fg = colors.string })
hl('@string.escape', { fg = colors.regexp })
hl('@string.special', { fg = colors.regexp })
hl('@character', { fg = colors.string })
hl('@number', { fg = '#d2a6ff' })
hl('@boolean', { fg = '#d2a6ff' })
hl('@function', { fg = '#ffb454' })
hl('@function.builtin', { fg = '#ffb454' })
hl('@function.call', { fg = '#ffb454' })
hl('@function.macro', { fg = colors.accent })
hl('@method', { fg = '#ffb454' })
hl('@method.call', { fg = '#ffb454' })
hl('@constructor', { fg = colors.accent })
hl('@keyword', { fg = colors.orange })
hl('@keyword.function', { fg = colors.orange })
hl('@keyword.operator', { fg = colors.orange })
hl('@keyword.return', { fg = colors.orange })
hl('@conditional', { fg = colors.orange })
hl('@repeat', { fg = colors.orange })
hl('@label', { fg = colors.orange })
hl('@operator', { fg = colors.operator })
hl('@exception', { fg = '#f07178' })
hl('@type', { fg = colors.entity })
hl('@type.builtin', { fg = colors.entity })
hl('@type.qualifier', { fg = colors.orange })
hl('@property', { fg = '#39bae6' })
hl('@attribute', { fg = '#d2a6ff' })
hl('@tag', { fg = colors.orange })
hl('@tag.attribute', { fg = colors.entity })
hl('@tag.delimiter', { fg = colors.special })
hl('@punctuation.delimiter', { fg = colors.special })
hl('@punctuation.bracket', { fg = colors.special })
hl('@punctuation.special', { fg = colors.accent })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = colors.orange, bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#39bae6' })
hl('@markup.raw', { fg = colors.string })

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
