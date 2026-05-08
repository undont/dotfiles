# Themes Directory

This directory contains theme definitions for the dotfiles environment. Themes are applied consistently across tmux, Ghostty, FZF, and Neovim.

## Available Themes

Run `dotfiles theme list` to see all available themes.

## Adding a New Theme

To add a new theme, you need to update **three** files:

### 1. Create Theme File: `themes/<theme-name>.theme`

Create a new `.theme` file following the structure of any existing theme. All themes share the same variable format:

```bash
#!/bin/bash
# <Theme Name> theme
# <URL to theme project>

THEME_NAME="<Display Name>"
THEME_ACTIVE_ACCENT="purple"  # purple, cyan, green, pink, yellow, or red

# Base Colours
TMUX_BG_PRIMARY="#282a36"       # Main background
TMUX_FG_PRIMARY="#f8f8f2"       # Main text
TMUX_BG_SECONDARY="#44475a"     # Panel/sidebar background
TMUX_FG_SECONDARY="#b0b8d1"     # Muted text (comments, line numbers)

# Accent Colours
TMUX_ACCENT_PURPLE="#caa8fa"
TMUX_ACCENT_PINK="#ff93d1"
TMUX_ACCENT_CYAN="#8be9fd"
TMUX_ACCENT_GREEN="#50fa7b"
TMUX_ACCENT_YELLOW="#f1fa8c"
TMUX_ACCENT_RED="#ffa1a1"

# Plugin Status Indicators (8 colours)
# ... see existing themes for examples

# Ghostty Colours + 16-colour terminal palette
# ... see existing themes for examples

# Neovim colourscheme name (must match nvim/colors/<name>.lua)
NVIM_COLORSCHEME="<theme-name>"
NVIM_FG_VARIABLE="#cfd8f6"      # Variable identifiers
```

### 2. Create Neovim Colourscheme: `nvim/colors/<name>.lua`

Create a custom colourscheme file. Use any existing file as a template (e.g. `nvim/colors/dracula.lua`). Each colourscheme defines highlight groups for:

- **Editor**: Normal, CursorLine, Visual, Search, Pmenu, StatusLine
- **Syntax**: Comment, String, Function, Keyword, Type, Operator
- **Diff / Git signs**: DiffAdd, DiffChange, DiffDelete, GitSignsAdd
- **Diagnostics / LSP**: DiagnosticError, DiagnosticWarn, DiagnosticInfo
- **Treesitter**: @variable, @function, @keyword, @string, @type, etc.
- **Plugins**: Telescope, Neo-tree, Which-key, Mini statusline

The `colors` table at the top should match the `.theme` file values. `NVIM_COLORSCHEME` must match `vim.g.colors_name`, and `NVIM_FG_VARIABLE` should match the colourscheme's `fg_variable`.

### 3. Update Theme Mapping: `nvim/lua/custom/core/theme.lua`

Add an entry to the `theme_map` table:

```lua
local theme_map = {
  -- ... existing themes ...
  ['<theme-name>'] = '<nvim-colorscheme-name>',
}
```

## Accessibility & Contrast

All themes must pass WCAG 2.1 contrast ratio checks to ensure readability.

### Requirements

| Check | Minimum ratio | What it covers |
|-------|--------------|----------------|
| All readable text | 4.5:1 | FG on BG, muted text, accents, palette colours |
| Palette as background | 4.5:1 | Best of black/white text on each palette colour |
| Selection text | 3.0:1 | UI highlight (Ghostty selection) |

### Running the Contrast Checker

```bash
# Check a single theme
scripts/theme-contrast-check themes/my-theme.theme

# Check all themes
scripts/theme-contrast-check --all

# Check with fix suggestions
scripts/theme-contrast-check --fix themes/my-theme.theme
```

### What Gets Checked

- **Primary text** on both primary and secondary backgrounds
- **Muted text** (FG_SECONDARY) on both backgrounds
- **All 6 accent colours** on both backgrounds
- **Ghostty palette colours 1-6** as foreground on the terminal background
- **Palette 8** (bright black / comments) on background
- **Each palette colour as a background** — must be readable with either black or white text (for terminal apps like LazyGit that use ANSI colours as backgrounds)

### Tips for Fixing Contrast Issues

- **Lighten foreground colours** rather than darkening backgrounds (preserves theme character)
- **FG_SECONDARY** is the most common failure — it needs to pass 4.5:1 on *both* BG_PRIMARY and BG_SECONDARY
- **GHOSTTY_PALETTE_8** should match or be close to FG_SECONDARY
- Use [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) for quick manual checks
- Test visually with `dotfiles theme switch <name>` and open Neovim, LazyGit, and Neo-tree

## Theme Architecture

### Automatic Defaults (`theme-defaults.sh`)

Theme files only define **base colours** and **accents**. The following are automatically derived:

- **Status bar colours**: Uses `TMUX_BG_PRIMARY`, `TMUX_FG_PRIMARY`, and chosen accent
- **Pane borders**: Active border uses `THEME_ACTIVE_ACCENT`
- **Message/command bar**: Uses chosen accent
- **FZF colours**: Automatically mapped from base and accent colours

### Overriding Individual Derived Variables

Any variable set in the `.theme` file before `apply_theme_defaults` runs will be respected — the defaults use `${VAR:-fallback}` so they won't clobber an explicit value.

For example, to use cyan for agent/zoom alerts while keeping purple as the active window accent:

```bash
THEME_ACTIVE_ACCENT="purple"
TMUX_STATUS_BELL_FG="#8be9fd"    # Cyan — overrides the purple default
```

### Consumer Scripts

Two scripts consume theme files and apply defaults:

1. **`scripts/theme-switch`**: Applies theme to tmux and Ghostty templates
2. **`scripts/fzf-theme.sh`**: Generates FZF colours (sourced by `.zshrc`)

Both scripts source the `.theme` file, then `theme-defaults.sh`, then call `apply_theme_defaults()`.

## Testing a New Theme

```bash
# Verify theme appears in list
dotfiles theme list

# Apply the theme
dotfiles theme switch <theme-name>

# Run contrast checks
scripts/theme-contrast-check themes/<theme-name>.theme

# In Neovim, reload the colourscheme
:ThemeReload
```
