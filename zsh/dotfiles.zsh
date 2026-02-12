# =============================================================================
# DOTFILES ZSH FRAMEWORK
# =============================================================================
# Shared shell configuration sourced by ~/.zshrc.
# Do NOT symlink this file directly — source it from your personal ~/.zshrc:
#
#   source ~/dotfiles/zsh/dotfiles.zsh
#
# File structure:
#   ~/.zshrc                           - Your personal config (sources this file)
#   ~/.zprofile                        - Login shell config (PATH additions from installers)
#   ~/.p10k.zsh                        - Powerlevel10k theme configuration
#   ~/.config/zsh/secrets.zsh          - API keys and credentials (not version controlled)

# =============================================================================
# STARTUP PROFILING (optional)
# =============================================================================
# Enable with: ZPROF=1 zsh -i -c exit
# Or use: zsh-profile-detailed
[[ -n "$ZPROF" ]] && zmodload zsh/zprof

# =============================================================================
# PLATFORM DETECTION
# =============================================================================
# Detect platform for conditional configuration (must be before Homebrew-installed tools)
case "$(uname)" in
  Darwin)
    export IS_MACOS=1
    if [[ "$(uname -m)" == "arm64" ]]; then
      export IS_APPLE_SILICON=1
      export HOMEBREW_PREFIX="/opt/homebrew"
    else
      export IS_APPLE_SILICON=0
      export HOMEBREW_PREFIX="/usr/local"
    fi
    ;;
  Linux)
    export IS_MACOS=0
    export IS_APPLE_SILICON=0
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    ;;
esac

# =============================================================================
# TERMINFO FALLBACK
# =============================================================================
# Ghostty sets TERM=xterm-ghostty, but remote machines (e.g. SSH targets)
# may not have the terminfo entry installed, causing garbled terminal output.
# Fall back to xterm-256color when the terminfo is missing.
if [[ "$TERM" == "xterm-ghostty" ]] && ! infocmp xterm-ghostty &>/dev/null; then
  export TERM=xterm-256color
fi

