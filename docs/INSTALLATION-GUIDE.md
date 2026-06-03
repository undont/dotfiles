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
  - [Step 7: Setup keyd (Linux)](#step-7-setup-keyd-linux)
  - [Step 8: Set Default Shell](#step-8-set-default-shell)
  - [Step 9: Setup Secrets File](#step-9-setup-secrets-file)
  - [Step 10: Run Health Check](#step-10-run-health-check)
  - [Step 11: Save Preset Configuration](#step-11-save-preset-configuration)
  - [Step 12: Configure Project Directories](#step-12-configure-project-directories)
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
| **Full** | `--full` | + Hammerspoon, Karabiner (macOS) / keyd (Linux) | Power user (default) |

### Preset Details

**Minimal** (`--minimal`):
- Shell: zsh with Powerlevel10k prompt
- Terminal multiplexer: tmux with custom keybindings
- Ideal for: SSH servers, containers, remote development

**Core** (`--core`):
- Everything in Minimal, plus:
- Editor: Neovim with LSP, Telescope, and plugins
- Terminal: Ghostty configuration
- AI Tools: OpenCode (brewed); Claude Code, Codex, Copilot CLIs install separately
- Session launchers (`dev`, `github`, `btop`, `docker`, `dotfiles`, `config`)
- Ideal for: Linux desktops, cross-platform setups

**Full** (`--full`, default):
- Everything in Core, plus:
- macOS: Hammerspoon (window automation), Karabiner Elements (keyboard customisation)
- Linux: keyd (keyboard remapping daemon, Karabiner equivalent)
- Ideal for: Primary workstations (macOS or Linux)

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
[1/12] Installing/updating Homebrew...
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
  - **fnm**: Reminds you to install Node.js (macOS via brew; Linux via manual install)
  - **uv**: Python package + tool manager (`uv tool install`, `uvx`)
- On Linux: fixes gcc/cc symlinks for native builds, installs Ghostty and fnm via system package manager or manual install

**Why this matters**:
The Brewfile is a declarative list of all tools needed for the development environment. Using `brew bundle` ensures consistent installations across machines and makes it easy to keep environments in sync.

**Categories of packages installed**:

| Category | Examples |
|----------|----------|
| Shell & Terminal | zsh, tmux, powerlevel10k, fzf, direnv, carapace, zoxide |
| Editors | neovim |
| AI Tools | opencode (Claude/Codex/Copilot install separately) |
| Git Tools | gh (GitHub CLI), lazygit, diffnav, act |
| Search & Navigation | ripgrep, fd, tree, jq, yq, bat, zoxide |
| Languages | fnm (Node.js), bun, Go, Python 3.13 + uv, openjdk, dotnet-sdk |
| Databases | postgresql@17, mongosh, sqld |
| macOS Apps | ghostty, hammerspoon, karabiner-elements, raycast, music-presence |
| Fonts | Meslo LG Nerd Font, JetBrains Mono Nerd Font |

**What you'll see**:
```
[2/12] Installing packages from Brewfile...
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
- Verifies the two tools needed to bootstrap the install: `git` and `brew`
- Provides installation hints if either is missing
- Returns success only if both are present

**Why this matters**:
The bootstrap check is deliberately minimal: every other tool (nvim, tmux, fzf, language toolchains, etc.) is installed by `brew bundle` in Step 2, so gating on them here would just produce false-MISSING noise on a fresh machine. The full toolchain is audited later by Step 10 (`health-check.sh`).

**Tools checked**:

| Tool | Hint if missing |
|------|-----------------|
| `git` | macOS: `xcode-select --install`; Linux: system package manager |
| `brew` | See https://brew.sh |

**What you'll see**:
```
[3/12] Checking prerequisites...
  ✓ git
  ✓ Homebrew
  ✓ Bootstrap prerequisites present: install can proceed.
```

---

### Step 4: Backup Existing Configuration

**Script**: `scripts/install/backup-existing.sh`

**What it does**:
- Creates a timestamped backup directory: `~/.dotfiles-backup/YYYYMMDD-HHMMSS-PID/`
- Copies any existing configuration files that will be replaced
- Records the backup location for potential rollback

**Why this matters**:
If you have existing configurations (especially customised ones), this step ensures they're preserved. You can always restore your original setup if needed.

**Files backed up (if they exist)**:

| Component | Preset | Files/Directories |
|-----------|--------|-------------------|
| Zsh | minimal | `.zshrc`, `.zprofile`, `.p10k.zsh`, `.zsh/` |
| Tmux | minimal | `.tmux.conf`, `.tmux/` |
| Neovim | core | `.config/nvim/` |
| Ghostty | core | `.config/ghostty/` |
| Yazi | core | `.config/yazi/` |
| Hammerspoon | full | `.hammerspoon/` |
| Karabiner | full | `.config/karabiner/` |

**What you'll see**:
```
[4/12] Backing up existing configuration...
  Created backup directory: ~/.dotfiles-backup/20260111-143022-12345/
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

**Symlinks and files created**:

```
Zsh (minimal):
  ~/.zshrc                    Created from template (personal file, not a symlink)
  ~/.zprofile              -> ~/dotfiles/zsh/zprofile
  ~/.p10k.zsh              -> ~/dotfiles/zsh/p10k.zsh

Tmux (minimal):
  ~/.tmux                  -> ~/dotfiles/tmux
  ~/.tmux.conf             -> ~/.config/tmux/tmux.conf  (generated by dotfiles theme)
  ~/.config/tmux/local.conf   Created from template (local overrides)

Dotfiles CLI (minimal):
  ~/.local/bin/dotfiles    -> ~/dotfiles/scripts/dotfiles

Neovim (core):
  ~/.config/nvim           -> ~/dotfiles/nvim
  ~/.config/nvim/local.lua    Created from template (local overrides)

Ghostty (core):
  ~/.config/ghostty/          Directory created (config generated by dotfiles theme)
  ~/.config/ghostty/local     Created from template (local overrides)

btop (core):
  ~/.config/btop/btop.conf -> ~/dotfiles/btop/btop.conf

Yazi (core):
  ~/.config/yazi           -> ~/dotfiles/yazi

LazyGit (core):
  ~/.config/lazygit/config.yml  -> ~/dotfiles/lazygit/config.yml   (all platforms)
  ~/.config/lazygit/local.yml      Created from template (local overrides)

LazyDocker (core):
  ~/Library/Application Support/lazydocker/config.yml  Copy from ~/dotfiles/lazydocker/config.yml (macOS)
  ~/.config/lazydocker/config.yml                      Copy from ~/dotfiles/lazydocker/config.yml (Linux)

Session Launchers (core):
  ~/.local/launchers/dev  -> ~/dotfiles/launchers/dev

Hammerspoon (full):
  ~/.hammerspoon           -> ~/dotfiles/hammerspoon

Karabiner (full):
  ~/.config/karabiner/karabiner.json -> ~/dotfiles/karabiner/karabiner.json
```

**What you'll see**:
```
[5/12] Creating symlinks...
  ✓ Created personal ~/.zshrc (sources dotfiles framework)
  ✓ ~/.zprofile -> ~/dotfiles/zsh/zprofile
  ✓ ~/.tmux -> ~/dotfiles/tmux
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
[6/12] Installing plugin managers...
  ✓ TPM installed to ~/.tmux/plugins/tpm
  ✓ lazy.nvim will auto-install on first Neovim launch
```

---

### Step 7: Setup keyd (Linux)

**Script**: `scripts/install/setup-keyd.sh`

**What it does**:
- Skipped on macOS (uses Karabiner Elements instead)
- Installs keyd via the system package manager if not present
- Deploys the keyd config from `keyd/default.conf` to `/etc/keyd/default.conf`
- Enables and starts the keyd systemd service
- Reloads the config if the service was already running

**Why this matters**:
keyd is a Linux keyboard remapping daemon, the equivalent of Karabiner Elements on macOS. It provides system-level key remapping that works across all applications, including:
- Caps Lock → Escape
- Right Alt → Control
- Grave/Tilde ↔ Non-US Backslash (Apple keyboard layout fix)

**What you'll see**:
```
[7/12] Setting up keyd (keyboard remapping)...
  ✓ Deployed keyd config to /etc/keyd/default.conf
  ✓ keyd service enabled and started
  ✓ keyd setup complete
```

On macOS, or if the full preset isn't selected:
```
  ⊘ Skipping keyd setup (macOS)
```

---

### Step 8: Set Default Shell

**Script**: `scripts/install/set-default-shell.sh`

**What it does**:
- Checks if zsh is already the default login shell
- If not, adds zsh to `/etc/shells` (if missing) and runs `chsh` to set it
- May require sudo for adding to `/etc/shells`

**Why this matters**:
The dotfiles expect zsh as the login shell. On some Linux distributions, bash is the default. This step ensures zsh is set as the default so the shell configuration loads automatically on login.

**What you'll see**:
```
[8/12] Setting default shell...
  Default shell is already zsh.
```

Or, if the shell needs changing:
```
[8/12] Setting default shell...
  Changing default shell to zsh (/usr/bin/zsh)...
  ✓ Default shell changed to zsh
```

---

### Step 9: Setup Secrets File

**What it does**:
- Creates `~/.config/zsh/secrets.zsh` if it doesn't exist
- Copies from template (`zsh/secrets.zsh.template`) if available
- Sets file permissions to 600 (read/write for owner only)

**Why this matters**:
The secrets file is where you store sensitive environment variables like API keys. It's:
- Stored in XDG location (`~/.config/zsh/`)
- Only readable by you (permissions 600)
- Sourced by the zsh framework on shell startup

**Example secrets file content**:
```bash
# ~/.config/zsh/secrets.zsh

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
[9/12] Setting up secrets file...
  ✓ Created secrets file from template
  ✓ Set permissions to 600
  ! Edit ~/.config/zsh/secrets.zsh to add your API keys
```

---

### Step 10: Run Health Check

**Script**: `scripts/install/health-check.sh`

**What it does**:
- Verifies all symlinks point to correct locations
- Checks that plugin managers are installed
- Validates secrets file exists with correct permissions
- Tests that custom scripts are accessible in PATH

**Why this matters**:
The health check confirms the installation completed successfully. It catches issues like broken symlinks or missing directories before you encounter problems.

**Checks performed**:

| Check | Preset | What it verifies |
|-------|--------|------------------|
| Symlinks | minimal | `.zprofile`, `.prettierrc`, `.editorconfig`, `.tmux`, `.tmux.conf`, dotfiles CLI |
| Files | minimal | `.p10k.zsh` and generated `tmux.conf` exist |
| Symlinks | core | `nvim` config, `lazygit` config, `dash-repo-sync` |
| Files | core | generated `ghostty/config`, `ghostty/local`, `gh-dash/config.yml` |
| Symlinks | full | `hammerspoon/init.lua`; `karabiner.json` (file check) |
| TPM | minimal | `~/.tmux/plugins/tpm` exists |
| lazy.nvim | core | `~/.local/share/nvim/lazy` exists (after first nvim launch) |
| Secrets | minimal | `~/.config/zsh/secrets.zsh` exists |

**What you'll see**:
```
[10/12] Running health check...
  ✓ All symlinks verified
  ✓ TPM installed
  ✓ Secrets file configured
  ✓ Custom scripts in PATH
```

---

### Step 11: Save Preset Configuration

**What it does**:
- Saves your selected preset to `~/.config/dotfiles/preset`
- This allows `dotfiles update` to remember your preset choice

**Why this matters**:
When you run `dotfiles update` later, it reads the saved preset so it can run the correct installation steps without requiring you to specify the preset again.

**What you'll see**:
```
[11/12] Saving preset configuration...
  ✓ Preset 'core' saved to ~/.config/dotfiles/preset
```

---

### Step 12: Configure Project Directories

**What it does**:
- Prompts you to set `DEV_ROOT`, your main development directory (default: `~/src`)
- Optionally prompts for `PROJECTS_ROOT`, a secondary directory for side projects, playgrounds, etc.
- Writes the exports to your `~/.zshrc` using `update_zshrc_export()`
- Creates the directories if they don't exist
- Skips the prompt if either variable is already configured

**Why this matters**:
The launcher picker (`` ` p ``) and `dotfiles set` command use these paths for dynamic project discovery. Setting them during installation means the launcher can find your projects immediately.

**What you'll see**:
```
[12/12] Project directories (optional)...
  DEV_ROOT sets your main development directory for the launcher picker.
  Default: /Users/you/src
  Enter path (or press Enter for default, "skip" to skip):
  ✓ DEV_ROOT set to /Users/you/src

  PROJECTS_ROOT sets a secondary directory (side projects, playground, etc.).
  Enter path (or press Enter to skip):
  ✓ Skipped. Set later with: dotfiles set projects <path>
```

**Non-interactive mode**: When the installer runs non-interactively (e.g., piped or in CI), this step is skipped. You can configure directories later:
```bash
dotfiles set dev ~/src
dotfiles set projects ~/playground
```

---

## Command-Line Options

### Presets

| Option | Description |
|--------|-------------|
| `--minimal` | Install zsh + tmux only (servers, remote machines) |
| `--core` | Install zsh, tmux, nvim, ghostty, AI/CLI tools |
| `--full` | Install everything including platform-specific apps (default) |

### Other Options

| Option | Description |
|--------|-------------|
| `--skip-brew` | Skip Homebrew installation and package installation (steps 1-2) |
| `--skip-backup` | Skip backing up existing configuration (step 4) |
| `--skip-steps L` | Skip a comma-separated list of steps (`homebrew,packages,symlinks,keyd`), used by `dotfiles update` for incremental runs |
| `--check-only` | Only run prerequisite and health checks, make no changes |
| `--update` | Update mode (skips logo, uses update terminology) |
| `--yes`, `-y` | Skip the preset confirmation prompt |
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

The installer detects what's already configured and shows only the steps you still need. On a fresh install you'll see all of these; on a re-run you may see only one or two.

### 1. Reload Your Shell

```bash
# Either restart your terminal, or run:
source ~/.zshrc
```

### 2. Install Tmux Plugins

Shown only if `~/.tmux/plugins/tmux-resurrect` doesn't exist yet.

```bash
# Start tmux
tmux

# Press prefix + I to install plugins
# (prefix is backtick ` by default)
```

### 3. Launch Neovim (core/full presets)

Shown only if lazy.nvim hasn't populated `~/.local/share/nvim/lazy` yet.

```bash
# First launch triggers lazy.nvim plugin installation
nvim
```

Wait for all plugins to install, then restart Neovim.

### 4. Install Node.js (core/full presets)

Shown only if `node` is not found in PATH.

```bash
# Install latest LTS version
fnm install --lts
fnm default lts-latest

# Verify
node --version
```

### 5. Add Your Secrets

Shown only if `~/.config/zsh/secrets.zsh` doesn't contain any `export` lines yet.

```bash
# Edit secrets file
nvim ~/.config/zsh/secrets.zsh

# Add your API keys and credentials
```

### 6. Configure Project Directories

Shown only if `DEV_ROOT` or `PROJECTS_ROOT` aren't set in `~/.zshrc`. If you skipped the interactive prompt during Step 12, configure them now:

```bash
dotfiles set dev ~/src
dotfiles set projects ~/playground
```

---

## What Gets Installed

### Shell Environment (Zsh)

- **Powerlevel10k**: Fast, customisable prompt with git status, execution time, etc.
- **zsh-autosuggestions**: Fish-like autosuggestions based on history
- **carapace**: Multi-shell completion bridge (so modern completion specs work in zsh)
- **zoxide**: Frecency-based `cd` replacement
- **fzf integration**: Ctrl+R history, Ctrl+T files, Alt+A directory history
- **direnv**: Automatic environment variable loading per directory

### Terminal Multiplexer (Tmux)

- **Prefix key**: Backtick (`` ` ``) for single-keystroke access
- **Mouse support**: Click to select panes, drag to resize
- **Vim-style navigation**: hjkl keys for pane movement
- **Session persistence**: Survives terminal restarts (via tmux-resurrect + continuum)
- **Agent alerts**: Visual indicators for AI agent activity (Claude, OpenCode, Codex, Copilot)
- **Command exit alerts**: ✓/✗ markers when long commands finish in other windows

### Editor (Neovim)

- **lazy.nvim**: Plugin manager with lazy loading
- **LSP support**: Autocomplete, go-to-definition, error checking (Mason-managed servers)
- **SonarLint**: SonarQube/SonarCloud diagnostics as a second LSP client
- **Treesitter**: Advanced syntax highlighting
- **Telescope**: Fuzzy finder for files, grep, buffers
- **GitHub Copilot**: AI code completion (requires authentication)
- **PR review**: Octo.nvim + diffview for GitHub PR review in-editor

### Desktop Applications

**macOS (Casks)**:
- **Ghostty**: Fast, GPU-accelerated terminal emulator
- **Hammerspoon**: Lua-based automation (window management, etc.)
- **Karabiner Elements**: Keyboard customisation

**Linux**:
- **Ghostty**: Installed via system package manager (not brew)
- **keyd**: Keyboard remapping daemon (Caps Lock → Escape, Right Alt → Control)

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
cp ~/.dotfiles-backup/<backup-dir>/.zshrc ~/.zshrc
cp ~/.dotfiles-backup/<backup-dir>/.tmux.conf ~/.tmux.conf

# Or restore everything
cp -r ~/.dotfiles-backup/<backup-dir>/.* ~/
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
- [Theme System](./THEME-SYSTEM.md) - Theme architecture and switching
