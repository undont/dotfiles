<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/assets/logo-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset=".github/assets/logo-light.svg">
  <img alt="dotfiles" src=".github/assets/logo-dark.svg" width="480">
</picture>

**Personal configuration files for zsh, tmux, neovim, ghostty, git and much more.**

[![CI](https://github.com/seanhalberthal/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/seanhalberthal/dotfiles/actions/workflows/ci.yml)
[![Zsh Startup](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/seanhalberthal/fa735d81db7a1bfb7662671f293e4c35/raw/zsh-startup.json)](https://github.com/seanhalberthal/dotfiles/actions/workflows/ci.yml)
[![macOS](https://img.shields.io/badge/macOS-compatible-A2AAAD?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Linux](https://img.shields.io/badge/Linux-compatible-blue?logo=linux&logoColor=white)](https://www.linux.org/)
[![Neovim](https://img.shields.io/badge/Neovim-0.11+-57A143?logo=neovim&logoColor=white)](https://neovim.io/)
[![Tmux](https://img.shields.io/badge/Tmux-3.3+-1BB91F?logo=tmux&logoColor=white)](https://github.com/tmux/tmux)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

[Quick Start](#quick-start) · [Features](#-whats-inside) · [Themes](#-themes) · [Keybindings](#-keybindings) · [Docs](#documentation)

</div>

---

## Quick Start

**Prerequisites** — macOS or Linux. Fresh macOS? Run `xcode-select --install` first.

```bash
git clone https://github.com/seanhalberthal/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh            # Full install (default)
```

### Install Presets

| Preset | Components | Use Case |
|--------|------------|----------|
| `--minimal` | zsh, tmux | Servers, remote machines, SSH |
| `--core` | + nvim, ghostty, AI/CLI tools, launchers | Linux desktop, cross-platform dev |
| `--full` | + Hammerspoon, Karabiner | macOS power user (default) |

The installer backs up existing configs, installs Homebrew packages filtered by preset, creates symlinks, sets up plugin managers, and runs a health check. Your preset is saved so `dotfiles update` remembers it.

<details>
<summary><b>All installation options</b></summary>

```bash
./install.sh              # Full installation (default)
./install.sh --minimal    # Lightweight server setup
./install.sh --core       # Cross-platform dev setup
./install.sh --full       # Everything including macOS apps
./install.sh --skip-brew  # Skip Homebrew/package installation
./install.sh --skip-backup # Skip backing up existing configs
./install.sh --check-only  # Only run prerequisite and health checks
```

</details>

<details>
<summary><b>Post-installation steps</b></summary>

The installer detects what's already configured and only shows steps you still need:

1. **Restart your terminal** or run `source ~/.zshrc`
2. **Install tmux plugins** — open tmux and press `` ` + I ``
3. **Configure Neovim** — open nvim, plugins install automatically
4. **Add secrets** — edit `~/.config/zsh/secrets.zsh` with your API keys
5. **Install Node.js** — `fnm install --lts && fnm default lts-latest`
6. **Configure project directories** — `dotfiles set dev ~/src` (also prompted during install)
7. **Verify** — run `./scripts/install/health-check.sh`

</details>

---

## ✨ What's Inside

### Zsh — Fast, Framework-Based Shell

- **Powerlevel10k** prompt with instant prompt and git status
- **Framework architecture** — `~/.zshrc` is your personal file, sourcing `dotfiles.zsh` as a shared framework (no git conflicts)
- **fzf everywhere** — `Ctrl+R` history, `Ctrl+T` files, `Opt/Alt+C` directories
- **Performance** — lazy-loaded completions, fnm (~5ms) over nvm (~300ms), cached eval for direnv/fzf
- **Tab completion** for `dotfiles` / `dot`, `trestore`, `tkill`, `tattach`
- **Handy aliases** — `gs` (git status), `gl` (git log), `gfp` (fetch + prune), `gpr` (prune local branches gone from remote), `tattach` (attach or restore from backup), `cdb`/`cdf` (browser-style directory back/forward), `Opt+A` (directory history picker), `cl` (full terminal reset), `drs` (sync repo paths to gh-dash), `brewup`, `nvim-sync`, `mkcd`, and more — run `dot aliases` for the full list

### Tmux — 60+ Custom Scripts, One Cohesive Workflow

> Backtick (`` ` ``) prefix with vim-style navigation, 11 script categories, and 6 TPM plugins.

- **Undo system** (`Opt/Alt+u`) — accidentally closed a pane or window? Restore it with full directory, scrollback, and layout
- **Session save/restore** — tmux-resurrect + continuum with **per-session backups** (custom extension splits combined saves into individual files)
- **Launcher picker** (`` ` p ``) — create, run, and manage session launchers with an interactive wizard
- **Multi-agent alerts** — coloured indicators in session lists when AI agents need attention (⚡ Claude, 🔮 OpenCode) with auto-clearing
- **Command exit alerts** — switch away from any command and get a ✓/✗ alert when it finishes automatically
- **Instance management** — list, create, and kill running instances of Claude, OpenCode, and nvim from fzf pickers
- **Navigation history** (`` ` - `` / `` ` = ``) — browser-style back/forward across windows and sessions
- **URL picker** (`` ` y ``) — grab URLs from scrollback via fzf popup
- **Dotfiles sync indicator** — status bar shows `↓` `↑` `↕` when updates are available
- **Local overrides** — `~/.config/tmux/local.conf` survives theme changes and updates

### Neovim — Modular Config, Diverse Tooling

> Based on kickstart.nvim with lazy.nvim, Treesitter, and 10 language servers via Mason.

- **LSP** — TypeScript, Go, Python, Lua, C#/.NET (Roslyn), ESLint, Bash, CSS, HTML, YAML
- **Git** — LazyGit (status, blame, diff), gitsigns (inline decorations, hunk navigation)
- **PR review** — Octo.nvim for GitHub PRs + diffview for side-by-side diffs and merge conflict resolution
- **Build picker** (`Space q`) — auto-detects Go, TypeScript, .NET, and Makefile projects
- **Test runner** — Neotest with three adapters: .NET, Go, and Vitest/Bun
- **Navigation** — flash.nvim (jump), grug-far (project-wide search & replace), oil.nvim (file ops), trouble.nvim (diagnostics)
- **Multiple cursors** — vim-visual-multi (`Ctrl+n`, `Alt+↓/↑`)
- **Markdown** — mkdnflow with list continuation, todo toggles, table formatting
- **Colourschemes** — 15 hand-crafted + generatable from 438 Ghostty themes, self-contained Lua files with no plugin deps
- **GitHub Copilot** with security (disabled for `.env`, credentials, secrets)
- **Searchable cheatsheet** — `Space ?` opens a filterable keybinding reference
- **Local overrides** — `~/.config/nvim/local.lua` survives updates

### Ghostty, Hammerspoon & Karabiner

- **Ghostty** — colour scheme follows active theme, zsh shell integration, macOS optimised, local override file
- **Hammerspoon** — auto-centre windows for 7+ apps (Ghostty, Arc, JetBrains, Discord, Slack, Notion), CLI via IPC, local override file
- **Karabiner** — Caps Lock to Escape, Right Option to Control (Ghostty + JetBrains), UK keyboard layout fixes

### Session Launchers

Press `` ` p `` to open the launcher picker — shell scripts that create pre-configured tmux sessions.

- **Built-in**: `dev` (dev session), `github` (gh-dash), `btop` (system monitor)
- **Wizard**: press `n` to scaffold a new launcher interactively
- **User launchers** in `~/.config/dotfiles/launchers/` override repo launchers by name
- **Set**: press `s` to configure `DEV_ROOT` and `PROJECTS_ROOT` for dynamic project discovery

### Dotfiles CLI 

```bash
dotfiles update    # Smart incremental update (only re-runs changed steps)
dotfiles status    # Version, sync status, and local changes
dotfiles health    # Full health check (symlinks, plugins, env vars)
dotfiles links     # Show all managed symlinks and their status
dotfiles theme     # List, switch, or generate themes
dotfiles aliases   # Browse all shell aliases and shortcuts
dotfiles notes     # Browse full changelog in a pager
dotfiles version   # Show current version, preset, and theme
dotfiles edit      # Open dotfiles in $EDITOR
```

> `dot` is a shorthand alias for `dotfiles` — both work interchangeably with full tab completion.

---

## 🎨 Themes
One command changes **everything**. Switch tmux, terminal, neovim, fzf, gh-dash, and lazygit all at once — no restart, no manual config edits.

```bash
dotfiles theme dracula                # Switch everything, instantly
dotfiles theme generate zenburn       # Generate a new theme from Ghostty
```

### Theme Generator

Turn any of Ghostty's **438 built-in themes** into a complete, coordinated colour system. The Lua pipeline:

1. **Parses** a Ghostty palette (16 ANSI colours + foreground/background)
2. **Derives** semantic roles — 6 accent colours, selection, secondary surfaces
3. **Corrects** for [WCAG 2.1](https://www.w3.org/TR/WCAG21/) accessibility (4.5:1 minimum contrast ratio)
4. **Outputs** a `.theme` file + a self-contained neovim colourscheme (no plugin deps)

```bash
dotfiles theme generate list          # Browse all 438 Ghostty themes
dotfiles theme generate "Catppuccin Latte"  # Generate and switch to it
```

Press `` ` t `` inside tmux to browse **all** themes in an fzf popup. Selecting a Ghostty theme auto-generates and applies it on the fly — no separate generate step needed.

See [docs/THEME-SYSTEM.md](docs/THEME-SYSTEM.md) for the full architecture.

### Hand-Crafted Themes

**15 curated themes** with carefully tuned palettes, each passing WCAG 2.1 contrast checks:

> Dracula · Catppuccin Mocha · Tokyo Night · Nord · Rosé Pine · Kanagawa · Gruvbox · Maple · Synthwave · One Dark · Monokai · Nightfox · Everforest · Ayu Dark · Solarized

**Local overrides survive every theme switch** — cursor style, fonts, and extra keybindings persist in files that are never overwritten:

| App | Override File |
|-----|--------------|
| Tmux | `~/.config/tmux/local.conf` |
| Neovim | `~/.config/nvim/local.lua` |
| Ghostty | `~/.config/ghostty/local` |
| gh-dash | `~/.config/gh-dash/local.yml` |
| LazyGit | `~/.config/lazygit/local.yml` |
| Hammerspoon | `~/.hammerspoon/local.lua` |
| Zsh | `~/.zshrc` (your personal config) |

---

## ⌨ Keybindings

<table>
<tr><td>

### Tmux

| Action | Keybinding |
|--------|------------|
| Prefix | `` ` `` |
| Help popup | `` ` h `` |
| Launcher picker | `` ` p `` |
| Theme picker | `` ` t `` |
| Save session | `` ` w `` |
| Session switcher | `` ` s `` |
| Window switcher | `` ` f `` |
| URL picker | `` ` y `` |
| Navigate back | `` ` - `` |
| Navigate forward | `` ` = `` |
| Rename window | `Opt/Alt+r` |
| Close pane | `Opt/Alt+s` |
| Close window | `Opt/Alt+x` |
| Undo pane/window | `Opt/Alt+u` |
| Reload local overrides | `` ` r `` |

</td><td>

### Neovim

| Action | Keybinding |
|--------|------------|
| Leader | `Space` |
| Cheatsheet | `Space ?` |
| Find files | `Space sf` |
| Live grep | `Space sg` |
| File explorer | `Space e` |
| Git (LazyGit) | `Space g` |
| Build (quickfix) | `Space q` |
| Format | `Space f` |
| Test nearest | `Space tt` |
| Diagnostics | `Space xx` |
| PR diff review | `Space dp` |

</td></tr>
</table>

---

## Performance

Zsh startup time is benchmarked in CI on every push and PR. If the median startup exceeds 500ms, the benchmark job fails — preventing regressions from landing.

---

## Uninstalling

```bash
./scripts/install/uninstall.sh                                    # Remove symlinks only
./scripts/install/uninstall.sh --restore-backup                   # Restore original configs
./scripts/install/uninstall.sh --restore-backup --remove-brew-packages  # Full uninstall
```

---

## Contents

<details>
<summary><b>Repository structure</b></summary>

```
dotfiles/
├── zsh/              # Zsh shell configuration
│   ├── dotfiles.zsh  # Shared framework (sourced by ~/.zshrc)
│   ├── zshrc         # Backwards-compat wrapper for legacy symlinks
│   ├── zshrc.template # Template for user's personal ~/.zshrc
│   ├── zprofile      # Login shell config
│   └── p10k.zsh      # Powerlevel10k theme
├── tmux/             # Tmux terminal multiplexer
│   ├── tmux.conf.template # Config template (processed by dotfiles theme)
│   ├── scripts/      # 60+ custom scripts across 11 categories
│   ├── plugins/      # TPM-managed plugins
│   └── tmux-help.template # Keybinding help (renders Opt/Alt per platform)
├── nvim/             # Neovim configuration
│   ├── init.lua      # Entry point
│   ├── colors/       # Self-contained colourschemes (15 hand-crafted + generated)
│   ├── cheatsheet.txt # Searchable keybinding reference (Space ?)
│   ├── snippets/     # Custom LuaSnip snippets
│   └── lua/custom/   # Modular config (14 plugin files)
│       ├── core/     # Options, keymaps, autocmds, theme, quickfix
│       └── plugins/  # Plugin configurations
├── lazygit/          # LazyGit configuration
├── lazydocker/       # LazyDocker configuration
├── btop/             # System monitor configuration
├── launchers/        # Session launch scripts (picker: prefix + p)
│   ├── dev          # Dev session launcher (zsh + nvim + claude)
│   ├── github        # gh-dash session
│   └── btop          # System monitor session
├── hammerspoon/      # macOS automation (auto-centre windows)
├── gh-dash/          # GitHub dashboard (themed, keybindings, local overrides, dash-repo-sync)
├── ghostty/          # Terminal emulator (themed via dotfiles theme)
├── karabiner/        # Keyboard customisation
├── scripts/          # Installation and utility scripts
│   ├── dotfiles      # CLI for managing dotfiles (includes theme management)
│   ├── install/      # Installer modules
│   ├── hooks/        # Agent alert, command exit alert + buffer sync hooks
│   ├── tests/        # Test suites
│   └── _lib/         # Shared shell libraries
├── themes/           # 15 hand-crafted + generated theme definitions (WCAG checked)
├── docs/             # Documentation
│   ├── AGENT-HOOKS.md
│   ├── CMD-ALERTS.md
│   ├── INSTALLATION-GUIDE.md
│   ├── THEME-SYSTEM.md
│   └── TROUBLESHOOTING.md
└── Brewfile          # Homebrew dependencies (preset-filtered)
```

</details>

<details>
<summary><b>Manual symlink commands</b></summary>

```bash
# Zsh (template creates ~/.zshrc which sources dotfiles.zsh)
cp ~/dotfiles/zsh/zshrc.template ~/.zshrc  # Only if ~/.zshrc doesn't exist
ln -sf ~/dotfiles/zsh/zprofile ~/.zprofile
ln -sf ~/dotfiles/zsh/p10k.zsh ~/.p10k.zsh

# Tmux (symlink entire directory, config is generated)
ln -sf ~/dotfiles/tmux ~/.tmux
# Config generated by: dotfiles theme dracula

# Neovim
ln -sf ~/dotfiles/nvim ~/.config/nvim

# Session launchers
mkdir -p ~/.local/launchers
ln -sf ~/dotfiles/launchers/dev ~/.local/launchers/dev

# Dotfiles CLI + utilities
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/scripts/dotfiles ~/.local/bin/dotfiles
ln -sf ~/dotfiles/gh-dash/dash-repo-sync ~/.local/bin/dash-repo-sync

# LazyGit (symlinked base + local override)
mkdir -p ~/.config/lazygit
ln -sf ~/dotfiles/lazygit/config.yml ~/.config/lazygit/config.yml
cp -n ~/dotfiles/lazygit/local.yml.template ~/.config/lazygit/local.yml

# Hammerspoon (symlinked init.lua + local override)
ln -sf ~/dotfiles/hammerspoon/init.lua ~/.hammerspoon/init.lua
cp -n ~/dotfiles/hammerspoon/local.lua.template ~/.hammerspoon/local.lua

# Ghostty (config generated by dotfiles theme to ~/.config/ghostty/config)
mkdir -p ~/.config/ghostty

# Karabiner Elements (copy-on-install — user-owned after first install)
mkdir -p ~/.config/karabiner
cp -n ~/dotfiles/karabiner/karabiner.json ~/.config/karabiner/karabiner.json
```

</details>

## Documentation

- [Agent Hooks](docs/AGENT-HOOKS.md) — Setup guide for agent alert hooks (Claude Code, OpenCode)
- [Command Exit Alerts](docs/CMD-ALERTS.md) — Auto ✓/✗ alerts when commands finish in other windows
- [Installation Guide](docs/INSTALLATION-GUIDE.md) — Detailed walkthrough of each installation step
- [Theme System](docs/THEME-SYSTEM.md) — How themes work, the Ghostty theme generator, and WCAG contrast checks
- [Troubleshooting](docs/TROUBLESHOOTING.md) — Common issues and solutions
