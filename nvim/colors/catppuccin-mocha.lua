-- Catppuccin Mocha colourscheme for Neovim
-- Matches the dotfiles catppuccin-mocha.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'catppuccin-mocha'
vim.o.termguicolors = true

-- Theme colours (matching themes/catppuccin-mocha.theme)
local colors = {
  -- Base colours
  bg_primary = '#1e1e2e',
  fg_primary = '#cdd6f4',
  bg_secondary = '#313244',
  fg_secondary = '#6c7086',

  -- Accents
  purple = '#cba6f7',
  pink = '#f5c2e7',
  cyan = '#89dceb',
  green = '#a6e3a1',
  yellow = '#f9e2af',
  red = '#f38ba8',

  -- Additional shades
  selection = '#313244',
  comment = '#6c7086',
  line_highlight = '#262637',
  blue = '#89b4fa',
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
hl('CursorLineNr', { fg = '#cba6f7', bold = true })
hl('LineNr', { fg = colors.comment })
hl('SignColumn', { bg = colors.bg_primary })
hl('Visual', { bg = colors.selection })
hl('VisualNOS', { bg = colors.selection })
hl('Search', { fg = colors.bg_primary, bg = colors.yellow })
hl('IncSearch', { fg = colors.bg_primary, bg = '#f5c2e7' })
hl('MatchParen', { fg = '#f5c2e7', bold = true })
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
hl('PmenuSel', { fg = colors.bg_primary, bg = '#cba6f7' })
hl('PmenuSbar', { bg = colors.bg_secondary })
hl('PmenuThumb', { bg = '#cba6f7' })
hl('StatusLine', { fg = '#cba6f7', bg = colors.bg_secondary })
hl('StatusLineNC', { fg = colors.comment, bg = colors.bg_secondary })
hl('TabLine', { fg = colors.fg_secondary, bg = colors.bg_secondary })
hl('TabLineFill', { bg = colors.bg_secondary })
hl('TabLineSel', { fg = '#cba6f7', bg = colors.bg_primary, bold = true })
hl('Directory', { fg = colors.cyan })
hl('Title', { fg = '#f5c2e7', bold = true })
hl('SpecialKey', { fg = colors.comment })
hl('NonText', { fg = colors.comment })
hl('Whitespace', { fg = colors.comment })

-- Syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = '#cba6f7' })
hl('String', { fg = '#a6e3a1' })
hl('Character', { fg = '#a6e3a1' })
hl('Number', { fg = '#cba6f7' })
hl('Boolean', { fg = '#cba6f7' })
hl('Float', { fg = '#cba6f7' })
hl('Identifier', { fg = colors.fg_primary })
hl('Function', { fg = '#89dceb' })
hl('Statement', { fg = '#cba6f7' })
hl('Conditional', { fg = '#cba6f7' })
hl('Repeat', { fg = '#cba6f7' })
hl('Label', { fg = '#cba6f7' })
hl('Operator', { fg = '#f9e2af' })
hl('Keyword', { fg = '#cba6f7' })
hl('Exception', { fg = '#cba6f7' })
hl('PreProc', { fg = '#cba6f7' })
hl('Include', { fg = '#cba6f7' })
hl('Define', { fg = '#cba6f7' })
hl('Macro', { fg = '#cba6f7' })
hl('PreCondit', { fg = '#cba6f7' })
hl('Type', { fg = '#f9e2af' })
hl('StorageClass', { fg = '#cba6f7' })
hl('Structure', { fg = '#f9e2af' })
hl('Typedef', { fg = '#f9e2af' })
hl('Special', { fg = '#f5c2e7' })
hl('SpecialChar', { fg = '#f5c2e7' })
hl('Tag', { fg = '#f9e2af' })
hl('Delimiter', { fg = colors.fg_primary })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#f5c2e7', bold = true })

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
hl('GitSignsAddLn', { bg = '#353c43' })
hl('GitSignsChangeLn', { bg = '#3f3c45' })
hl('GitSignsDeleteLn', { bg = '#3e3244' })
hl('GitSignsAddNr', { fg = colors.green, bg = '#353c43' })
hl('GitSignsChangeNr', { fg = colors.yellow, bg = '#3f3c45' })
hl('GitSignsDeleteNr', { fg = colors.red, bg = '#3e3244' })

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
hl('@variable.builtin', { fg = '#cba6f7' })
hl('@variable.parameter', { fg = colors.fg_secondary })
hl('@variable.member', { fg = '#f9e2af' })
hl('@constant', { fg = '#cba6f7' })
hl('@constant.builtin', { fg = '#cba6f7' })
hl('@module', { fg = colors.cyan })
hl('@string', { fg = '#a6e3a1' })
hl('@string.escape', { fg = '#f5c2e7' })
hl('@string.special', { fg = '#f5c2e7' })
hl('@character', { fg = '#a6e3a1' })
hl('@number', { fg = '#cba6f7' })
hl('@boolean', { fg = '#cba6f7' })
hl('@function', { fg = '#89dceb' })
hl('@function.builtin', { fg = '#89dceb' })
hl('@function.call', { fg = '#89dceb' })
hl('@function.macro', { fg = '#cba6f7' })
hl('@method', { fg = '#89dceb' })
hl('@method.call', { fg = '#89dceb' })
hl('@constructor', { fg = '#f9e2af' })
hl('@keyword', { fg = '#cba6f7' })
hl('@keyword.function', { fg = '#cba6f7' })
hl('@keyword.operator', { fg = '#cba6f7' })
hl('@keyword.return', { fg = '#cba6f7' })
hl('@conditional', { fg = '#cba6f7' })
hl('@repeat', { fg = '#cba6f7' })
hl('@label', { fg = '#cba6f7' })
hl('@operator', { fg = '#f9e2af' })
hl('@exception', { fg = '#cba6f7' })
hl('@type', { fg = '#f9e2af' })
hl('@type.builtin', { fg = '#f9e2af' })
hl('@type.qualifier', { fg = '#cba6f7' })
hl('@property', { fg = '#f9e2af' })
hl('@attribute', { fg = '#cba6f7' })
hl('@tag', { fg = '#f5c2e7' })
hl('@tag.attribute', { fg = '#f9e2af' })
hl('@tag.delimiter', { fg = colors.fg_secondary })
hl('@punctuation.delimiter', { fg = colors.fg_primary })
hl('@punctuation.bracket', { fg = colors.fg_primary })
hl('@punctuation.special', { fg = '#f5c2e7' })
hl('@comment', { link = 'Comment' })
hl('@markup.strong', { bold = true })
hl('@markup.italic', { italic = true })
hl('@markup.underline', { underline = true })
hl('@markup.heading', { fg = '#f5c2e7', bold = true })
hl('@markup.link', { fg = colors.cyan, underline = true })
hl('@markup.link.url', { fg = colors.purple, underline = true })
hl('@markup.list', { fg = '#f9e2af' })
hl('@markup.raw', { fg = '#a6e3a1' })

