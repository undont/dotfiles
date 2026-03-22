# Zsh Configuration

A modern zsh setup with Powerlevel10k prompt, fuzzy finding, autosuggestions, and MCP server integration.

## Quick Reference

| Feature             | Description                                           |
| ------------------- | ----------------------------------------------------- |
| **Prompt**          | Powerlevel10k with git status                         |
| **Fuzzy finder**    | `Ctrl+R` history, `Ctrl+T` files, `Opt+A` directory history |
| **Autosuggestions** | Right arrow to accept                                 |
| **Dotfiles CLI**    | `dot` / `dotfiles` for management commands            |

---

## Setup Guide (New Machine)

### 1. Prerequisites

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# zsh is the default shell on macOS, no installation needed
```

### 2. Install Core Tools

```bash
# Prompt theme
brew install powerlevel10k

# Shell plugins
brew install zsh-autosuggestions fzf

# Directory environment manager
brew install direnv
```

### 3. Install a Nerd Font

Powerlevel10k uses special icons that require a patched font:

```bash
# Install a Nerd Font (MesloLGS NF is recommended for p10k)
brew tap homebrew/cask-fonts
brew install --cask font-meslo-lg-nerd-font
```

Then configure your terminal to use "MesloLGS NF" or another Nerd Font.

### 4. Install Dotfiles

Run the installer which creates `~/.zshrc` from the template and symlinks shared config:

```bash
./install.sh
```

This creates:
```
~/.zshrc              # Your personal config (from template, sources the framework)
~/.zprofile           # Login shell config (symlink)
~/.p10k.zsh           # Powerlevel10k theme settings (copy-on-install, customise freely)
```

### 5. Create Secrets File

Create `~/.config/zsh/secrets.zsh` with your API keys:

```bash
# GitHub
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."

# Atlassian (Jira/Confluence)
export ATLASSIAN_API_TOKEN="..."
export JIRA_URL="https://your-org.atlassian.net"
export JIRA_USER_EMAIL="you@example.com"
export CONFLUENCE_URL="https://your-org.atlassian.net/wiki"
export CONFLUENCE_USER_EMAIL="you@example.com"

# AI Services
export OPENAI_API_KEY="sk-..."
export BRAVE_API_KEY="..."

# SonarCloud
export SONAR_TOKEN="..."
export SONAR_ORG="your-org"
```

### 6. Configure Powerlevel10k

Run the configuration wizard:

```bash
p10k configure
```

Or copy an existing `~/.p10k.zsh` file.

### 7. Reload Shell

```bash
source ~/.zshrc
```

---

## File Structure

```
~/
├── .zshrc              # Your personal config (sources the dotfiles framework)
├── .zprofile           # Login shell config (symlink to ~/dotfiles/zsh/zprofile)
├── .p10k.zsh           # Powerlevel10k theme (copy-on-install, user-owned)
└── .config/
    └── zsh/
        └── secrets.zsh       # API keys and credentials (not versioned)

