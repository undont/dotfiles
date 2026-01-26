# Zsh Configuration

A modern zsh setup with Powerlevel10k prompt, fuzzy finding, autosuggestions, and MCP server integration.

## Quick Reference

| Feature             | Description                                           |
| ------------------- | ----------------------------------------------------- |
| **Prompt**          | Powerlevel10k with git status                         |
| **Fuzzy finder**    | `Ctrl+R` history, `Ctrl+T` files, `Opt+C` directories |
| **Autosuggestions** | Right arrow to accept                                 |
| **MCP sync**        | `mcp-sync` to sync server configs                     |

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

### 4. Copy Configuration Files

```
~/.zshrc              # Main shell configuration
~/.zprofile           # Login shell config (PATH additions)
~/.p10k.zsh           # Powerlevel10k theme settings
~/.zsh/
├── .secrets.zsh      # API keys (create from template below)
└── README.md         # This documentation
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
├── .zshrc              # Main config (symlink to ~/dotfiles/zsh/zshrc)
├── .zprofile           # Login shell config (symlink to ~/dotfiles/zsh/zprofile)
├── .p10k.zsh           # Powerlevel10k theme (symlink to ~/dotfiles/zsh/p10k.zsh)
└── .config/
    ├── zsh/
    │   ├── secrets.zsh       # API keys and credentials (not versioned)
    │   └── local-aliases.zsh # Machine-specific aliases (not versioned)
    ├── mcp-servers.json      # MCP server definitions (source of truth)
    └── sync-mcp-servers.sh   # Sync script for MCP configs
```

### File Purposes

| File                          | Purpose                                                  |
| ----------------------------- | -------------------------------------------------------- |
| `.zshrc`                      | Interactive shell config: prompt, aliases, plugins, PATH |
| `.zprofile`                   | Login shell only: PATH additions from installers         |
| `.p10k.zsh`                   | Prompt appearance, git status format, colours            |
| `.config/zsh/secrets.zsh`     | API keys (sourced by .zshrc, not version controlled)     |
| `.config/zsh/local-aliases.zsh` | Machine-specific project aliases (not versioned)       |

### Zsh Load Order

```
.zshenv     → Always loaded (not used in this setup)
.zprofile   → Login shells only (terminal window open, SSH)
.zshrc      → Interactive shells (most config goes here)
.zlogin     → After .zshrc for login shells (not used)
```

---

## Configuration Sections

The `.zshrc` is organised into these sections:

1. **Powerlevel10k Prompt** - Theme and instant prompt
2. **PATH Configuration** - Homebrew, Go, Java, Python, etc.
3. **Google Cloud SDK** - gcloud CLI and completions (lazy loaded)
4. **Node.js (fnm)** - Fast Node Manager (~5ms init)
5. **Docker & Completions** - CLI completions with cached compinit
6. **Direnv** - Per-directory environment variables
7. **ZSH Plugins** - autosuggestions, fzf
8. **Terminal Title Hooks** - Dynamic tab titles
9. **Secrets & Credentials** - Load .secrets.zsh
10. **.NET / SonarCloud / Bun** - Various tool configs
11. **Aliases & Functions** - Custom shortcuts
12. **ZLE Keybindings** - Line editor mode and key mappings

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
| `Opt+C`    | cd into a directory (fuzzy search) |

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
| `oc`       | `opencode`                      | Launch OpenCode editor             |
| `mcp-sync` | `~/.config/sync-mcp-servers.sh` | Sync MCP server configs            |
| `tls`      | `trestore --list`               | List saved tmux session backups    |
| `tcleanup` | `~/.tmux/scripts/tests/cleanup-tests.sh` | Clean up orphaned test resources (servers/backups) |
| `gols`     | `ls ~/go/bin`                   | List installed Go binaries         |
| `dot`      | `cd ~/dotfiles`                 | Navigate to dotfiles directory     |
| `claudeconfig` | `cd ~/claude-config`        | Navigate to claude-config directory |

### Dotfiles CLI

| Command          | Description                                        |
| ---------------- | -------------------------------------------------- |
| `dotfiles update` | Pull latest changes and re-run installer          |
| `dotfiles status` | Show sync status and local changes                |
| `dotfiles sync`  | Preview incoming changes without applying          |
| `dotfiles health` | Run full health check                             |
| `dotfiles edit`  | Open dotfiles directory in $EDITOR                 |
| `dotfiles cd`    | Print dotfiles path (use: `cd "$(dotfiles cd)"`)  |

Tab completion is available for all dotfiles commands.

| Function       | Usage                        | Description                                                                                                                                    |
| -------------- | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `tattach <name>` | `tattach myproject`        | Smart attach: connects to running session, or restores from backup if not running. Automatically cleans up stale backups that fail to restore. |
| `tkill <name>` | `tkill myproject`            | Kills the specified tmux session and removes its backup file from `~/.tmux/resurrect/sessions/`. |
| `trestore`     | `trestore [options]`         | Restore tmux sessions. No args = restore ALL; `--session <name>` = specific session; `--delete <name>` = delete backup. |
| `brewup`       | `brewup`                     | Runs `brew update && brew upgrade`. |

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

## MCP (Model Context Protocol) Setup

MCP servers provide AI tools with access to external services (Jira, Confluence, GitHub, etc.).

### Configuration Files

| File                               | Purpose                           |
| ---------------------------------- | --------------------------------- |
| `~/.config/mcp-servers.json`       | Source of truth (OpenCode format) |
| `~/.config/opencode/opencode.json` | OpenCode editor config            |
| `~/.claude.json`                   | Claude Code CLI config            |

### Sync Script

The `mcp-sync` alias runs `~/.config/sync-mcp-servers.sh` to keep configs in sync:

