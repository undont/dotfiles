# shellcheck shell=zsh
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
# FILE DESCRIPTOR LIMIT
# =============================================================================
# macOS default soft limit is 256 — too low for Neovim plugins that spawn many
# git subprocesses (diffview, gitsigns). Raise to 10240 to prevent EMFILE errors.
[[ "$IS_MACOS" == "1" ]] && ulimit -n 10240 2>/dev/null

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
# Appended (not prepended) so Homebrew-installed versions take priority
export PATH="$PATH:$HOME/.local/share/nvim/mason/bin"

# .NET global tools (EasyDotnet, etc.)
export PATH="$PATH:$HOME/.dotnet/tools"
export DOTNET_ROLL_FORWARD='Major'

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
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd)"
fi

# =============================================================================
# DOCKER & COMPLETIONS
# =============================================================================
# Docker CLI completions (docker, docker-compose commands)
fpath=("$HOME/.docker/completions" $fpath)

# Cached compinit - only regenerate completion dump once per day (~50-100ms savings)
# The (#q...) glob qualifier requires EXTENDED_GLOB; anonymous function scopes it
# so it doesn't leak globally (local_options only works inside functions).
autoload -Uz compinit
# shellcheck disable=SC1009,SC1036,SC1072,SC1073
(){ setopt local_options EXTENDED_GLOB
  if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit
  else
    compinit -C
  fi
}

# gh CLI completions: gh generates a compdef line inside its completion file that
# conflicts with zsh autoload. Re-register after compinit so it resolves correctly.
# See: https://github.com/cli/cli/issues/8462
(( $+commands[gh] )) && compdef _gh gh 2>/dev/null

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

# Apply theme colours to fzf (and auto-refresh on theme-switch)
# Export DOTFILES_ROOT so fzf-theme.sh skips its subshell-based path detection
export DOTFILES_ROOT="${DOTFILES_DIR:-$HOME/dotfiles}"
if [[ -f "$DOTFILES_ROOT/scripts/fzf-theme.sh" ]]; then
  source "$DOTFILES_ROOT/scripts/fzf-theme.sh"
  _fzf_theme_cached="${CURRENT_THEME:-}"

  # Re-source fzf-theme.sh if the active theme has changed since last check
  _fzf_theme_refresh() {
    local live
    live=$(<"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/current-theme" 2>/dev/null) || return
    if [[ "$live" != "$_fzf_theme_cached" ]]; then
      source "$HOME/dotfiles/scripts/fzf-theme.sh"
      _fzf_theme_cached="$live"
    fi
  }

  # Wrap fzf ZLE widgets so Ctrl+R/T and Alt+C pick up theme changes immediately
  for _w in fzf-file-widget fzf-history-widget fzf-cd-widget; do
    zle -A "$_w" "_orig-$_w"
    eval "_wrapped-${_w}() { _fzf_theme_refresh; zle _orig-${_w}; }"
    zle -N "$_w" "_wrapped-${_w}"
  done
  unset _w
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

