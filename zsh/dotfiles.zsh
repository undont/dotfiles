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

# Rust/Cargo binaries (cargo install, rustup toolchains)
export PATH="$PATH:$HOME/.cargo/bin"

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
  local gcloud_dir="$HOMEBREW_PREFIX/share/google-cloud-sdk"
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
# Dotfiles autoloaded functions and completions
fpath=("$DOTFILES_ROOT/zsh/functions" $fpath)

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

  if [[ -n "$bin_path" && -s "$cache_file" && "$cache_file" -nt "$bin_path" ]]; then
    source "$cache_file"
  else
    [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir"
    "$@" > "$cache_file"
    if [[ -s "$cache_file" ]]; then
      source "$cache_file"
    else
      rm -f "$cache_file"
    fi
  fi
}

# =============================================================================
# DIRENV
# =============================================================================
# Automatically load/unload environment variables when entering directories
# with .envrc files. Great for per-project env vars.
_cached_eval direnv direnv hook zsh

# =============================================================================
# ZSH LINE EDITOR (ZLE) BASE KEYMAP
# =============================================================================
# Set emacs mode BEFORE plugins and custom bindings so they layer on top
# rather than being wiped. Must precede fzf, zsh-autosuggestions, and any
# custom ZLE widgets (e.g. _cdl-widget bound to Opt+A).
bindkey -e                             # Force emacs mode (Ctrl+A, Ctrl+E, etc.)

# Prevent accidental vi-mode activation from Option+key combinations
# Option+key sends ESC followed by another character. Setting KEYTIMEOUT to 1
# (10ms) means ESC alone won't trigger vi-mode, but ESC sequences from Option+key
# will be processed correctly, and tools like fzf can still use ESC to exit.
export KEYTIMEOUT=1                    # Wait 10ms for more chars after ESC

