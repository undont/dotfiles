-- kanagawa colourscheme for nvim
-- matches the dotfiles kanagawa.theme exactly

vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' then
  vim.cmd 'syntax reset'
end

vim.g.colors_name = 'kanagawa'
vim.o.termguicolors = true

-- theme colours (matching themes/kanagawa.theme)
local colors = {
  -- base colours
  bg_primary = '#1f1f28',
  fg_primary = '#dcd7ba',
  bg_secondary = '#2a2a37',
  fg_secondary = '#54546d',
  fg_variable = '#bab6a7',

  -- accents
  purple = '#957fb8',
  pink = '#d27e99',
  cyan = '#7fb4ca',
  green = '#98bb6c',
  yellow = '#e6c384',
  red = '#c34043',

  -- additional shades
  selection = '#2d4f67',
  comment = '#727169',
  line_highlight = '#25252f',
  blue = '#7e9cd8',
  orange = '#ffa066',

  -- syntax roles (mirroring upstream kanagawa.nvim wave)
  aqua = '#7aa89f', -- types
  op_yellow = '#c0a36e', -- operators
  parameter = '#b8b4d0', -- function parameters
  punct = '#9cabca', -- punctuation
  wave_red = '#e46876', -- preproc, builtins
}

-- set highlight groups
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

-- syntax highlighting
hl('Comment', { fg = colors.comment, italic = true })
hl('Constant', { fg = colors.orange })
hl('String', { fg = '#98bb6c' })
hl('Character', { fg = '#98bb6c' })
hl('Number', { fg = '#d27e99' })
hl('Boolean', { fg = colors.orange, bold = true })
hl('Float', { fg = '#d27e99' })
hl('Identifier', { fg = '#e6c384' })
hl('Function', { fg = colors.blue })
hl('Statement', { fg = '#957fb8' })
hl('Conditional', { fg = '#957fb8' })
hl('Repeat', { fg = '#957fb8' })
hl('Label', { fg = '#957fb8' })
hl('Operator', { fg = colors.op_yellow })
hl('Keyword', { fg = '#957fb8' })
hl('Exception', { fg = '#957fb8' })
hl('PreProc', { fg = colors.wave_red })
hl('Include', { fg = colors.wave_red })
hl('Define', { fg = colors.wave_red })
hl('Macro', { fg = colors.wave_red })
hl('PreCondit', { fg = colors.wave_red })
hl('Type', { fg = colors.aqua })
hl('StorageClass', { fg = '#957fb8' })
hl('Structure', { fg = colors.aqua })
hl('Typedef', { fg = colors.aqua })
hl('Special', { fg = '#7fb4ca' })
hl('SpecialChar', { fg = colors.wave_red })
hl('Tag', { fg = '#7fb4ca' })
hl('Delimiter', { fg = colors.punct })
hl('SpecialComment', { fg = colors.comment, italic = true })
hl('Debug', { fg = colors.red })
hl('Underlined', { fg = colors.cyan, underline = true })
hl('Ignore', { fg = colors.comment })
hl('Error', { fg = colors.red, bold = true })
hl('Todo', { fg = '#d27e99', bold = true })

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

-- Treesitter
hl('@variable', { fg = colors.fg_variable })
hl('@variable.builtin', { fg = colors.wave_red })
hl('@variable.parameter', { fg = colors.parameter })
hl('@variable.member', { fg = '#e6c384' })
hl('@constant', { fg = colors.orange })
hl('@constant.builtin', { fg = colors.orange })
hl('@module', { fg = colors.aqua })
hl('@string', { fg = '#98bb6c' })
hl('@string.escape', { fg = colors.op_yellow })
hl('@string.special', { fg = '#d27e99' })
hl('@character', { fg = '#98bb6c' })
hl('@number', { fg = '#d27e99' })
hl('@boolean', { fg = colors.orange, bold = true })
hl('@function', { fg = colors.blue })
hl('@function.builtin', { fg = '#7fb4ca' })
hl('@function.call', { fg = colors.blue })
hl('@function.macro', { fg = colors.wave_red })
hl('@method', { fg = colors.blue })
hl('@method.call', { fg = colors.blue })
hl('@constructor', { fg = '#7fb4ca' })
hl('@keyword', { fg = '#957fb8' })
hl('@keyword.function', { fg = '#957fb8' })
hl('@keyword.operator', { fg = '#957fb8' })
hl('@keyword.return', { fg = '#957fb8' })
hl('@conditional', { fg = '#957fb8' })
hl('@repeat', { fg = '#957fb8' })
hl('@label', { fg = '#957fb8' })
hl('@operator', { fg = colors.op_yellow })
hl('@exception', { fg = '#957fb8' })
hl('@type', { fg = colors.aqua })
hl('@type.builtin', { fg = colors.aqua })
hl('@type.qualifier', { fg = '#957fb8' })
hl('@property', { fg = '#e6c384' })
hl('@attribute', { fg = colors.wave_red })
hl('@tag', { fg = '#d27e99' })
hl('@tag.attribute', { fg = '#e6c384' })
hl('@tag.delimiter', { fg = colors.punct })
hl('@punctuation.delimiter', { fg = colors.punct })
hl('@punctuation.bracket', { fg = colors.punct })
hl('@punctuation.special', { fg = '#7fb4ca' })
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