```bash
# Sync source → both tools (default)
mcp-sync

# Check sync status
mcp-sync check

# Pull from Claude, sync to OpenCode
mcp-sync --claude

# Pull from OpenCode, sync to Claude
mcp-sync --opencode
```

### Format Conversion

The script handles format differences between tools:

**OpenCode format:**

```json
{
  "mcp-server": {
    "type": "local",
    "command": ["npx", "-y", "@company/server"],
    "environment": { "API_KEY": "..." }
  }
}
```

**Claude format:**

```json
{
  "mcp-server": {
    "command": "npx",
    "args": ["-y", "@company/server"],
    "env": { "API_KEY": "..." }
  }
}
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

## Local Aliases Configuration

### Overview

Project-specific aliases (like `da` for Dana, `dot` for dotfiles) can be customised per machine using the `.local-aliases.zsh` file. This allows the same dotfiles configuration to work across different users and development environments.

### Setup

1. **Copy the template:**
   ```bash
   cp ~/.config/zsh/local-aliases.zsh.template ~/.config/zsh/local-aliases.zsh
   ```

2. **Edit your local aliases:**
   ```bash
   nvim ~/.config/zsh/local-aliases.zsh
   ```

3. **Define your project paths:**
   ```bash
   # Example configuration
   export DANA_ROOT="$HOME/src/dana"
   alias da="cd $DANA_ROOT"
   alias dap="cd $DANA_ROOT/.claude/plans"
   ```

4. **Reload your shell:**
   ```bash
   source ~/.zshrc
   ```

### Pattern: Environment Variables + Aliases

The recommended pattern uses environment variables for project roots, then defines aliases based on those variables:

```bash
# Define the root path
export PROJECT_ROOT="$HOME/projects/my-app"

# Create aliases using the variable
alias myapp="cd $PROJECT_ROOT"
alias myapp-plans="cd $PROJECT_ROOT/.claude/plans"
alias myapp-test="cd $PROJECT_ROOT && npm test"
```

**Benefits:**
- ✅ Portable across machines (each user sets their own paths)
- ✅ Environment variables can be used in scripts
- ✅ Easy to update paths (change variable, all aliases update)
- ✅ Self-documenting (variable names describe what they point to)

### Default Aliases

The `.zshrc` includes some default aliases that you can override:

| Alias | Default Path | Purpose |
|-------|--------------|---------|
| `da` | `~/src/dana` | Dana project root |
| `dap` | `~/src/dana/.claude/plans` | Dana plans directory |
| `daw` | `~/src/dana-worktrees` | Dana worktrees |
| `dot` | `~/dotfiles` | Dotfiles repository |
| `dotp` | `~/dotfiles/.claude/plans` | Dotfiles plans |
| `dotd` | `~/dotfiles/.claude/docs` | Dotfiles documentation |
| `.ai` | `~/.ai` | AI configuration |
| `plans` | `~/.claude/plans` | Claude Code plans |
| `commands` | `~/.claude/commands` | Claude Code commands |

To override these, define them in your `.local-aliases.zsh` file.

### Tab Completion for Custom Aliases

If your custom alias needs tab completion (like project-specific tmux session names), use a function instead of an alias:

```bash
# In .local-aliases.zsh
myapp() {
  cd "$MYAPP_ROOT/$1"
}

# Add completion function
_myapp() {
  local -a subdirs
  subdirs=(${(f)"$(ls -d $MYAPP_ROOT/*/ 2>/dev/null | xargs -n1 basename)"})
  _describe 'myapp directories' subdirs
}
compdef _myapp myapp
```

### Common Patterns

#### Multi-Project Workspace

```bash
export DEV_ROOT="$HOME/dev"
alias dev="cd $DEV_ROOT"
alias api="cd $DEV_ROOT/api"
alias web="cd $DEV_ROOT/web"
alias mobile="cd $DEV_ROOT/mobile"
```

#### Project with Launcher Function

```bash
export MYAPP_ROOT="$HOME/projects/myapp"
alias myapp="cd $MYAPP_ROOT"

# Launcher that sets up environment
myapp-dev() {
  cd "$MYAPP_ROOT" || return 1
  fnm use  # Use correct Node version
  npm run dev
}
```

#### Conditional Aliases (work vs personal)

```bash
# Only create work aliases on work machine
if [[ -d "$HOME/work" ]]; then
  export WORK_ROOT="$HOME/work"
  alias work="cd $WORK_ROOT"
  alias jira="cd $WORK_ROOT/jira-client"
fi
```

### File Status

- ✅ **`.local-aliases.zsh`** - Not version controlled, user-specific
- ✅ **`.local-aliases.zsh.template`** - Version controlled template
- ✅ **Automatically loaded** in `.zshrc` after default aliases

### Troubleshooting

**Aliases not working after setup:**
```bash
# Reload shell configuration
source ~/.zshrc

# Or open a new terminal tab
```

**Check if file is being loaded:**
```bash
# Add this to top of .local-aliases.zsh for debugging
echo "Loading local aliases..."

# Check if file exists
ls -la ~/.config/zsh/local-aliases.zsh
```

**Verify environment variables:**
```bash
# Print all custom project variables
env | grep -E "(ROOT|_PROJECT)"
```

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
| `Option+Backspace` | Delete word backwards             |
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

### MCP sync fails

Check that jq is installed:

```bash
brew install jq
```

Verify config files exist:

```bash
ls -la ~/.config/mcp-servers.json
ls -la ~/.config/opencode/opencode.json
ls -la ~/.claude.json
```

---

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

The prompt appears immediately by caching the previous prompt state. This is handled automatically by p10k and configured at the top of `.zshrc`.

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