# Defer initial cache population to the first prompt (saves ~14ms at source time)
_update_git_branch_once() {
  _update_git_branch
  precmd_functions=(${precmd_functions:#_update_git_branch_once})
}
precmd_functions+=(_update_git_branch_once)

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
# LAZYGIT
# =============================================================================
# Load base config (symlinked from dotfiles) + personal local overrides.
# local.yml only needs the keys you want to override — lazygit merges both files.
# LG_CONFIG_FILE overrides the default path, so we use ~/.config/lazygit/ on all platforms.
_lg_base="$HOME/.config/lazygit/config.yml"
_lg_local="$HOME/.config/lazygit/local.yml"
if [[ -f "$_lg_local" ]]; then
    export LG_CONFIG_FILE="$_lg_base,$_lg_local"
else
    export LG_CONFIG_FILE="$_lg_base"
fi
unset _lg_base _lg_local

# =============================================================================
# OPENCODE
# =============================================================================
# Point opencode-tmux-alert plugin to dotfiles hook scripts
export OPENCODE_ALERT_SCRIPT="$HOME/dotfiles/scripts/hooks/wrappers/opencode-alert.sh"
export OPENCODE_CLEAR_SCRIPT="$HOME/dotfiles/scripts/hooks/agent-alert-clear.sh"

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
alias dot="dotfiles"                   # Shorthand for dotfiles CLI
alias drs="dash-repo-sync"            # Sync local repo paths into gh-dash config

# Tmux session management (see ~/.tmux/README.md)
alias tls="~/.tmux/scripts/resurrect/restore.sh --list"
alias tcleanup="~/.tmux/scripts/tests/cleanup-tests.sh"
alias alerts-clear="rm -rf ${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts"  # Clear all tmux alerts
alias ta="tattach" # Attach to tmux session, restoring from backup if needed (see tattach function below)

# Navigation
alias c="clear"
alias cl="printf '\033[2J\033[3J\033[H'; [[ -n \$TMUX ]] && tmux clear-history"  # clear screen + scrollback
alias ..="cd .."
alias ...="cd ../.."

# File listing (colour-aware: BSD ls uses -G, GNU ls uses --color=auto)
if [[ "$IS_MACOS" == "1" ]]; then
  alias ls="ls -G"
else
  alias ls="ls --color=auto"
fi
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"

# Search
alias grep="grep --color=auto"

# Shell shortcuts
alias h="cd ~"
alias j="jobs"
alias v="nvim"

# Clipboard — Linux only (macOS has pbcopy/pbpaste natively)
if [[ "$IS_MACOS" != "1" ]]; then
  alias pbcopy="xclip -selection clipboard"
  alias pbpaste="xclip -selection clipboard -o"
fi

# Safer file operations
alias cp="cp -i"
alias mv="mv -i"

# System
alias df="df -h"
alias du="du -sh"
alias psg="ps aux | grep -v grep | grep"   # e.g. psg nvim
alias ports="lsof -i -P -n | grep LISTEN"

# Networking
alias myip="curl -s ifconfig.me"

# Open — platform-aware (macOS: open, Linux: xdg-open)
if [[ "$IS_MACOS" == "1" ]]; then
  alias o="open"
  alias finder="open ."
else
  alias o="xdg-open"
fi

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

# Make directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Directory back/forward navigation (browser-style)
# cdb: go back to previous directory
# cdf: go forward (after going back)
typeset -ga _dir_back_stack _dir_forward_stack
_dir_nav_active=0

_dir_track_chpwd() {
  # Skip tracking when cdb/cdf triggered the change
  if (( _dir_nav_active )); then return; fi
  _dir_back_stack+=("$OLDPWD")
  _dir_forward_stack=()
  # Cap stack size at 50 entries
  (( ${#_dir_back_stack} > 50 )) && _dir_back_stack=("${_dir_back_stack[@]: -50}")
}
chpwd_functions+=(_dir_track_chpwd)

cdb() {
  if (( ${#_dir_back_stack} == 0 )); then
    echo "No previous directory" >&2
    return 1
  fi
  local dest="${_dir_back_stack[-1]}"
  _dir_back_stack[-1]=()
  _dir_forward_stack+=("$PWD")
  _dir_nav_active=1
  cd "$dest"
  _dir_nav_active=0
}

cdf() {
  if (( ${#_dir_forward_stack} == 0 )); then
    echo "No forward directory" >&2
    return 1
  fi
  local dest="${_dir_forward_stack[-1]}"
  _dir_forward_stack[-1]=()
  _dir_back_stack+=("$PWD")
  _dir_nav_active=1
  cd "$dest"
  _dir_nav_active=0
}

# Directory history picker (fzf-powered)
cdl() {
  if (( ${#_dir_back_stack} == 0 )); then
    echo "No directory history" >&2
    return 1
  fi

  # Reverse stack (most recent first) and deduplicate consecutive entries
  local -a reversed=()
  local prev=""
  local i
  for (( i=${#_dir_back_stack}; i>=1; i-- )); do
    local entry="${_dir_back_stack[$i]}"
    if [[ "$entry" != "$prev" ]]; then
      reversed+=("$entry")
      prev="$entry"
    fi
  done

  local count=${#reversed[@]}
  local dest

  if command -v fzf &>/dev/null; then
    _fzf_theme_refresh 2>/dev/null
    dest=$(printf '%s\n' "${reversed[@]}" | fzf \
      --height=40% --reverse \
      --header="$count entries" \
      --preview='ls -CF {}' \
    ) || return 0
  else
    # Fallback: numbered list
    local n=1
    for entry in "${reversed[@]}"; do
      printf "  %2d  %s\n" "$n" "$entry"
      (( n++ ))
    done
    printf "\nSelect [1-%d]: " "$count"
    read -r n
    if [[ -z "$n" || "$n" -lt 1 || "$n" -gt "$count" ]] 2>/dev/null; then
      return 0
    fi
    dest="${reversed[$n]}"
  fi

  if [[ -n "$dest" && -d "$dest" ]]; then
    _dir_back_stack+=("$PWD")
    _dir_forward_stack=()
    _dir_nav_active=1
    cd "$dest"
    _dir_nav_active=0
  fi
}

# Attach to tmux session, restoring from backup if needed
tattach() {
  # Try to attach to running session
  if tmux a -t "$1" 2>/dev/null; then return 0; fi

  # Not running - try to restore from backup
  local backup="${HOME}/.tmux/resurrect/sessions/$1.txt"
  if [[ -f "$backup" ]]; then
    echo "Restoring '$1' from backup..."
    if ~/.tmux/scripts/resurrect/restore.sh --session "$1" && tmux a -t "$1"; then
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

# Git
alias gs="git status -sb"
alias gd="git diff"
alias gdn="git diff | diffnav" # View git diffs in diffnav
alias gds="git diff --staged"
alias gl="git log --graph --decorate --format='%C(yellow)%h%C(reset) %s %C(dim)(%ar, %an)%C(reset)' -20"
alias glf="git log --graph --decorate --format='%C(yellow)%h%C(reset) %s %C(dim)(%ad, %an)%C(reset)' --date=format:'%d %B %Y %H:%M'"
alias gco="git checkout"
alias gsw="git switch"
alias gb="git branch -vv"
alias gp="git push"
alias gpl="git pull"
alias gst="git stash"
alias gfp="git fetch -pf"             # Fetch and prune remote-tracking branches
alias gpr="git branch -vv | grep ': gone]' | awk '{print \$1}' | xargs git branch -D"  # Prune local branches removed from remote

# Development tools
alias gols="ls ~/go/bin"               # List installed Go binaries
alias nvim-clear="rm -rf ~/.cache/nvim/luac/ && echo 'Cleared Neovim bytecode cache'"  # Fix stale plugin cache

# Sync all Lazy.nvim plugins (headless)
nvim-sync() {
  printf "Syncing Neovim plugins...\n"
  nvim --headless "+Lazy! sync" +qa
  printf "\033[0;32m✔\033[0m Neovim plugins synced\n"
}

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

# Bind Home/End in both forms: Ghostty sends CSI H/F directly; tmux with
# extended-keys re-encodes them as VT220-style \x1b[1~ and \x1b[4~.
bindkey '\e[H'  beginning-of-line      # Home (Ghostty, CSI)
bindkey '\e[F'  end-of-line            # End (Ghostty, CSI)
bindkey '\e[1~' beginning-of-line      # Home (tmux-encoded)
bindkey '\e[4~' end-of-line            # End (tmux-encoded)
# \e[1~ shares the prefix \e[1 with modifier+arrow sequences (\e[1;2A etc).
# Binding the full sequences resolves the ambiguity so ZLE doesn't garble them.
bindkey '\e[1;2A' up-line-or-history   # Shift+Up
bindkey '\e[1;2B' down-line-or-history # Shift+Down
bindkey '\e[1;2C' forward-word         # Shift+Right
bindkey '\e[1;2D' backward-word        # Shift+Left
bindkey '\e[1;3A' up-line-or-history   # Opt+Up
bindkey '\e[1;3B' down-line-or-history # Opt+Down

# Ghostty sends these sequences for modifier+enter combos; bind them to
# accept-line so they act as Enter in zsh instead of printing garbage.
bindkey '\e[13;5u'  accept-line        # Ctrl+Enter (kitty protocol)
bindkey '\e[13;6u'  accept-line        # Ctrl+Shift+Enter (kitty protocol)
bindkey '\e[;5;13~' accept-line        # Ctrl+Enter (Ghostty variant)
bindkey '\e[;6;13~' accept-line        # Ctrl+Shift+Enter (Ghostty variant)

# tmux extended-keys (modifyOtherKeys) sends CSI sequences for Ctrl+key
# combos that have no standard terminal meaning. Swallow them to prevent
# raw escape codes printing in the shell.
bindkey -s '\e[27;5;45~' ''            # Ctrl+- (swallow)
bindkey -s '\e[27;5;61~' ''            # Ctrl+= (swallow)

# =============================================================================
# DOTFILES CLI
# =============================================================================
# Tab completion for dotfiles command
_dotfiles() {
  local -a commands
  commands=(
    'update:Pull latest changes and re-run installer'
    'status:Show version, sync status, and local changes'
    'health:Run full health check'
    'links:Show all managed symlinks and their status'
    'aliases:Show all shell aliases, functions, and utilities'
    'theme:Manage colour themes'
    'set:Configure project directories (dev, projects)'
    'notes:Browse the full changelog in a pager'
    'version:Show current dotfiles version, preset, and theme'
    'edit:Open dotfiles directory in $EDITOR'
    'cd:Print dotfiles path'
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
      theme|-t)
        local -a theme_opts
        theme_opts=(
          'list:List available themes'
          'current:Show current theme'
          'generate:Generate theme from Ghostty'
          'delete:Delete a generated theme'
        )
        # Add available theme names from themes/ directory
        local dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"
        local theme_file
        for theme_file in "$dotfiles_dir"/themes/*.theme(N); do
          local name="${theme_file:t:r}"
          theme_opts+=("${name}:Switch to ${name} theme")
        done
        _describe 'theme' theme_opts
        ;;
    esac
  elif (( CURRENT == 4 )); then
    case "${words[2]}" in
      set)
        _files -/
        ;;
      theme|-t)
        case "${words[3]}" in
          generate)
            local -a gen_opts
            gen_opts=(
              'list:List all Ghostty themes'
              'help:Show help'
            )
            local dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"
            if [[ -x "$dotfiles_dir/scripts/generate-theme" ]]; then
              local -a themes
              themes=(${(f)"$("$dotfiles_dir/scripts/generate-theme" list 2>/dev/null)"})
              for t in "${themes[@]}"; do
                [[ -n "$t" ]] && gen_opts+=("$t")
              done
            fi
            _describe 'generate-theme' gen_opts
            ;;
          delete)
            local -a del_opts
            del_opts=(
              'all:Remove all generated themes'
              'list:List generated themes'
              'help:Show help'
            )
            local dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"
            for theme_file in "$dotfiles_dir"/themes/generated/*.theme(N); do
              local name="${theme_file:t:r}"
              del_opts+=("${name}:Delete generated theme")
            done
            _describe 'theme-delete' del_opts
            ;;
        esac
        ;;
    esac
  elif (( CURRENT == 5 )); then
    # dotfiles theme delete all --yes
    if [[ "${words[2]}" == "theme" || "${words[2]}" == "-t" ]] && \
       [[ "${words[3]}" == "delete" ]] && [[ "${words[4]}" == "all" ]]; then
      local -a flags
      flags=('--yes:Skip confirmation prompt')
      _describe 'flags' flags
    fi
  fi
}
compdef _dotfiles dotfiles
compdef _dotfiles dot

# =============================================================================
# COMMAND EXIT ALERTS (auto-alert for long-running commands)
# =============================================================================
# Automatically sends a tmux alert when a command finishes after ≥10 seconds
# and you've switched away from the window while it was running.
[[ -f "$HOME/dotfiles/scripts/hooks/cmd-alert-hook.zsh" ]] && source "$HOME/dotfiles/scripts/hooks/cmd-alert-hook.zsh"

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
[[ -n "$ZPROF" ]] && zprof || true
