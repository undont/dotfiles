# Theme System Architecture

## Overview

The dotfiles theme system uses XDG Base Directory standard to prevent git conflicts when users change themes. This document explains the architecture and migration process.

## Problem Solved

**Before:** Theme colours were stored directly in `tmux/.tmux.conf`, which is tracked in the repository. When users changed themes, it created git conflicts and made updates difficult.

**After:** Themes are generated from templates into XDG-compliant locations (`~/.config/`), keeping user preferences separate from the repository.

## Architecture

### File Locations

```
Repository (tracked in git):
  themes/*.theme                   - Theme definitions (15+ themes)
  tmux/tmux.conf.template          - Tmux config template with {{PLACEHOLDERS}}
  ghostty/config.template          - Ghostty config template with {{PLACEHOLDERS}}
  gh-dash/config.yml.template      - gh-dash config template with {{PLACEHOLDERS}}

User Configuration (gitignored):
  ~/.config/tmux/tmux.conf         - Generated tmux config (XDG standard)
  ~/.tmux.conf                     - Compatibility symlink → ~/.config/tmux/tmux.conf
  ~/.config/ghostty/config         - Generated ghostty config (XDG, all platforms)
  ~/.config/gh-dash/config.yml     - Generated gh-dash config (XDG standard)
  ~/.config/dotfiles/current-theme - Current theme name

Local Overrides (user-owned, survive theme changes):
  ~/.config/tmux/local.conf   - Personal tmux settings (sourced at end of config)
  ~/.config/ghostty/local     - Personal ghostty settings (included via config-file)
  ~/.config/nvim/local.lua    - Personal neovim settings
```

### Theme Switching Flow

1. User runs `theme-switch catppuccin-mocha`
2. Script sources `themes/catppuccin-mocha.theme` for colour variables
3. Script processes templates, replacing `{{PLACEHOLDERS}}` with actual values
4. Generated configs are written to XDG locations
5. Current theme name is saved to `~/.config/dotfiles/current-theme`
6. Running applications are reloaded (tmux, ghostty, fzf); gh-dash reads config at launch time

## Benefits

1. **No Git Conflicts**: User theme changes don't affect the repository
2. **XDG Compliance**: Follows modern standards (`~/.config/`)
3. **Clean Templates**: Repository templates remain readable and portable
4. **Backwards Compatible**: Symlink at `~/.tmux.conf` for legacy tools
5. **Multi-User Friendly**: Each user can have different themes

## Migration for Existing Users

If you were using the old setup (symlink to `tmux/.tmux.conf` in the repo), run:

```bash
./scripts/migrate-tmux-config.sh
```

This script will:
1. Remove old symlink from `~/.tmux.conf` → `dotfiles/tmux/.tmux.conf`
2. Generate themed config in XDG location (`~/.config/tmux/tmux.conf`)
3. Create compatibility symlink `~/.tmux.conf` → `~/.config/tmux/tmux.conf`
4. Preserve your current theme

## Theme Commands

```bash
# Switch to a theme
theme-switch dracula
theme-switch catppuccin-mocha
theme-switch tokyo-night
theme-switch nord
theme-switch gruvbox-dark
theme-switch rose-pine
# ... and more (15 themes available)

# List available themes
theme-switch list

# Show current theme
theme-switch current

# Switch without reloading (for scripting)
theme-switch <theme> --no-reload

# Switch quietly (for automation)
theme-switch <theme> --quiet
```

## Creating New Themes

1. Create `themes/my-theme.theme`:

```bash
# My Theme
THEME_NAME="My Theme"

# Tmux colours
TMUX_BG_PRIMARY="#1e1e2e"
TMUX_FG_PRIMARY="#cdd6f4"
# ... more colour variables
```

2. Add all required colour variables (see existing themes for reference)
3. Test: `theme-switch my-theme`

## Technical Details

### Template Processing

The `theme-switch` script uses `sed` for fast template processing:

```bash
sed -e "s|{{THEME_NAME}}|$THEME_NAME|g" \
    -e "s|{{TMUX_BG_PRIMARY}}|$TMUX_BG_PRIMARY|g" \
    # ... more replacements
    "$TMUX_TEMPLATE" > "$TMUX_OUTPUT"
```

### XDG Directory Creation

The theme switcher ensures XDG directories exist:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
```

This respects the `XDG_CONFIG_HOME` environment variable if set.

### Git Configuration

`.gitignore` excludes generated configs and local overrides (they live in `~/.config/`, outside the repo).

## Troubleshooting

### Theme not applying after switch

1. Check if you're in tmux: `echo $TMUX`
2. Manually reload: `tmux source ~/.config/tmux/tmux.conf`
3. Check for errors: `tmux source ~/.config/tmux/tmux.conf` (will show errors)

### Migration script fails

1. Backup your current config: `cp ~/.tmux.conf ~/.tmux.conf.backup`
2. Run migration script with verbose output
3. Check file permissions on `~/.config/tmux/`

### Git shows tmux config as modified

If you're on the old setup (pre-XDG), run the migration script:

```bash
./scripts/migrate-tmux-config.sh
```

After migration, tmux config is generated to `~/.config/tmux/tmux.conf` and won't affect the repository.

## See Also

- `CLAUDE.md` - Full architecture documentation
- `themes/` - Available theme definitions
- `scripts/theme-switch` - Theme switching implementation