~/dotfiles/zsh/
├── dotfiles.zsh        # Shared framework (sourced by ~/.zshrc)
├── zshrc.template      # Template for creating ~/.zshrc
├── zprofile            # Login shell config
├── p10k.zsh            # Powerlevel10k theme settings
├── secrets.zsh.template  # Template for secrets file
└── README.md           # This documentation
```

### File Purposes

| File                          | Purpose                                                     |
| ----------------------------- | ----------------------------------------------------------- |
| `~/.zshrc`                    | Your personal config: sources framework + your customisations |
| `~/dotfiles/zsh/dotfiles.zsh` | Shared framework: PATH, plugins, tools, keybindings         |
| `~/.zprofile`                 | Login shell only: PATH additions from installers            |
| `~/.p10k.zsh`                 | Prompt appearance, git status format, colours               |
| `~/.config/zsh/secrets.zsh`   | API keys (sourced by framework, not version controlled)     |

### Zsh Load Order

```
.zshenv     → Always loaded (not used in this setup)
.zprofile   → Login shells only (terminal window open, SSH)
.zshrc      → Interactive shells (most config goes here)
.zlogin     → After .zshrc for login shells (not used)
```

---

## Configuration Sections

The framework (`dotfiles.zsh`) is organised into these sections:

1. **Platform Detection** - macOS/Linux, Homebrew location
2. **Powerlevel10k Theme** - Theme loading and p10k config
3. **PATH Configuration** - Homebrew, Go, Java, Python, etc.
4. **Google Cloud SDK** - gcloud CLI and completions (lazy loaded)
5. **Node.js (fnm)** - Fast Node Manager (~5ms init)
6. **Docker & Completions** - CLI completions with cached compinit
7. **Direnv** - Per-directory environment variables
8. **ZSH Plugins** - autosuggestions, fzf
9. **Terminal Title Hooks** - Dynamic tab titles
10. **Secrets & Credentials** - Load secrets.zsh
11. **.NET / SonarCloud** - Various tool configs
12. **Aliases & Functions** - Custom shortcuts
13. **ZLE Keybindings** - Line editor mode and key mappings

Your personal `~/.zshrc` adds:
- **P10k Instant Prompt** - Must be at the very top of the file
- **Framework Source** - Sources `dotfiles.zsh`
- **Personal Config** - Your aliases, overrides, and customisations

---

## Plugins & Tools

### Powerlevel10k

Modern, fast prompt theme with:

- Git status (branch, ahead/behind, dirty state)
- Command execution time
- Exit status indicators
- Virtual environment display
- Cloud context (AWS, GCP, Azure)

**Configuration:** `~/.p10k.zsh`
**Reconfigure:** `p10k configure`

### zsh-autosuggestions

Suggests commands as you type based on history.

- **Accept full suggestion:** Right arrow or End
- **Accept word:** Ctrl+Right arrow
- **Dismiss:** Ctrl+C or type something different

### fzf (Fuzzy Finder)

| Keybinding | Action                             |
| ---------- | ---------------------------------- |
| `Ctrl+R`   | Search command history             |
| `Ctrl+T`   | Search files in current directory  |
| `Opt+A`    | Pick from directory history (back stack) |

### direnv

Automatically loads `.envrc` files when entering directories.

```bash
# Create .envrc in a project directory
echo 'export DATABASE_URL="postgres://..."' > .envrc
direnv allow
```

---

## Aliases & Functions

### Environment Variables

| Variable | Value  | Description                             |
| -------- | ------ | --------------------------------------- |
| `EDITOR` | `nvim` | Default editor for git, tmux-open, etc. |

### Aliases

| Alias      | Command                         | Description                        |
| ---------- | ------------------------------- | ---------------------------------- |
| `opencode` | `cl && opencode`                | Clear scrollback + launch OpenCode |
| `oc`       | `opencode`                      | Shorthand for OpenCode editor      |
| `claude`   | `cl && claude`                  | Clear scrollback + launch Claude CLI |
| `gemini`   | `cl && gemini`                  | Clear scrollback + launch Gemini CLI |
| `copilot`  | `cl && copilot`                 | Clear scrollback + launch Copilot CLI |
| `ralph`    | `cl && ralph`                   | Clear scrollback + launch Ralph (Claude Code) |
| `ralf`     | `cl && ralf`                    | Clear scrollback + launch Ralf (Claude Code) |
| `dot`      | `dotfiles`                      | Shorthand for dotfiles CLI         |
| `drs`      | `dash-repo-sync`                | Sync local repo paths into gh-dash config |
| `ff`       | `fastfetch`                     | System info (fastfetch)                    |
| `dash`     | `cl && gh dash`                 | Clear scrollback + open GitHub Dash        |
| `ta`       | `tattach`                       | Shorthand for `tattach` (see functions below) |
| `tls`      | `~/.tmux/scripts/resurrect/restore.sh --list` | List saved tmux session backups |
| `tcleanup` | `~/.tmux/scripts/tests/cleanup-tests.sh` | Clean up orphaned test resources (servers/backups) |
| `ac` / `alerts-clear` | `rm -rf ~/.config/tmux-alerts` | Clear all tmux alerts (agent + command exit) |
| `gols`     | `ls ~/go/bin`                   | List installed Go binaries         |
| `brewup`   | `brew update && brew upgrade`   | Update and upgrade Homebrew        |
| `grmc`     | `git rm --cached`               | Untrack file(s) without deleting from disk |
| `gca`      | `git commit --amend`            | Amend the last commit              |
| `nvim-clear` | `rm -rf ~/.cache/nvim/luac/`  | Clear Neovim bytecode cache        |

### Dotfiles CLI

| Command          | Description                                        |
| ---------------- | -------------------------------------------------- |
| `dotfiles update` | Smart incremental update (`-f` force, `-p` preview) |
| `dotfiles status` | Show version, sync status, and local changes      |
| `dotfiles health` | Run full health check (incl. env var checks)      |
| `dotfiles links` | Show all managed symlinks and their status          |
| `dotfiles notes` | Browse full changelog in a pager                    |
| `dotfiles version` | Show current dotfiles version, preset, and theme |
| `dotfiles theme <name>` | Switch to a theme (list, current, generate, delete) |
| `dotfiles aliases` | Show all shell aliases, functions, and utilities |
| `dotfiles sync`  | Sync copy-on-install files from repo (--force to overwrite) |
| `dotfiles edit`  | Open dotfiles directory in $EDITOR                 |
| `dotfiles cd`    | Print dotfiles path (use: `cd "$(dotfiles cd)"`)  |

Tab completion is available for all dotfiles commands.

| Function       | Usage                        | Description                                                                                                                                    |
| -------------- | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `cdb`          | `cdb`                        | Go back to previous directory (browser-style history). |
| `cdf`          | `cdf`                        | Go forward after `cdb` (browser-style history). Normal `cd` clears the forward stack. |
| `Opt/Alt+A`    | (keybinding)                 | Pick from directory history with fzf (most recent first, deduplicated). Falls back to numbered list without fzf. |
| `font-preview`   | `font-preview [text]`      | Browse figlet/toilet fonts with fzf preview. Use `-f` for figlet only, `-t` for toilet only. |
| `tattach <name>` | `tattach myproject`        | Smart attach: connects to running session, or restores from backup if not running. Automatically cleans up stale backups that fail to restore. |
| `tkill <name>` | `tkill myproject`            | Kills the specified tmux session and removes its backup file from `~/.tmux/resurrect/sessions/`. |
| `trestore`     | `trestore [options]`         | Restore tmux sessions. No args = restore ALL; `--session <name>` = specific session; `--delete <name>` = delete backup. |
| `mkcd <dir>`   | `mkcd mydir`                 | Create a directory and cd into it. |
| `nvim-sync`    | `nvim-sync`                  | Sync all Lazy.nvim plugins (headless). |
| `brewup`       | `brewup`                     | Alias for `brew update && brew upgrade`. |

### Tab Completion

Custom tab completion is enabled for these commands:

| Command    | Completion Source          | Description                       |
| ---------- | -------------------------- | --------------------------------- |
| `dotfiles` | CLI subcommands            | Lists available commands (update, status, etc.) |
| `trestore` | Saved session backups      | Lists `~/.tmux/resurrect/sessions/*.txt` |
| `tkill`    | Running tmux sessions      | Lists currently active sessions   |
| `tattach`  | Running tmux sessions      | Lists currently active sessions   |

**Usage:** Type the command and press `Tab` to see available options.

---

## PATH Configuration

The PATH is built from multiple sources:

```
$HOME/.local/bin                    # User scripts, dotfiles CLI
/opt/homebrew/bin                   # Homebrew (Apple Silicon)
/opt/homebrew/opt/openjdk/bin       # Java
$GOPATH/bin                         # Go binaries
$HOME/.bun/bin                      # Bun runtime
$ANDROID_HOME/platform-tools        # Android SDK
$HOME/.local/launchers              # Session launchers (from .zprofile)
JetBrains Toolbox scripts           # (from .zprofile)
Google Cloud SDK                    # (lazy loaded)
fnm-managed Node.js                 # (~5ms init, auto-switches on cd)
```

---

## Secrets Structure

The `~/.config/zsh/secrets.zsh` file contains API keys and is **not version controlled**.

### Categories

```bash
# GitHub
export GITHUB_PERSONAL_ACCESS_TOKEN="..."

# Atlassian (Jira/Confluence)
export ATLASSIAN_API_TOKEN="..."
export JIRA_URL="..."
export JIRA_USER_EMAIL="..."
export CONFLUENCE_URL="..."
export CONFLUENCE_USER_EMAIL="..."

# AI Services
export OPENAI_API_KEY="..."
export BRAVE_API_KEY="..."

# Code Quality
export SONAR_TOKEN="..."
export SONAR_ORG="..."
```

### Security Notes

- Never commit `.secrets.zsh` to version control
- Add to `.gitignore` if your home directory is a git repo
- Consider using a secrets manager for production environments

---

## Personal Configuration

Your `~/.zshrc` is your own file — add anything you want after the framework source line. This replaces the old `local-aliases.zsh` approach.

### Adding Personal Config

Edit `~/.zshrc` and add config below the framework source line:

```bash
# =============================================================================
# YOUR PERSONAL CONFIGURATION
# =============================================================================
export EDITOR="code"                    # Override default editor
alias myproject="cd ~/src/myapp"        # Project shortcuts
export PATH="$HOME/scripts:$PATH"       # Extra PATH entries
```

### Common Patterns

#### Project Shortcuts

```bash
export MYAPP_ROOT="$HOME/src/myapp"
alias myapp="cd $MYAPP_ROOT"
```

#### Multi-Project Workspace

```bash
export DEV_ROOT="$HOME/dev"
alias dev="cd $DEV_ROOT"
alias api="cd $DEV_ROOT/api"
alias web="cd $DEV_ROOT/web"
```

#### Conditional Aliases (work vs personal)

```bash
if [[ -d "$HOME/work" ]]; then
  export WORK_ROOT="$HOME/work"
  alias work="cd $WORK_ROOT"
fi
```

### Migration from local-aliases.zsh

If you previously used `~/.config/zsh/local-aliases.zsh`, the installer automatically migrates its content into your `~/.zshrc` during upgrade. A backup is saved as `local-aliases.zsh.bak`.

---

## Terminal Title Hooks

The shell automatically updates terminal/tab titles:

**When idle:** Shows current directory and git branch

```
myproject (main)
```

**When running a command:** Shows the command name

```
npm
```

This is implemented via `precmd()` and `preexec()` functions in `.zshrc`.

---

## Line Editor Mode

Zsh uses **emacs mode** (not vi mode) for command line editing.

### Common Keybindings

| Key                | Action                            |
| ------------------ | --------------------------------- |
| `Ctrl+A`           | Move to beginning of line         |
| `Ctrl+E`           | Move to end of line               |
| `Ctrl+W`           | Delete word backwards             |
| `Opt/Alt+Backspace` | Delete word backwards             |
| `Ctrl+K`           | Delete from cursor to end of line |
| `Ctrl+U`           | Delete entire line                |
| `Ctrl+Left/Right`  | Move by word                      |

**Note:** Vi-mode is explicitly disabled to prevent accidental activation when using Option key combinations.

---

## Troubleshooting

### Prompt looks broken (missing icons)

Install a Nerd Font and configure your terminal to use it:

```bash
brew install --cask font-meslo-lg-nerd-font
```

### Slow prompt in large git repos

Powerlevel10k is optimised for speed, but if issues occur:

```bash
# Check if git is the bottleneck
time git status
```

### Autosuggestions not working

Verify the plugin is loaded:

```bash
# Should show the plugin path
echo $ZSH_AUTOSUGGEST_STRATEGY
```

### fzf keybindings not working

Ensure fzf is properly sourced:

```bash
# Check if fzf is installed
which fzf

# Reload shell
source ~/.zshrc
```

## Performance Optimisations

The shell configuration uses several techniques to minimise startup time.

### Lazy Loading

Heavy tools are lazy loaded—they only initialise when first used:

| Tool        | Commands                  | Savings   |
| ----------- | ------------------------- | --------- |
| **gcloud**  | `gcloud`, `gsutil`, `bq`    | ~260ms    |

The first invocation of these commands will have a brief delay as the tool loads, but subsequent calls are instant.

### Fast Node Manager (fnm)

Node.js version management uses [fnm](https://github.com/Schniz/fnm) instead of NVM. fnm is written in Rust and initialises in ~5ms (vs NVM's 300-500ms), eliminating the need for lazy loading.

```bash
# Install/switch Node versions
fnm install 22        # Install Node 22
fnm use 20            # Switch to Node 20
fnm default 22        # Set default version

# Auto-switching: fnm reads .nvmrc/.node-version files automatically
```

### Cached Completions

The completion system (`compinit`) is cached and only regenerates once per day:

```zsh
# Only rebuild if cache is older than 24 hours
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C  # Use cached dump
fi
```

### Powerlevel10k Instant Prompt

The prompt appears immediately by caching the previous prompt state. This is configured at the top of your `~/.zshrc` (before the framework source line). It must remain at the very top — do not add any `echo` or output commands above it.

### Profiling Startup Time

Built-in profiling functions are available:

```bash
# Quick benchmark (runs 5 iterations)
zsh-profile

# Detailed profiling (shows what's taking time)
zsh-profile-detailed
```

Or manually measure startup time:

```bash
# Quick measurement
time zsh -i -c exit

# Enable ZPROF for a single session
ZPROF=1 zsh -i -c exit
```

### Maintenance

```bash
# Update Homebrew packages
brewup

# Force completion cache rebuild (if completions seem stale)
rm -f ~/.zcompdump && compinit
```