# Load theme and config (installed via: brew install powerlevel10k)
if [[ -f "$HOMEBREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  source "$HOMEBREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme"
fi
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# =============================================================================
# PATH CONFIGURATION
# =============================================================================
# Note: Additional PATH entries may exist in ~/.zprofile (added by installers)

# Deduplicate PATH entries (zsh built-in — removes duplicates automatically)
typeset -U path

# Homebrew (detected location)
export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"

# Go workspace (GOPATH is where go install puts binaries)
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Java (OpenJDK via Homebrew)
export PATH="$HOMEBREW_PREFIX/opt/openjdk/bin:$PATH"

# Python pipx (isolated CLI tool installation)
export PATH="$PATH:$HOME/.local/bin"

# Launchers (tmux session launchers, VS Code launcher, etc.)
export PATH="$PATH:$HOME/.local/launchers"

# User scripts directory (custom shell scripts)
export PATH="$HOME/bin:$PATH"

# Neovim Mason LSP/tools (lua-language-server, gopls, pyright, etc.)
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

# .NET global tools (EasyDotnet, etc.)
export PATH="$PATH:$HOME/.dotnet/tools"

# ARM embedded development (for microcontroller/firmware work)
export INCLUDE="$HOMEBREW_PREFIX/arm-none-eabi/include"
# export LIB="$HOMEBREW_PREFIX/arm-none-eabi/lib"

# =============================================================================
# GOOGLE CLOUD SDK - LAZY LOADED
# =============================================================================
# Lazy load gcloud CLI tools and shell completion (~260ms savings)
# Only loads when you actually use gcloud/gsutil/bq
_load_gcloud() {
  unset -f gcloud gsutil bq
  local gcloud_dir="$HOME/google-cloud-sdk"
  if [[ -f "$gcloud_dir/path.zsh.inc" ]]; then
    source "$gcloud_dir/path.zsh.inc"
  fi
  if [[ -f "$gcloud_dir/completion.zsh.inc" ]]; then
    source "$gcloud_dir/completion.zsh.inc"
  fi
}
gcloud() { _load_gcloud && gcloud "$@"; }
gsutil() { _load_gcloud && gsutil "$@"; }
bq() { _load_gcloud && bq "$@"; }

# =============================================================================
# NODE.JS (FNM)
# =============================================================================
# fnm (Fast Node Manager) - Rust-based, ~5ms init vs NVM's 300-500ms
# Usage: fnm install 22, fnm use 20, fnm default 22
# Reads .nvmrc and .node-version files automatically with --use-on-cd
eval "$(fnm env --use-on-cd)"

# =============================================================================
# DOCKER & COMPLETIONS
# =============================================================================
# Docker CLI completions (docker, docker-compose commands)
fpath=("$HOME/.docker/completions" $fpath)

# Cached compinit - only regenerate completion dump once per day (~50-100ms savings)
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# =============================================================================
# CACHED EVAL HELPER
# =============================================================================
# Cache the output of slow eval commands (direnv, fzf) to avoid forking on
# every shell startup. Cache is invalidated when the binary is newer than the
# cached file (covers brew upgrade). Usage: _cached_eval <name> <command...>
_cached_eval() {
  local name="$1"; shift
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  local cache_file="$cache_dir/$name.zsh"
  local bin_path="${commands[$name]}"

  if [[ -n "$bin_path" && -f "$cache_file" && "$cache_file" -nt "$bin_path" ]]; then
    source "$cache_file"
  else
    [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir"
    "$@" > "$cache_file"
    source "$cache_file"
  fi
}

# =============================================================================
# DIRENV
# =============================================================================
# Automatically load/unload environment variables when entering directories
# with .envrc files. Great for per-project env vars.
_cached_eval direnv direnv hook zsh

# =============================================================================
# ZSH PLUGINS
# =============================================================================
# zsh-autosuggestions: suggests commands as you type based on history
# Accept suggestion: Right arrow or End key
if [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# fzf: fuzzy finder for files, history, and more
# Keybindings: Ctrl+R (history), Ctrl+T (files), Opt+C (cd to directory)
_cached_eval fzf fzf --zsh

# Apply theme colours to fzf
if [[ -f "$HOME/dotfiles/scripts/fzf-theme.sh" ]]; then
  source "$HOME/dotfiles/scripts/fzf-theme.sh"
fi

# =============================================================================
# TERMINAL TITLE HOOKS
# =============================================================================
# Dynamic terminal/tab titles that show context
# _dotfiles_precmd: runs before each prompt (shows directory + git branch)
# _dotfiles_preexec: runs before each command (shows running command)
# Uses *_functions arrays to stack with other hooks (p10k, plugins, etc.)
#
# Performance: git branch is cached in _git_branch to avoid forking
# git rev-parse on every prompt (~28ms). Cache is refreshed on directory
# change (chpwd) and after git commands (preexec).

_git_branch=""

_update_git_branch() {
  _git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
}

# Refresh branch cache when changing directories
chpwd_functions+=(_update_git_branch)

# Initialise cache for the first prompt
_update_git_branch

_dotfiles_precmd() {
  if [[ -n "$_git_branch" ]]; then
    print -Pn "\e]0;%1~ ($_git_branch)\a"
  else
    print -Pn "\e]0;%1~\a"
  fi
}
precmd_functions+=(_dotfiles_precmd)

_dotfiles_preexec() {
  # Extract first word safely using parameter expansion
  local cmd="${1%% *}"
  print -Pn "\e]0;${cmd}\a"

  # Refresh git branch cache after git commands that may change the branch
  case "$cmd" in
    git|gh|tig) _update_git_branch ;;
  esac
}
preexec_functions+=(_dotfiles_preexec)

# =============================================================================
# SECRETS & CREDENTIALS
# =============================================================================
# API keys and tokens loaded from separate file (not version controlled)
# See ~/dotfiles/zsh/README.md for structure of secrets.zsh
ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
if [[ -f "$ZSH_CONFIG_DIR/secrets.zsh" ]]; then
  source "$ZSH_CONFIG_DIR/secrets.zsh"
fi

# Android SDK platform tools (adb, fastboot)
[[ -n "$ANDROID_HOME" ]] && export PATH=$PATH:$ANDROID_HOME/platform-tools

# =============================================================================
# .NET
# =============================================================================
# Disable Microsoft telemetry for .NET CLI
export DOTNET_CLI_TELEMETRY_OPTOUT='true'

# =============================================================================
# SONARCLOUD
# =============================================================================
# SonarScanner CLI for code quality analysis
export SONAR_HOST_URL="https://sonarcloud.io"

# =============================================================================
# SSH WRAPPER
# =============================================================================
# Ghostty sets TERM=xterm-ghostty which most remote hosts don't recognise.
# Override TERM for SSH connections so the remote PTY gets xterm-256color.
ssh() {
  if [[ "$TERM" == "xterm-ghostty" ]]; then
    TERM=xterm-256color command ssh "$@"
  else
    command ssh "$@"
  fi
}

# =============================================================================
# ALIASES & FUNCTIONS
# =============================================================================
# Editor
export EDITOR="nvim"                   # Default editor for git, etc.
alias oc="opencode"                    # Launch OpenCode editor

# MCP (Model Context Protocol)
alias mcp-sync="~/.ai/scripts/sync-mcp-servers.sh"    # Sync MCP servers across tools

# Tmux session management (see ~/.tmux/README.md)
alias tls="~/.tmux/scripts/restore-resurrect.sh --list"
alias tcleanup="~/.tmux/scripts/tests/cleanup-tests.sh"

# Functions (instead of aliases) for tab completion support
trestore() {
  ~/.tmux/scripts/resurrect/restore.sh "$@"
}

tkill() {
  ~/.tmux/scripts/resurrect/delete.sh "$@"
}


# Tab completion for tmux commands
_trestore_complete() {
  local -a options sessions
  options=(
    '--session[Restore a specific session]:session:->sessions'
    '-s[Restore a specific session]:session:->sessions'
    '--delete[Delete a session backup]:session:->sessions'
    '-d[Delete a session backup]:session:->sessions'
    '--list[List available sessions]'
    '-l[List available sessions]'
    '--replace[Kill existing session before restoring]'
    '--help[Show usage]'
    '-h[Show usage]'
  )

  _arguments -s "${options[@]}"

  case "$state" in
    sessions)
      sessions=(${(f)"$(ls ~/.tmux/resurrect/sessions/*.txt 2>/dev/null | xargs -n1 basename -s .txt)"})
      _describe 'session backups' sessions
      ;;
  esac
}

_tmux_sessions_running() {
  # Complete with running tmux sessions (for tkill and tattach)
  local -a sessions
  sessions=(${(f)"$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"})
  _describe 'running tmux sessions' sessions
}

# Register completion functions
compdef _trestore_complete trestore
compdef _tmux_sessions_running tkill
compdef _tmux_sessions_running tattach

# Attach to tmux session, restoring from backup if needed
tattach() {
  # Try to attach to running session
  if tmux a -t "$1" 2>/dev/null; then return 0; fi

  # Not running - try to restore from backup
  local backup="${HOME}/.tmux/resurrect/sessions/$1.txt"
  if [[ -f "$backup" ]]; then
    echo "Restoring '$1' from backup..."
    if ~/.tmux/scripts/restore-resurrect.sh --session "$1" && tmux a -t "$1"; then
      return 0
    fi
    # Restore failed - backup is stale
    echo "Backup stale, removing: $1"
    rm -f "$backup"
    return 1
  fi
  echo "No session or backup found: $1"
  return 1
}

# Development tools
alias gols="ls ~/go/bin"               # List installed Go binaries
alias git-prune="git branch -vv | grep ': gone]' | awk '{print \$1}' | xargs git branch -D"  # Prune local branches removed from remote

# Homebrew update
alias brewup="brew update && brew upgrade"

# =============================================================================
# ZSH LINE EDITOR (ZLE) KEYBINDINGS
# =============================================================================
# Disable vi-mode completely - use emacs keybindings (default)
bindkey -e                             # Force emacs mode (Ctrl+A, Ctrl+E, etc.)

# Prevent accidental vi-mode activation from Option+key combinations
# Option+key sends ESC followed by another character. Setting KEYTIMEOUT to 1
# (10ms) means ESC alone won't trigger vi-mode, but ESC sequences from Option+key
# will be processed correctly, and tools like fzf can still use ESC to exit.
export KEYTIMEOUT=1                    # Wait 10ms for more chars after ESC

# Ensure common word deletion shortcuts work correctly
bindkey '^[^?' backward-kill-word      # Option+Backspace: delete word backwards
bindkey '^W' backward-kill-word        # Ctrl+W: delete word backwards

# =============================================================================
# DOTFILES CLI
# =============================================================================
# Tab completion for dotfiles command
_dotfiles() {
  local -a commands
  commands=(
    'update:Pull latest changes and re-run installer'
    'status:Show sync status and quick health summary'
    'health:Run full health check'
    'set:Configure project directories (dev, projects)'
    'edit:Open dotfiles directory in $EDITOR'
    'cd:Print dotfiles path'
    'sync:Fetch from origin and show what'\''s changed'
    'help:Show help message'
  )

  # Handle subcommand completions
  if (( CURRENT == 2 )); then
    _describe 'dotfiles command' commands
  elif (( CURRENT == 3 )); then
    case "${words[2]}" in
      set)
        local -a targets
        targets=(
          'dev:Set DEV_ROOT directory'
          'projects:Set PROJECTS_ROOT directory'
        )
        _describe 'set target' targets
        ;;
    esac
  elif (( CURRENT == 4 )); then
    case "${words[2]}" in
      set)
        _files -/
        ;;
    esac
  fi
}
compdef _dotfiles dotfiles

# =============================================================================
# SHELL STARTUP PROFILING
# =============================================================================
# Quick benchmark: runs zsh 5 times and shows startup time
zsh-profile() {
  echo "Running 5 iterations..."
  for i in {1..5}; do
    time zsh -i -c exit
  done
}

# Detailed profiling: shows what's taking time during startup
zsh-profile-detailed() {
  ZPROF=1 zsh -i -c exit
}

# =============================================================================
# ZPROF OUTPUT (end of startup)
# =============================================================================
# Print profiling results if ZPROF is set
[[ -n "$ZPROF" ]] && zprof
