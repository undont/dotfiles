# Setup Walkthrough

A detailed explanation of what each step of the installation process does and why.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Install Presets](#install-presets)
- [Installation Steps](#installation-steps)
  - [Step 1: Install/Update Homebrew](#step-1-installupdate-homebrew)
  - [Step 2: Install Packages from Brewfile](#step-2-install-packages-from-brewfile)
  - [Step 3: Check Prerequisites](#step-3-check-prerequisites)
  - [Step 4: Backup Existing Configuration](#step-4-backup-existing-configuration)
  - [Step 5: Create Symlinks](#step-5-create-symlinks)
  - [Step 6: Install Plugin Managers](#step-6-install-plugin-managers)
  - [Step 7: Setup Secrets File](#step-7-setup-secrets-file)
  - [Step 8: Run Health Check](#step-8-run-health-check)
- [Command-Line Options](#command-line-options)
- [Post-Installation](#post-installation)
- [What Gets Installed](#what-gets-installed)
- [Error Handling and Rollback](#error-handling-and-rollback)
- [Uninstalling](#uninstalling)

---

## Overview

The installation script (`install.sh`) orchestrates a complete development environment setup. It's designed to be:

- **Safe**: Backs up existing configuration before making changes
- **Recoverable**: Supports automatic rollback on failure
- **Flexible**: Offers presets and skip options for customised installations
- **Transparent**: Provides detailed progress feedback with confirmation prompts

The entire process typically takes 5-15 minutes depending on network speed and existing packages.

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/your-username/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run full installation (default)
./install.sh

# Or choose a specific preset
./install.sh --core       # Cross-platform dev setup
./install.sh --minimal    # Lightweight server setup

# Or check prerequisites only (no changes made)
./install.sh --check-only
```

---

## Install Presets

The installer supports three presets to customise what gets installed:

| Preset | Flag | Components | Use Case |
|--------|------|------------|----------|
| **Minimal** | `--minimal` | zsh, tmux | Servers, remote machines, SSH environments |
| **Core** | `--core` | + nvim, ghostty, AI/CLI tools, session launch scripts | Linux desktop, cross-platform development |
| **Full** | `--full` | + Hammerspoon, Karabiner | macOS power user (default) |

### Preset Details

**Minimal** (`--minimal`):
- Shell: zsh with Powerlevel10k prompt
- Terminal multiplexer: tmux with custom keybindings
- Ideal for: SSH servers, containers, remote development

**Core** (`--core`):
- Everything in Minimal, plus:
- Editor: Neovim with LSP, Telescope, and plugins
- Terminal: Ghostty configuration
- AI Tools: Claude Code, development CLI tools
- Custom scripts: `tnew`, `dana`
- Ideal for: Linux desktops, cross-platform setups

**Full** (`--full`, default):
- Everything in Core, plus:
- Hammerspoon: macOS window automation
- Karabiner Elements: keyboard customisation
- Ideal for: macOS primary workstations

### How Presets Work

1. **Brewfile filtering**: The `Brewfile` is organised into sections marked with `# @preset: minimal/core/full`. Only packages for your selected preset (and below) are installed.

2. **Selective symlinks**: Only configuration files relevant to your preset are symlinked.

3. **Targeted prerequisites**: The prerequisite check only validates tools needed for your preset.

4. **Confirmation prompt**: Before installation begins, you'll see which preset is selected and be asked to confirm.

```
╔════════════════════════════════════════════╗
║           Dotfiles Installation            ║
╚════════════════════════════════════════════╝

Dotfiles directory: /Users/you/dotfiles

Selected preset: core
Components: zsh, tmux, nvim, ghostty, AI/CLI tools, session launch scripts

Proceed with core installation? [y/N]
```

---

## Installation Steps

### Step 1: Install/Update Homebrew

**Script**: `scripts/install/install-homebrew.sh`

**What it does**:
- Checks if Homebrew is already installed
- If not present: installs Xcode Command Line Tools (macOS), then Homebrew
- If present: runs `brew update` to fetch latest package definitions
- Disables Homebrew analytics for privacy
- Verifies installation by checking `brew --version`

**Why this matters**:
Homebrew is the package manager used to install all other tools. Without it, you'd need to manually download and configure each tool individually.

**Platform differences**:

| Platform | Homebrew Path | Notes |
|----------|---------------|-------|
| macOS (Apple Silicon) | `/opt/homebrew` | Default for M1/M2/M3 Macs |
| macOS (Intel) | `/usr/local` | Default for Intel Macs |
| Linux | `/home/linuxbrew/.linuxbrew` | Linuxbrew |

**What you'll see**:
```
[1/8] Installing/updating Homebrew...
  ✓ Homebrew already installed
  ✓ Updated Homebrew
  ✓ Analytics disabled
```

---

### Step 2: Install Packages from Brewfile

**Script**: `scripts/install/install-packages.sh`

**What it does**:
- Runs `brew bundle install` using the `Brewfile` in the repository root
- Installs all formulae (command-line tools) and casks (GUI applications)
- Runs post-installation setup for specific tools:
  - **fzf**: Installs shell keybindings (Ctrl+R for history, Ctrl+T for files)
  - **fnm**: Reminds you to install Node.js
  - **pipx**: Ensures Python package manager is configured

**Why this matters**:
The Brewfile is a declarative list of all tools needed for the development environment. Using `brew bundle` ensures consistent installations across machines and makes it easy to keep environments in sync.

**Categories of packages installed**:

| Category | Examples |
|----------|----------|
| Shell & Terminal | zsh, tmux, powerlevel10k, fzf, direnv |
| Editors | neovim |
| AI Tools | claude (Claude Code) |
| Git Tools | gh (GitHub CLI), lazygit |
| Search & Navigation | ripgrep, fd, tree, jq, bat |
| Languages | fnm (Node.js), bun, Go, Python 3.13 |
| Databases | PostgreSQL, mongosh, sqld |
| macOS Apps | ghostty, hammerspoon, karabiner-elements |
| Fonts | Meslo LG Nerd Font, JetBrains Mono Nerd Font |

**What you'll see**:
```
[2/8] Installing packages from Brewfile...
  Installing neovim...
  Installing ripgrep...
  Installing tmux...
  ...
  ✓ All packages installed
  ✓ fzf keybindings installed
```

---

### Step 3: Check Prerequisites

**Script**: `scripts/install/check-prerequisites.sh`

**What it does**:
- Verifies all required tools are installed and accessible in PATH
- Categorises tools as required or optional
- Provides installation hints for any missing tools
- Returns success only if all required tools are present

**Why this matters**:
This step catches configuration issues early. If a required tool isn't properly installed (perhaps due to PATH issues), you'll know immediately rather than encountering cryptic errors later.

**Tools checked**:

| Category | Required | Optional |
|----------|----------|----------|
| Core | git, zsh, tmux, nvim, fzf, go, ripgrep | fd, bat |
| Development | gh, direnv, jq, tree, shellcheck | fnm, python3 |
| AI & Tools | claude, dotnet, cmake | gcloud |
| Databases | psql, mongosh, sqld | - |
| macOS | Karabiner Elements | Hammerspoon |

**What you'll see**:
```
[3/8] Checking prerequisites...
  ✓ git
  ✓ zsh
  ✓ tmux
  ✓ nvim
  ...
  ✓ All prerequisites satisfied
```

---

### Step 4: Backup Existing Configuration

**Script**: `scripts/install/backup-existing.sh`

**What it does**:
- Creates a timestamped backup directory: `~/.dotfiles-backup/YYYYMMDD-HHMMSS/`
- Copies any existing configuration files that will be replaced
- Records the backup location for potential rollback

**Why this matters**:
If you have existing configurations (especially customised ones), this step ensures they're preserved. You can always restore your original setup if needed.

**Files backed up (if they exist)**:

| Component | Files/Directories |
|-----------|-------------------|
| Zsh | `.zshrc`, `.zprofile`, `.p10k.zsh`, `.zsh/` |
| Tmux | `.tmux.conf`, `.tmux/` |
| Neovim | `.config/nvim/` |
| Hammerspoon | `.hammerspoon/` |
| Ghostty | `.config/ghostty/` |
| Karabiner | `.config/karabiner/` |

**What you'll see**:
```
[4/8] Backing up existing configuration...
  Created backup directory: ~/.dotfiles-backup/20260111-143022/
  ✓ Backed up .zshrc
  ✓ Backed up .tmux.conf
  ✓ Backed up .config/nvim
```

**Skip this step**:
```bash
./install.sh --skip-backup
```

---

### Step 5: Create Symlinks

**Script**: `scripts/install/create-symlinks.sh`

**What it does**:
- Removes any old symlinks that point to incorrect locations
- Creates parent directories as needed (e.g., `~/.config/`)
- Creates symbolic links from the dotfiles repository to your home directory
- Records all created symlinks for rollback capability

**Why this matters**:
Symlinks are the core mechanism that makes dotfiles work. Instead of copying files, symlinks point to files in the repository. This means:
- Changes you make are automatically tracked in git
- `git pull` immediately updates your configuration
- You can easily sync configurations across machines

**Symlinks created**:

```
Zsh:
  ~/.zshrc           -> ~/dotfiles/zsh/.zshrc
  ~/.zprofile        -> ~/dotfiles/zsh/.zprofile
  ~/.p10k.zsh        -> ~/dotfiles/zsh/.p10k.zsh
  ~/.zsh             -> ~/dotfiles/zsh/.zsh

Tmux:
  ~/.tmux.conf       -> ~/dotfiles/tmux/.tmux.conf
  ~/.tmux            -> ~/dotfiles/tmux/.tmux

Neovim:
  ~/.config/nvim     -> ~/dotfiles/nvim

Hammerspoon:
  ~/.hammerspoon     -> ~/dotfiles/hammerspoon

Ghostty:
  ~/.config/ghostty/config -> ~/dotfiles/ghostty/config

Karabiner:
  ~/.config/karabiner/karabiner.json -> ~/dotfiles/karabiner/karabiner.json

Session Launchers:
  ~/.local/launchers/tnew  -> ~/dotfiles/launchers/tnew
  ~/.local/launchers/dana  -> ~/dotfiles/launchers/dana
  ~/.local/launchers/code  -> ~/dotfiles/launchers/code

Dotfiles CLI:
  ~/.local/bin/dotfiles    -> ~/dotfiles/scripts/dotfiles
```

**What you'll see**:
```
[5/8] Creating symlinks...
  ✓ ~/.zshrc -> ~/dotfiles/zsh/.zshrc
  ✓ ~/.tmux.conf -> ~/dotfiles/tmux/.tmux.conf
  ✓ ~/.config/nvim -> ~/dotfiles/nvim
  ...
```

---

### Step 6: Install Plugin Managers

**What it does**:
- **TPM (Tmux Plugin Manager)**: Clones the repository to `~/.tmux/plugins/tpm`
- **lazy.nvim**: Auto-installed by Neovim configuration on first launch

**Why this matters**:
Plugin managers handle downloading, updating, and loading plugins for tmux and Neovim. Without them, you'd need to manually manage dozens of plugins.

**TPM (Tmux)**:
- Installed to: `~/.tmux/plugins/tpm`
- Plugins defined in: `~/.tmux.conf` (look for `set -g @plugin`)
- Install plugins: Inside tmux, press `` ` + I `` (backtick, then capital I)
- Update plugins: Inside tmux, press `` ` + U ``

**lazy.nvim (Neovim)**:
- Auto-installed on first Neovim launch
- Plugins defined in: `~/.config/nvim/lua/custom/plugins/`
- Install/update: Run `:Lazy sync` in Neovim

**What you'll see**:
```
[6/8] Installing plugin managers...
  ✓ TPM installed to ~/.tmux/plugins/tpm
  ✓ lazy.nvim will auto-install on first Neovim launch
```

---

### Step 7: Setup Secrets File

**What it does**:
- Creates `~/.zsh/.secrets.zsh` if it doesn't exist
- Copies from template (`zsh/.zsh/.secrets.zsh.template`) if available
- Sets file permissions to 600 (read/write for owner only)

**Why this matters**:
The secrets file is where you store sensitive environment variables like API keys. It's:
- Excluded from git (listed in `.gitignore`)
- Only readable by you (permissions 600)
- Sourced by `.zshrc` on shell startup

**Example secrets file content**:
```bash
# ~/.zsh/.secrets.zsh

# API Keys
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."

# Database URLs
export DATABASE_URL="postgres://user:pass@localhost:5432/db"

# Cloud credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

**What you'll see**:
```
[7/8] Setting up secrets file...
  ✓ Created ~/.zsh/.secrets.zsh from template
  ✓ Set permissions to 600
  ! Remember to add your API keys to ~/.zsh/.secrets.zsh
```

---

### Step 8: Run Health Check

**Script**: `scripts/install/health-check.sh`

**What it does**:
- Verifies all symlinks point to correct locations
- Checks that plugin managers are installed
- Validates secrets file exists with correct permissions
- Tests that custom scripts are accessible in PATH

**Why this matters**:
The health check confirms the installation completed successfully. It catches issues like broken symlinks or missing directories before you encounter problems.

**Checks performed**:

| Check | What it verifies |
|-------|------------------|
| Symlinks | All point to correct dotfiles locations |
| TPM | `~/.tmux/plugins/tpm` exists |
| lazy.nvim | `~/.local/share/nvim/lazy` exists (after first nvim launch) |
| Secrets | `~/.zsh/.secrets.zsh` exists with mode 600 |
| Scripts | `tnew` and `dana` commands are in PATH |

**What you'll see**:
```
[8/8] Running health check...
  ✓ All symlinks verified
  ✓ TPM installed
  ✓ Secrets file configured
  ✓ Custom scripts in PATH

Installation complete!
```

---

## Command-Line Options

### Presets

| Option | Description |
|--------|-------------|
| `--minimal` | Install zsh + tmux only (servers, remote machines) |
| `--core` | Install zsh, tmux, nvim, ghostty, AI/CLI tools |
| `--full` | Install everything including macOS apps (default) |

### Other Options

| Option | Description |
|--------|-------------|
| `--skip-brew` | Skip Homebrew installation and package installation (steps 1-2) |
| `--skip-backup` | Skip backing up existing configuration (step 4) |
| `--check-only` | Only run prerequisite and health checks, make no changes |
| `-h`, `--help` | Show help message |

**Examples**:
```bash
# Full installation (default)
./install.sh

# Cross-platform dev setup
./install.sh --core

# Lightweight server setup
./install.sh --minimal

# Skip Homebrew (if packages already installed)
./install.sh --skip-brew

# Combine options
./install.sh --core --skip-backup

# Just check if everything is set up correctly
./install.sh --check-only
```

---

## Post-Installation

After the installation completes, you'll need to:

### 1. Reload Your Shell

```bash
# Either restart your terminal, or run:
source ~/.zshrc
```

### 2. Install Tmux Plugins

```bash
# Start tmux
tmux

# Press prefix + I to install plugins
# (prefix is backtick ` by default)
```

### 3. Launch Neovim

```bash
# First launch triggers lazy.nvim plugin installation
nvim
```

Wait for all plugins to install, then restart Neovim.

### 4. Install Node.js

```bash
# Install latest LTS version
fnm install --lts
fnm default lts-latest

# Verify
node --version
```

### 5. Add Your Secrets

```bash
# Edit secrets file
nvim ~/.zsh/.secrets.zsh

# Add your API keys and credentials
```

---

## What Gets Installed

### Shell Environment (Zsh)

- **Powerlevel10k**: Fast, customisable prompt with git status, execution time, etc.
- **zsh-autosuggestions**: Fish-like autosuggestions based on history
- **fzf integration**: Fuzzy finding for history (Ctrl+R), files (Ctrl+T), directories (Alt+C)
- **direnv**: Automatic environment variable loading per directory

### Terminal Multiplexer (Tmux)

- **Prefix key**: Backtick (`` ` ``) for single-keystroke access
- **Mouse support**: Click to select panes, drag to resize
- **Vim-style navigation**: hjkl keys for pane movement
- **Session persistence**: Survives terminal restarts (via tmux-resurrect)
- **Agent alerts**: Visual indicators for AI agent activity (⚡ Claude, 🔮 OpenCode)

### Editor (Neovim)

- **lazy.nvim**: Plugin manager with lazy loading
- **LSP support**: Autocomplete, go-to-definition, error checking
- **Treesitter**: Advanced syntax highlighting
- **Telescope**: Fuzzy finder for files, grep, buffers
- **GitHub Copilot**: AI code completion (requires authentication)

### macOS Applications (Casks)

- **Ghostty**: Fast, GPU-accelerated terminal emulator
- **Hammerspoon**: Lua-based automation (window management, etc.)
- **Karabiner Elements**: Keyboard customisation

### Fonts

- **Meslo LG Nerd Font**: Default terminal font with icon support
- **JetBrains Mono Nerd Font**: Alternative programming font

---

## Error Handling and Rollback

### Automatic Recovery

The installation script includes robust error handling:

1. **Error trapping**: Catches failures immediately
2. **State recording**: Tracks which steps completed successfully
3. **Automatic rollback**: On failure, attempts to restore previous state

### Manual Rollback

If you need to undo the installation:

```bash
# Run the rollback script
./scripts/install/rollback.sh
```

This will:
- Remove all symlinks created during installation
- Restore files from the backup directory
- Clean up installation state

### Restoring from Backup

If automatic rollback doesn't work:

```bash
# Find your backup
ls ~/.dotfiles-backup/

# Restore specific files
cp ~/.dotfiles-backup/YYYYMMDD-HHMMSS/.zshrc ~/.zshrc
cp ~/.dotfiles-backup/YYYYMMDD-HHMMSS/.tmux.conf ~/.tmux.conf

# Or restore everything
cp -r ~/.dotfiles-backup/YYYYMMDD-HHMMSS/.* ~/
```

### Uninstalling

To completely remove the dotfiles installation:

```bash
# Remove symlinks only
./scripts/install/uninstall.sh

# Remove symlinks and restore original configs
./scripts/install/uninstall.sh --restore-backup

# Full uninstall including Homebrew packages
./scripts/install/uninstall.sh --restore-backup --remove-brew-packages
```

The uninstall script:
- Removes all symlinks created during installation
- Optionally restores files from your most recent backup
- Optionally removes Homebrew packages (filtered by your saved preset)
- Removes TPM plugins (with confirmation)
- Cleans up the preset configuration file

---

## Related Documentation

- [Troubleshooting Guide](./TROUBLESHOOTING.md) - Solutions for common issues
- [Zsh Configuration](../zsh/.zsh/README.md) - Detailed zsh documentation
- [Tmux Configuration](../tmux/.tmux/README.md) - Detailed tmux documentation