# Treat hyphens, dots, underscores, and slashes as word separators so
# Opt+Backspace and Ctrl+W delete one segment at a time for kebab-case,
# snake_case, dotted.name, and file/paths.
WORDCHARS='*?[]~=&;!#$%^(){}<>'

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
      source "$DOTFILES_ROOT/scripts/fzf-theme.sh"
      _fzf_theme_cached="$live"
    fi
  }

  # Wrap fzf ZLE widgets so Ctrl+R/T pick up theme changes immediately
  for _w in fzf-file-widget fzf-history-widget; do
    if zle -l "$_w" &>/dev/null; then
      zle -A "$_w" "_orig-$_w"
      eval "_wrapped-${_w}() { _fzf_theme_refresh; zle _orig-${_w}; }"
      zle -N "$_w" "_wrapped-${_w}"
    fi
  done
  unset _w

  # Unbind Alt+C (fzf-cd-widget) — terminals send the same escape sequence for
  # Esc+c and Alt+C, causing accidental triggers when pressing Esc then "c".
  # The Opt+A cdl-widget is the preferred directory picker.
  bindkey -r '\ec'

  # Opt+A: directory history picker (inline fzf selection + BUFFER cd)
  # Follows fzf's own Alt-C pattern: run fzf directly in the widget,
  # then set BUFFER to the cd command and accept-line to execute it.
  _cdl-widget() {
    if (( ${#_dir_back_stack} == 0 )); then
      zle redisplay
      return 0
    fi
    setopt localoptions pipefail 2>/dev/null
    local -a reversed=()
    local prev="" i
    for (( i=${#_dir_back_stack}; i>=1; i-- )); do
      local entry="${_dir_back_stack[$i]}"
      if [[ "$entry" != "$prev" ]]; then
        reversed+=("$entry")
        prev="$entry"
      fi
    done
    local count=${#reversed[@]}
    _fzf_theme_refresh 2>/dev/null
    local dir
    dir="$(printf '%s\n' "${reversed[@]}" | fzf \
      --height=40% --reverse \
      --header="$count entries" \
      --preview='ls -CF {}' \
    )"
    if [[ -z "$dir" ]]; then
      zle redisplay
      return 0
    fi
    if [[ -d "$dir" ]]; then
      builtin cd -- "$dir"
      # Re-run precmd hooks so P10k regenerates the prompt string with the
      # new directory, then reset-prompt to display it.
      local f; for f in $precmd_functions; do "$f" 2>/dev/null; done
      zle reset-prompt
    else
      zle redisplay
    fi
  }
  zle -N _cdl-widget
  bindkey '\ea' _cdl-widget
fi
# =============================================================================
# CARAPACE COMPLETIONS
# =============================================================================
# Multi-shell completion provider. Bridges zsh's existing completion system,
# so builtin zsh completions continue to work. Cached via _cached_eval so we
# don't fork `carapace _carapace` on every shell start.
export CARAPACE_BRIDGES='zsh'
zstyle ':completion:*:git:*' group-order 'main commands' 'alias commands' 'external commands'
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
if (( $+commands[carapace] )); then
  _cached_eval carapace carapace _carapace
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
# See ~/dotfiles/zsh/secrets.zsh.template for structure
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
# Prevent MSBuild from keeping worker nodes alive between builds
export MSBUILDDISABLENODEREUSE=1

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
export OPENCODE_ALERT_SCRIPT="$DOTFILES_ROOT/scripts/hooks/wrappers/opencode-alert.sh"
export OPENCODE_CLEAR_SCRIPT="$DOTFILES_ROOT/scripts/hooks/agent-alert-clear.sh"

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
alias v="cl && nvim"                   # Clear scrollback + launch Neovim
alias opencode="cl && opencode"        # Clear scrollback + launch OpenCode editor
alias oc="opencode"                    # Shorthand for OpenCode editor
alias claude="cl && claude"            # Clear scrollback + launch Claude AI CLI
alias ralph="cl && ralph"              # Clear scrollback + launch Ralph => Claude Code
alias ralf="cl && ralf"                # Clear scrollback + launch Ralf => Claude Code
alias gemini="cl && gemini"            # Clear scrollback + launch Gemini AI CLI
alias copilot="cl && copilot"          # Clear scrollback + launch GitHub Copilot CLI
alias btop="cl && btop"                # Clear scrollback + launch btop system monitor
alias dash="cl && gh dash"             # Clear scrollback + launch GitHub Dash
alias dot="dotfiles"                   # Shorthand for dotfiles CLI
alias drs="dash-repo-sync"             # Sync local repo paths into gh-dash config
alias ff="fastfetch"                   # Fastfetch system info
alias ac="alerts-clear"                # Clear tmux alerts (see alias below)
alias j="cl && jiru"                                 # Jiru CLI alias (cl to clear scrollback first)
alias lg="cl && lazygit"                           # LazyGit alias (cl to clear scrollback first)
alias ld="cl && lazydocker"                     # LazyDocker alias (cl to clear scrollback first)

# Tmux session management
alias tls="~/.tmux/scripts/resurrect/restore.sh --list"
alias tcleanup="~/.tmux/scripts/tests/cleanup-tests.sh"
alias alerts-clear="rm -rf ${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts"  # Clear all tmux alerts
alias ta="tattach" # Attach to tmux session, restoring from backup if needed (see tattach function below)

# Asciinema demo recording
alias demo-rec='asciinema rec --idle-time-limit 2 --cols 120 --rows 35'

# Navigation
alias c="clear"
alias cl="printf '\033[2J\033[3J\033[H'; [[ -n \$TMUX ]] && tmux clear-history || true"  # clear screen + scrollback
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
alias nuke-node='killall -9 node 2>/dev/null && echo "done" || echo "no node processes"'
alias nuke-nvim='ps -eo pid,ppid,args | awk "/nvim --embed/ && \$2 == 1 {print \$1}" | xargs kill 2>/dev/null && echo "done" || echo "no stale nvim processes"'
alias nuke-dotnet='dotnet build-server shutdown 2>/dev/null; pkill -f "OmniSharp.dll" 2>/dev/null; pkill -f "EasyDotnet.BuildServer.dll" 2>/dev/null; pkill -f "dotnet-easydotnet" 2>/dev/null; pkill -f "VBCSCompiler" 2>/dev/null; pkill -f "vstest.console.dll" 2>/dev/null; echo "done"'

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

# Quick access to config files
alias secrets="v ~/.config/zsh/secrets.zsh"  # Edit API keys and credentials
alias config="v ~/.config"                   # Edit general config files
alias zshrc="v ~/.zshrc"                     # Edit personal shell config

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

# Directory history picker (autoloaded from zsh/functions/_cdl, bound to Opt+A via ZLE widget)
autoload -Uz _cdl

# Font preview (figlet/toilet font browser with fzf)
autoload -Uz font-preview

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
alias gds="git diff --stat"
alias gl="git log --graph --decorate --format='%C(yellow)%h%C(reset) %s %C(dim)(%ar, %an)%C(reset)' -20"
alias glf="git log --graph --decorate --format='%C(yellow)%h%C(reset) %s %C(dim)(%ad, %an)%C(reset)' --date=format:'%d %B %Y %H:%M'"
alias gco="git checkout"
alias gsw="git switch"
alias gb="git branch -vv"
alias gp="git push"
alias gpl="git pull"
alias gst="git stash"
alias gfp="git fetch -pf"              # Fetch and prune remote-tracking branches
alias gpr="git branch -vv | grep ': gone]' | awk '{print \$1}' | xargs git branch -D"  # Prune local branches removed from remote
alias grmc="git rm --cached"           # Untrack file(s) without deleting from disk
alias gca="git commit --amend"         # Amend the last commit

# Make: forward to repo root when no Makefile in current directory
make() {
  if [[ ! -f Makefile && ! -f makefile && ! -f GNUmakefile ]]; then
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$root" && -f "$root/Makefile" ]]; then
      command make -C "$root" "$@"
      return
    fi
  fi
  command make "$@"
}

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
# Note: bindkey -e (emacs mode) and KEYTIMEOUT are set earlier, before plugins,
# so custom bindings from fzf and ZLE widgets aren't wiped.

# Ensure common word deletion shortcuts work correctly
bindkey '^[^?' backward-kill-word      # Option+Backspace: delete word backwards
bindkey '^W' backward-kill-word        # Ctrl+W: delete word backwards

# Shift+Tab walks backwards through menu completions (complements Tab going forward)
bindkey '^[[Z' reverse-menu-complete

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
bindkey '\e[1;5H' beginning-of-line   # Cmd+Up (via Ghostty: super+up → Ctrl+Home)
bindkey '\e[1;5F' end-of-line         # Cmd+Down (via Ghostty: super+down → Ctrl+End)

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
# Tab completion for dotfiles command (autoloaded from zsh/functions/_dotfiles)
autoload -Uz _dotfiles
compdef _dotfiles dotfiles
compdef _dotfiles dot

# =============================================================================
# COMMAND EXIT ALERTS (auto-alert for long-running commands)
# =============================================================================
# Automatically sends a tmux alert when a command finishes after ≥10 seconds
# and you've switched away from the window while it was running.
[[ -f "$DOTFILES_ROOT/scripts/hooks/cmd-alert-hook.zsh" ]] && source "$DOTFILES_ROOT/scripts/hooks/cmd-alert-hook.zsh"

# =============================================================================
# ZOXIDE
# =============================================================================
eval "$(zoxide init zsh)"

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
