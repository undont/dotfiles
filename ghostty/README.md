# Ghostty

Fast, native terminal emulator by Mitchell Hashimoto.

## Features

- **Dracula theme** - Dark colour scheme
- **Block cursor** with blinking
- **Zsh shell integration** - Title updates, no cursor override
- **Bell features** - Title and attention for tmux alerts
- **macOS optimised** - Glass icon, left Option as Alt

## Installation

```bash
brew install --cask ghostty
```

## Setup

```bash
# Create config directory
mkdir -p ~/.config/ghostty

# Symlink config
ln -sf ~/dotfiles/ghostty/config ~/.config/ghostty/config
```

## Keybindings

| Keybind | Action |
|---------|--------|
| `Shift+Enter` | Send escape + return (for tmux) |
| `Ctrl+Enter` | Send kitty-protocol enter (zsh/nvim) |
| `Ctrl+Shift+Enter` | Send kitty-protocol enter variant |
| `Opt+c` | Send escape + c |
| `Opt+Shift+[` | Send escape + `{` |
| `Opt+Shift+]` | Send escape + `}` |
| `Opt+Up` | Send modified cursor up (apps) |
| `Opt+Down` | Send modified cursor down (apps) |

## Configuration Reference

### Window Settings

| Setting | Value | Description |
|---------|-------|-------------|
| `window-width` | 140 | Columns |
| `window-height` | 38 | Rows |
| `window-position-x` | 226 | Initial X position |
| `window-position-y` | 115 | Initial Y position |

### Shell Integration

The config uses `shell-integration-features = no-cursor,title` to:
- Let Ghostty manage the cursor style (not shell)
- Update window title based on current directory/command

### Colours (Dracula)

```
Background: #282a36
Foreground: #f8f8f2
```

## Resources

- [Ghostty Website](https://ghostty.org/)
- [Configuration Reference](https://ghostty.org/docs/config)
- [Spectre Config Generator](https://github.com/imrajyavardhan12/spectre-ghostty-config)
