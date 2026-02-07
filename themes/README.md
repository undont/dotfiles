# Themes Directory

This directory contains theme definitions for the dotfiles environment. Themes are applied consistently across tmux, Ghostty, FZF, and Neovim.

## Available Themes

Run `theme-switch list` to see all available themes.

## Adding a New Theme

To add a new theme to this repository, you need to update **three** files:

### 1. Create Theme File: `themes/<theme-name>.theme`

Create a new `.theme` file with the following structure:

```bash
#!/bin/bash
# <Theme Name> theme
# <URL to theme project>

THEME_NAME="<Display Name>"
THEME_ACTIVE_ACCENT="purple"  # or "cyan", "green", "pink", "yellow", "red"

# ══════════════════════════════════════════════════════════════
# Base Colours
# ══════════════════════════════════════════════════════════════

TMUX_BG_PRIMARY="#282a36"
TMUX_FG_PRIMARY="#f8f8f2"
TMUX_BG_SECONDARY="#44475a"
TMUX_FG_SECONDARY="#6272a4"

# ══════════════════════════════════════════════════════════════
# Accent Colours
# ══════════════════════════════════════════════════════════════

TMUX_ACCENT_PURPLE="#bd93f9"
TMUX_ACCENT_PINK="#ff79c6"
TMUX_ACCENT_CYAN="#8be9fd"
TMUX_ACCENT_GREEN="#50fa7b"
TMUX_ACCENT_YELLOW="#f1fa8c"
TMUX_ACCENT_RED="#ff5555"

# ══════════════════════════════════════════════════════════════
# Plugin Status Indicators
# ══════════════════════════════════════════════════════════════

TMUX_CPU_LOW_BG="#264d5a"
TMUX_CPU_MEDIUM_BG="#3d3b5c"
TMUX_CPU_HIGH_BG="#503b50"
TMUX_RAM_LOW_BG="#2a4a3a"
TMUX_RAM_MEDIUM_BG="#2d4a50"
TMUX_RAM_HIGH_BG="#443a5a"
TMUX_BATTERY_NORMAL_BG="#2a4a40"
TMUX_BATTERY_LOW_BG="#503030"

# ══════════════════════════════════════════════════════════════
# Ghostty Colours
# ══════════════════════════════════════════════════════════════

GHOSTTY_BACKGROUND="#282a36"
GHOSTTY_FOREGROUND="#f8f8f2"
GHOSTTY_CURSOR_COLOR="#f8f8f2"
GHOSTTY_CURSOR_TEXT="#282a36"
GHOSTTY_SELECTION_BG="#44475a"
GHOSTTY_SELECTION_FG="#ffffff"

# Terminal palette (0-15)
GHOSTTY_PALETTE_0="#21222c"
GHOSTTY_PALETTE_1="#ff5555"
GHOSTTY_PALETTE_2="#50fa7b"
GHOSTTY_PALETTE_3="#f1fa8c"
GHOSTTY_PALETTE_4="#bd93f9"
GHOSTTY_PALETTE_5="#ff79c6"
GHOSTTY_PALETTE_6="#8be9fd"
GHOSTTY_PALETTE_7="#f8f8f2"
GHOSTTY_PALETTE_8="#6272a4"
GHOSTTY_PALETTE_9="#ff6e6e"
GHOSTTY_PALETTE_10="#69ff94"
GHOSTTY_PALETTE_11="#ffffa5"
GHOSTTY_PALETTE_12="#d6acff"
GHOSTTY_PALETTE_13="#ff92df"
GHOSTTY_PALETTE_14="#a4ffff"
GHOSTTY_PALETTE_15="#ffffff"

# ══════════════════════════════════════════════════════════════
# Neovim Colours
# ══════════════════════════════════════════════════════════════

NVIM_COLORSCHEME="dracula"
```

**Notes:**
- `THEME_NAME`: Display name shown in `theme-switch list`
- `THEME_ACTIVE_ACCENT`: Which accent colour to use for active windows/borders (`purple`, `cyan`, `green`, `pink`, `yellow`, or `red`)
- Base colours and accents are **required** - they're used by `theme-defaults.sh` to generate status bar, pane borders, and FZF colours automatically
- `NVIM_COLORSCHEME`: Must match the exact colorscheme name used in Neovim

### 2. Add Neovim Plugin: `nvim/lua/custom/plugins/ui.lua`

Add the Neovim colorscheme plugin to the plugins list:

```lua
-- <Theme Name> theme
{
  'author/plugin-name',
  lazy = true,
  opts = {
    -- plugin-specific options
  },
},
```

**Important:** All theme plugins **must** be `lazy = true` to avoid slowing down startup.

### 3. Update Theme Mappings: `nvim/lua/custom/core/theme.lua`

Add two entries:

**In `theme_map`** (maps dotfiles theme names to Neovim colorscheme names):
```lua
local theme_map = {
  -- ... existing themes ...
  ['<theme-name>'] = '<nvim-colorscheme-name>',
}
```

**In `lazy_schemes`** (maps Neovim colorscheme names to plugin names):
```lua
local lazy_schemes = {
  -- ... existing schemes ...
  ['<nvim-colorscheme-name>'] = '<plugin-name>',
}
```

**Example:**
```lua
-- theme_map
['monokai'] = 'monokai-pro',

-- lazy_schemes
['monokai-pro'] = 'monokai-pro.nvim',
```

## Theme Architecture

### Automatic Defaults (`theme-defaults.sh`)

Theme files only define **base colours** and **accents**. The following are automatically derived:

- **Status bar colours**: Uses `TMUX_BG_PRIMARY`, `TMUX_FG_PRIMARY`, and chosen accent
- **Pane borders**: Active border uses `THEME_ACTIVE_ACCENT`
- **Message/command bar**: Uses chosen accent
- **FZF colours**: Automatically mapped from base and accent colours

This standardisation means:
- Less duplication across theme files
- Consistent behaviour across all themes
- Easier maintenance

### Consumer Scripts

Two scripts consume theme files and apply defaults:

1. **`scripts/theme-switch`**: Applies theme to tmux and Ghostty templates
2. **`scripts/fzf-theme.sh`**: Generates FZF colours (sourced by `.zshrc`)

Both scripts:
1. Source the `.theme` file
2. Source `theme-defaults.sh`
3. Call `apply_theme_defaults()`

## Testing a New Theme

After adding all three files:

```bash
# List themes (verify new theme appears)
theme-switch list

# Apply the theme
theme-switch <theme-name>

# In Neovim, manually reload
:ThemeReload

# Or restart Neovim to see the theme applied
```

## Colour Palette Guidelines

When creating a new theme, ensure you define all required colour variables:

**Required:**
- 4 base colours (primary/secondary background/foreground)
- 6 accent colours (purple, pink, cyan, green, yellow, red)
- 8 plugin indicator backgrounds (CPU low/med/high, RAM low/med/high, battery normal/low)
- Ghostty colours (background, foreground, cursor, selection)
- 16-colour terminal palette (PALETTE_0 through PALETTE_15)

**Tip:** Use existing theme files as templates - they all follow the same structure.