-- Telescope
hl('TelescopeBorder', { fg = '#cba6f7', bg = colors.bg_secondary })
hl('TelescopePromptBorder', { fg = '#f5c2e7', bg = colors.bg_secondary })
hl('TelescopePromptTitle', { fg = '#f5c2e7', bold = true })
hl('TelescopePreviewTitle', { fg = '#cba6f7', bold = true })
hl('TelescopeResultsTitle', { fg = '#cba6f7', bold = true })
hl('TelescopeSelection', { fg = '#cba6f7', bg = colors.selection, bold = true })
hl('TelescopeMatching', { fg = '#f5c2e7', bold = true })

-- Neo-tree
hl('NeoTreeNormal', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeNormalNC', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('NeoTreeCursorLine', { bg = '#4f5060' })
hl('NeoTreeDirectoryIcon', { fg = colors.cyan })
hl('NeoTreeDirectoryName', { fg = colors.cyan })
hl('NeoTreeFileName', { fg = colors.fg_primary })
hl('NeoTreeFileNameOpened', { fg = '#f5c2e7' })
hl('NeoTreeGitModified', { fg = colors.yellow })
hl('NeoTreeGitAdded', { fg = colors.green })
hl('NeoTreeGitDeleted', { fg = colors.red })
hl('NeoTreeIndentMarker', { fg = colors.comment })
hl('NeoTreeRootName', { fg = '#f5c2e7', bold = true })

-- Which-key
hl('WhichKey', { fg = '#cba6f7' })
hl('WhichKeyGroup', { fg = '#f5c2e7' })
hl('WhichKeyDesc', { fg = colors.fg_primary })
hl('WhichKeySeparator', { fg = colors.comment })

-- Mini.nvim statusline
hl('MiniStatuslineModeNormal', { fg = colors.bg_primary, bg = '#cba6f7', bold = true })
hl('MiniStatuslineModeInsert', { fg = colors.bg_primary, bg = colors.green, bold = true })
hl('MiniStatuslineModeVisual', { fg = colors.bg_primary, bg = colors.purple, bold = true })
hl('MiniStatuslineModeReplace', { fg = colors.bg_primary, bg = colors.red, bold = true })
hl('MiniStatuslineModeCommand', { fg = colors.bg_primary, bg = colors.yellow, bold = true })
hl('MiniStatuslineDevinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFilename', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineFileinfo', { fg = colors.fg_primary, bg = colors.bg_secondary })
hl('MiniStatuslineInactive', { fg = colors.comment, bg = colors.bg_secondary })
