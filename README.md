# Dotfiles

[![CI](https://github.com/seanhalberthal/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/seanhalberthal/dotfiles/actions/workflows/ci.yml)
[![macOS](https://img.shields.io/badge/macOS-compatible-A2AAAD?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Linux](https://img.shields.io/badge/Linux-compatible-blue?logo=linux&logoColor=white)](https://www.linux.org/)
[![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?logo=neovim&logoColor=white)](https://neovim.io/)
[![Tmux](https://img.shields.io/badge/Tmux-3.3+-1BB91F?logo=tmux&logoColor=white)](https://github.com/tmux/tmux)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

Personal configuration files for zsh, tmux, neovim, hammerspoon, ghostty, and karabiner.

## Contents

```
dotfiles/
├── zsh/              # Zsh shell configuration
│   ├── .zshrc
│   ├── .zprofile
│   ├── .p10k.zsh     # Powerlevel10k theme
│   └── .zsh/         # Additional zsh configs
├── tmux/             # Tmux terminal multiplexer
│   ├── .tmux.conf
│   └── .tmux/        # Scripts and help files
├── nvim/             # Neovim configuration
│   ├── init.lua      # Entry point
│   └── lua/custom/   # Modular config
│       ├── core/     # Options, keymaps, autocmds
│       └── plugins/  # Plugin configurations
├── launchers/        # Session launch scripts
│   ├── tnew          # Tmux dev session launcher
│   ├── dana          # Dana project launcher
│   └── code          # VS Code dynamic launcher
├── hammerspoon/      # macOS automation
│   └── init.lua
├── ghostty/          # Terminal emulator
│   └── config
├── karabiner/        # Keyboard customisation
│   └── karabiner.json
├── scripts/          # Installation and utility scripts
│   ├── dotfiles      # CLI for managing dotfiles
│   ├── install/      # Installer modules
│   ├── hooks/        # Tool hooks (e.g. Claude alerts)
│   ├── tests/        # Test suites
│   └── _lib/         # Shared shell libraries
├── docs/             # Documentation
│   ├── INSTALLATION-GUIDE.md
│   └── TROUBLESHOOTING.md
└── Brewfile          # Homebrew dependencies
```

## Quick Start

### Prerequisites

- macOS/Linux (some features are macOS-only; keyboard remapping is optimised for Apple Silicon MacBook Pro)
  - **Fresh macOS**: Install Xcode Command Line Tools first: `xcode-select --install`

### Automatic Installation

```bash
# Clone the repository
git clone https://github.com/seanhalberthal/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the installer (defaults to full preset)
./install.sh

# Or choose a specific preset
./install.sh --core       # Cross-platform dev setup
./install.sh --minimal    # Lightweight server setup
```

The installer will:
1. Install/update Homebrew
2. Install packages from `Brewfile` (filtered by preset)
3. Check prerequisites
4. Backup existing configuration
5. Create symlinks
6. Install plugin managers (TPM)
7. Create secrets file from template
8. Run a health check

### Install Presets

| Preset | Components | Use Case |
|--------|------------|----------|
| `--minimal` | zsh, tmux | Servers, remote machines, SSH |
| `--core` | + nvim, ghostty, AI/CLI tools, session launch scripts | Linux desktop, cross-platform dev |
| `--full` | + Hammerspoon, Karabiner | macOS power user (default) |

### Installation Options

```bash
./install.sh              # Full installation (default)
./install.sh --minimal    # Lightweight server setup
./install.sh --core       # Cross-platform dev setup
./install.sh --full       # Everything including macOS apps
./install.sh --skip-brew  # Skip Homebrew/package installation
./install.sh --skip-backup # Skip backing up existing configs
./install.sh --check-only  # Only run prerequisite and health checks
```

### Post-Installation

1. **Restart your terminal** or run `source ~/.zshrc`
2. **Install tmux plugins**: Open tmux and press `` ` + I ``
3. **Configure Neovim**: Open nvim - plugins install automatically
4. **Add secrets**: Edit `~/.zsh/.secrets.zsh` with your API keys
5. **Install Node.js**: `fnm install --lts && fnm default lts-latest`

### Verification

```bash
# Run health check
./scripts/install/health-check.sh

# Check prerequisites
./scripts/install/check-prerequisites.sh
```

### Manual Installation

If you prefer manual setup, see the symlink commands below:

<details>
<summary>Click to expand manual symlink commands</summary>

```bash
# Zsh
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/dotfiles/zsh/.zprofile ~/.zprofile
ln -sf ~/dotfiles/zsh/.p10k.zsh ~/.p10k.zsh
ln -sf ~/dotfiles/zsh/.zsh ~/.zsh

# Tmux
ln -sf ~/dotfiles/tmux/.tmux.conf ~/.tmux.conf
ln -sf ~/dotfiles/tmux/.tmux ~/.tmux

# Neovim
ln -sf ~/dotfiles/nvim ~/.config/nvim

# Session launchers
mkdir -p ~/.local/launchers
ln -sf ~/dotfiles/launchers/tnew ~/.local/launchers/tnew
ln -sf ~/dotfiles/launchers/dana ~/.local/launchers/dana
ln -sf ~/dotfiles/launchers/code ~/.local/launchers/code

# Dotfiles CLI
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/scripts/dotfiles ~/.local/bin/dotfiles

# Hammerspoon
ln -sf ~/dotfiles/hammerspoon ~/.hammerspoon

# Ghostty
mkdir -p ~/.config/ghostty
ln -sf ~/dotfiles/ghostty/config ~/.config/ghostty/config

# Karabiner Elements
mkdir -p ~/.config/karabiner
ln -sf ~/dotfiles/karabiner/karabiner.json ~/.config/karabiner/karabiner.json
```

</details>

### Documentation

- [Installation Guide](docs/INSTALLATION-GUIDE.md) - Detailed walkthrough of each installation step
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## Updating

Use the `dotfiles` CLI to keep your configuration up-to-date:

```bash
dotfiles update    # Pull latest changes and re-run installer
dotfiles status    # Check if updates are available
dotfiles sync      # Preview incoming changes without applying
dotfiles health    # Run full health check
```

The `update` command remembers your installation preset (minimal/core/full) and re-applies it automatically.

For manual updates:
```bash
cd ~/dotfiles && git pull
```

Then reload your shell: `source ~/.zshrc`

## Uninstalling

To remove the dotfiles installation:

```bash
# Remove symlinks only
./scripts/install/uninstall.sh

# Remove symlinks and restore original configs from backup
./scripts/install/uninstall.sh --restore-backup

# Full uninstall including Homebrew packages
./scripts/install/uninstall.sh --restore-backup --remove-brew-packages
```

The uninstall script uses your saved preset to determine which packages to remove.

## Key Features

### Zsh
- Powerlevel10k prompt with instant prompt
- fzf integration for fuzzy finding
- Lazy-loaded completions for performance
- Custom aliases and functions

### Tmux
- Backtick (`` ` ``) as prefix key
- Vim-style navigation
- Session save/restore (tmux-resurrect + continuum)
- fzf session/window switcher with ⚡ indicators for Claude Code alerts
- Dracula theme

### Neovim
- lazy.nvim plugin manager
- LSP support (TypeScript, Go, Python, Lua, C#)
- Telescope fuzzy finder
- GitHub Copilot (disabled for sensitive files)
- Treesitter syntax highlighting

### AI Coding Assistants
- Claude Code (with tmux alert integration)
- Gemini CLI (with tmux alert integration)
- OpenCode

### Hammerspoon
- Auto-centre windows for specified apps
- CLI enabled via IPC

### Ghostty
- Dracula colour scheme
- Zsh shell integration
- macOS optimised (glass icon, left Option as Alt)

### Karabiner Elements
- Caps Lock to Escape (Ghostty only)
- Right Option to Left Control
- UK keyboard layout fixes for Apple keyboards

### Dana Project Launcher
The `dana` script creates a tmux session with pre-configured windows:

| Window | Name | Directory | Purpose |
|--------|------|-----------|---------|
| 1 | backend | ~/src/dana/backend | Backend development |
| 2 | web | ~/src/dana/web | Web frontend |
| 3 | mobile | ~/src/dana/mobile | Mobile app |
| 4 | tools | split panes | Left: `npx expo`, Right: `bun dev` |
| 5 | commit-and-push | ~/src/dana | Git operations |
| 6 | zsh | ~ | General shell |

## Keybinding Quick Reference

### Tmux
| Action | Keybinding |
|--------|------------|
| Prefix | `` ` `` |
| Help | `` ` h `` |
| Save session | `` ` w `` |
| Session switcher | `` ` s `` |
| Window switcher | `` ` f `` |
| Rename window | `Opt+r` |
| Close pane | `Opt+s` |
| Close window | `Opt+x` |
| Equalise sizes | `Opt+Shift+0` |
| URL picker | `Opt+y` |
| Undo pane/window | `Opt+u` |

### Neovim
| Action | Keybinding |
|--------|------------|
| Leader | `Space` |
| Help | `` ` h `` (in tmux) |
| Find files | `Space sf` |
| Live grep | `Space sg` |
| File explorer | `Space e` |
| Git (LazyGit) | `Space g` |
| Format | `Space f` |
