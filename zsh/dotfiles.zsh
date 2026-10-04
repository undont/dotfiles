# shellcheck shell=zsh
# =============================================================================
# DOTFILES ZSH FRAMEWORK
# =============================================================================
# shared shell configuration sourced by ~/.zshrc.
# do NOT symlink this file directly; source it from your personal ~/.zshrc:
#
#   source ~/dotfiles/zsh/dotfiles.zsh
#
# file structure:
#   ~/.zshrc                           - your personal config (sources this file)
#   ~/.zprofile                        - login shell config (PATH additions from installers)
#   ~/.p10k.zsh                        - powerlevel10k theme configuration
#   ~/.config/zsh/secrets.zsh          - API keys and credentials (not version controlled)

# =============================================================================
# STARTUP PROFILING (optional)
# =============================================================================
# enable with: ZPROF=1 zsh -i -c exit
# or use: zsh-profile-detailed
[[ -n "$ZPROF" ]] && zmodload zsh/zprof

# =============================================================================
# PLATFORM DETECTION
# =============================================================================
# must run before anything that needs HOMEBREW_PREFIX
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

# a newly tapped third-party repo needs `brew trust --tap <user/repo>` before
# brew loads its formulae or casks. the Brewfile's taps are trusted during install
export HOMEBREW_REQUIRE_TAP_TRUST=1

# =============================================================================
# HOMEBREW ENVIRONMENT (non-login shells)
# =============================================================================
# ~/.zprofile runs `brew shellenv` for login shells only. most linux terminal
# emulators open a non-login interactive shell that skips ~/.zprofile, leaving
# brew and everything it installs off PATH, so shellenv runs here when brew is
# not on PATH
if ((! $+commands[brew])); then
    for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [[ -x "$_brew" ]]; then
            eval "$("$_brew" shellenv)"
            break
        fi
    done
    unset _brew
fi

# =============================================================================
# FILE DESCRIPTOR LIMIT
# =============================================================================
# the macOS default soft limit is too low for nvim plugins that spawn many git
# subprocesses (diffview, gitsigns), which fail with EMFILE
[[ "$IS_MACOS" == "1" ]] && ulimit -n 10240 2>/dev/null

# =============================================================================
# TERMINFO FALLBACK
# =============================================================================
# ghostty sets TERM=xterm-ghostty; fall back to xterm-256color on machines
# without that terminfo entry (e.g. ssh targets)
if [[ "$TERM" == "xterm-ghostty" ]] && ! infocmp xterm-ghostty &>/dev/null; then
    export TERM=xterm-256color
fi

# powerlevel10k theme and its config
if [[ -f "$HOMEBREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
    source "$HOMEBREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme"
fi
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# =============================================================================
# PATH CONFIGURATION
# =============================================================================
# ~/.zprofile also sets `typeset -U path PATH`; repeated here so non-login
# shells dedupe too
typeset -U path PATH

# go install puts binaries in GOPATH/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# cargo install binaries, rustup toolchains
export PATH="$PATH:$HOME/.cargo/bin"

# java (openjdk via homebrew). JAVA_HOME is set from the keg rather than
# /usr/libexec/java_home: brew's JDKs aren't registered under
# /Library/Java/JavaVirtualMachines, and java_home exits 0 with the system JRE
# for any -v it can't satisfy, so a java-8-only machine pins java to 8 there
if [[ -d "$HOMEBREW_PREFIX/opt/openjdk" ]]; then
    export JAVA_HOME="$HOMEBREW_PREFIX/opt/openjdk"
    export PATH="$JAVA_HOME/bin:$PATH"
fi

# uv tool install target
export PATH="$PATH:$HOME/.local/bin"

# tmux session launchers
export PATH="$PATH:$HOME/.local/launchers"

# user scripts
export PATH="$HOME/bin:$PATH"

# nvim mason tools, appended so homebrew-installed versions take priority
export PATH="$PATH:$HOME/.local/share/nvim/mason/bin"

# .NET global tools (EasyDotnet, etc.)
export PATH="$PATH:$HOME/.dotnet/tools"
export DOTNET_ROLL_FORWARD='Major'

# arm-none-eabi headers for embedded work
export INCLUDE="$HOMEBREW_PREFIX/arm-none-eabi/include"
# export LIB="$HOMEBREW_PREFIX/arm-none-eabi/lib"

# =============================================================================
# GOOGLE CLOUD SDK - LAZY LOADED
# =============================================================================
# gcloud, gsutil and bq load the SDK paths and completion on first use
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
# fnm reads .nvmrc and .node-version files on cd (--use-on-cd)
if command -v fnm &>/dev/null; then
    eval "$(fnm env --use-on-cd)"
fi

# =============================================================================
# DOCKER & COMPLETIONS
# =============================================================================
# dotfiles autoloaded functions and completions. DOTFILES_ROOT must be set
# before this fpath entry, otherwise the path resolves to "/zsh/functions" and
# _dotfiles fails to autoload
export DOTFILES_ROOT="${DOTFILES_DIR:-$HOME/dotfiles}"
fpath=("$DOTFILES_ROOT/zsh/functions" $fpath)

# docker CLI completions
fpath=("$HOME/.docker/completions" $fpath)

# OS-provided completions for the systemd tools carapace has no completer for
# (loginctl, hostnamectl, timedatectl, ...). appended so it only fills gaps;
# carapace re-registers the ones it owns via compdef after compinit
[[ -d /usr/share/zsh/vendor-completions ]] && fpath=($fpath /usr/share/zsh/vendor-completions)

# brew's zsh-completions installs to its own share dir, separate from
# site-functions. appended so it only fills gaps; must precede compinit
[[ -d "$HOMEBREW_PREFIX/share/zsh-completions" ]] && fpath=($fpath "$HOMEBREW_PREFIX/share/zsh-completions")

# regenerate the completion dump at most once a day. the (#q...) glob qualifier
# needs EXTENDED_GLOB, scoped to the anonymous function by local_options
autoload -Uz compinit
# shellcheck disable=SC1009,SC1036,SC1072,SC1073
() {
    setopt local_options EXTENDED_GLOB
    if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
        compinit
    else
        compinit -C
    fi
}

# gh's completion file carries a compdef line that conflicts with zsh autoload;
# re-register after compinit (https://github.com/cli/cli/issues/8462)
(($+commands[gh])) && compdef _gh gh 2>/dev/null

# =============================================================================
# CACHED EVAL HELPER
# =============================================================================
# cache the output of slow eval commands (direnv, fzf) instead of forking on
# every startup. the cache is stale when the binary is newer than it (brew
# upgrade). usage: _cached_eval <name> <command...>
_cached_eval() {
    local name="$1"
    shift
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
    local cache_file="$cache_dir/$name.zsh"
    local bin_path="${commands[$name]}"

    # tool not installed: skip instead of printing "command not found" on every
    # prompt. minimal installs lack direnv/fzf
    [[ -n "$bin_path" ]] || return 0

    if [[ -s "$cache_file" && "$cache_file" -nt "$bin_path" ]]; then
        source "$cache_file"
    else
        [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir"
        "$@" >"$cache_file"
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
# loads and unloads environment variables from .envrc files on cd
_cached_eval direnv direnv hook zsh

# =============================================================================
# ZSH LINE EDITOR (ZLE) BASE KEYMAP
# =============================================================================
# emacs mode must be set before fzf, zsh-autosuggestions and custom ZLE
# widgets (e.g. _cdl-widget), whose bindings `bindkey -e` would wipe
bindkey -e

# Option+key sends ESC followed by another character. with a short KEYTIMEOUT a
# lone ESC does not trigger vi-mode, Option+key sequences still arrive whole,
# and fzf can use ESC to exit
export KEYTIMEOUT=1 # in hundredths of a second

# inside tmux, ignore EOF (Ctrl+D) at the prompt so an accidental press doesn't
# close the shell, which would tear down the pane and, if last, the window.
# outside tmux, Ctrl+D still exits normally
[[ -n "$TMUX" ]] && setopt IGNORE_EOF

# treat hyphens, dots, underscores, and slashes as word separators so
# Opt+Backspace and Ctrl+W delete one segment at a time for kebab-case,
# snake_case, dotted.name, and file/paths
WORDCHARS='*?[]~=&;!#$%^(){}<>'

# =============================================================================
# ZSH PLUGINS
# =============================================================================
# zsh-autosuggestions: accept a suggestion with Right or End
if [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# fzf keybindings: Ctrl+R (history), Ctrl+T (files)
_cached_eval fzf fzf --zsh

# theme colours for fzf. fzf-theme.sh relies on DOTFILES_ROOT (exported in the
# fpath block) to skip its subshell-based path detection
if [[ -f "$DOTFILES_ROOT/scripts/fzf-theme.sh" ]]; then
    source "$DOTFILES_ROOT/scripts/fzf-theme.sh"
    _fzf_theme_cached="${CURRENT_THEME:-}"

    # re-source fzf-theme.sh when the active theme changes
    _fzf_theme_refresh() {
        local live
        live=$(<"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/current-theme" 2>/dev/null) || return
        if [[ "$live" != "$_fzf_theme_cached" ]]; then
            source "$DOTFILES_ROOT/scripts/fzf-theme.sh"
            _fzf_theme_cached="$live"
        fi
    }

    # wrap fzf ZLE widgets so Ctrl+R/T pick up theme changes
    for _w in fzf-file-widget fzf-history-widget; do
        if zle -l "$_w" &>/dev/null; then
            zle -A "$_w" "_orig-$_w"
            eval "_wrapped-${_w}() { _fzf_theme_refresh; zle _orig-${_w}; }"
            zle -N "$_w" "_wrapped-${_w}"
        fi
    done
    unset _w

    # unbind Alt+C (fzf-cd-widget): terminals send the same sequence for Esc then
    # "c". Opt+A (_cdl-widget) is the directory picker
    bindkey -r '\ec'

    # Opt+A: directory history picker. runs fzf in the widget, cds, then redraws
    # the prompt
    _cdl-widget() {
        if ((${#_dir_back_stack} == 0)); then
            zle redisplay
            return 0
        fi
        setopt localoptions pipefail 2>/dev/null
        local -a reversed=()
        local prev="" i
        for ((i = ${#_dir_back_stack}; i >= 1; i--)); do
            local entry="${_dir_back_stack[$i]}"
            if [[ "$entry" != "$prev" ]]; then
                reversed+=("$entry")
                prev="$entry"
            fi
        done
        local count=${#reversed[@]}
        _fzf_theme_refresh 2>/dev/null
        local dir
        dir="$(
            printf '%s\n' "${reversed[@]}" | fzf \
                --height=40% --reverse \
                --header="$count entries" \
                --preview='ls -CF {}'
        )"
        if [[ -z "$dir" ]]; then
            zle redisplay
            return 0
        fi
        if [[ -d "$dir" ]]; then
            builtin cd -- "$dir"
            # re-run precmd hooks so p10k regenerates the prompt for the new directory
            local f
            for f in $precmd_functions; do "$f" 2>/dev/null; done
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
# multi-shell completion provider that bridges zsh's existing completion
# system, so builtin zsh completions keep working
export CARAPACE_BRIDGES='zsh'
zstyle ':completion:*:git:*' group-order 'main commands' 'alias commands' 'external commands'
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
if (($+commands[carapace])); then
    _cached_eval carapace carapace _carapace
fi

# =============================================================================
# TERMINAL TITLE HOOKS
# =============================================================================
# terminal/tab titles. _dotfiles_precmd shows directory + git branch before
# each prompt, _dotfiles_preexec shows the running command. the branch is cached
# in _git_branch and refreshed on chpwd and at the prompt after a git command

_git_branch=""
_git_branch_stale=0

_update_git_branch() {
    _git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
}

chpwd_functions+=(_update_git_branch)

# populate the cache at the first prompt, not at source time
_update_git_branch_once() {
    _update_git_branch
    precmd_functions=(${precmd_functions:#_update_git_branch_once})
}
precmd_functions+=(_update_git_branch_once)

_dotfiles_precmd() {
    if ((_git_branch_stale)); then
        _update_git_branch
        _git_branch_stale=0
    fi
    if [[ -n "$_git_branch" ]]; then
        print -Pn "\e]0;%1~ ($_git_branch)\a"
    else
        print -Pn "\e]0;%1~\a"
    fi
}
precmd_functions+=(_dotfiles_precmd)

_dotfiles_preexec() {
    local cmd="${1%% *}"

    # resolve job-control resumes (fg, fg %2, %2) to the job's real command via
    # $jobtexts, otherwise the title becomes "fg" and tmux automatic-rename
    # picks it up as the window name for title-named panes (claude)
    local job=""
    case "$cmd" in
        fg)
            local -a words
            words=(${(z)1})
            job="${words[2]:-%+}"
            ;;
        %*) job="$cmd" ;;
    esac
    [[ "$job" == (%*|<->) ]] && cmd="${${jobtexts[$job]:-$cmd}%% *}"

    print -Pn "\e]0;${cmd}\a"

    case "$cmd" in
        git | gh | tig) _git_branch_stale=1 ;;
    esac
}
preexec_functions+=(_dotfiles_preexec)

# =============================================================================
# SECRETS & CREDENTIALS
# =============================================================================
# API keys and tokens, not version controlled. see zsh/secrets.zsh.template
ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
if [[ -f "$ZSH_CONFIG_DIR/secrets.zsh" ]]; then
    source "$ZSH_CONFIG_DIR/secrets.zsh"
fi

# android SDK (homebrew cask android-commandlinetools): sdkmanager, avdmanager,
# adb, fastboot, emulator
if [[ -d "$HOMEBREW_PREFIX/share/android-commandlinetools" ]]; then
    export ANDROID_HOME="$HOMEBREW_PREFIX/share/android-commandlinetools"
    export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
fi

# =============================================================================
# .NET
# =============================================================================
export DOTNET_CLI_TELEMETRY_OPTOUT='true'
# stop MSBuild keeping worker nodes alive between builds
export MSBUILDDISABLENODEREUSE=1

# =============================================================================
# SONARCLOUD
# =============================================================================
# sonar-scanner CLI host
export SONAR_HOST_URL="https://sonarcloud.io"

# =============================================================================
# GIT
# =============================================================================
# skip the optional index.lock that read-only git commands (status, diff) take
# to write back a refreshed index. background status polls (an editor's git
# integration, several claude code sessions on one worktree) otherwise collide
# with an in-flight commit and fail it. real index writes still lock normally
export GIT_OPTIONAL_LOCKS=0

# =============================================================================
# LAZYGIT
# =============================================================================
# base config (symlinked from dotfiles) plus local overrides; lazygit merges
# both files. LG_CONFIG_FILE replaces the default path, so ~/.config/lazygit/ is
# used on all platforms
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
# point opencode-tmux-alert plugin to dotfiles hook scripts
export OPENCODE_ALERT_SCRIPT="$DOTFILES_ROOT/scripts/hooks/wrappers/opencode-alert.sh"
export OPENCODE_CLEAR_SCRIPT="$DOTFILES_ROOT/scripts/hooks/agent-alert-clear.sh"

# =============================================================================
# SSH WRAPPER
# =============================================================================
# ghostty sets TERM=xterm-ghostty, which most remote hosts don't recognise; ssh
# gets xterm-256color instead
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
# the `dotfiles aliases` cheatsheet renders this section by parsing:
#   # @section: <Name>                       section header (uppercased for display)
#   alias name="..."  # description           alias entry (description required)
#   # @cheat: <name> | <description>          free-form entry (any line)
#   # @cheat: <description>                   function entry, paired with the
#   followed by `name() { ... }`               next function definition
# aliases without a trailing description are skipped. see cmd_aliases /
# _aliases_parse in scripts/dotfiles

export EDITOR="nvim"

# render man pages in nvim instead of less; plain less inside :terminal so
# `man foo` from an nvim shell doesn't nest another nvim
if [[ -n "$NVIM" ]]; then
    export MANPAGER="less"
else
    export MANPAGER="nvim +Man!"
fi

# @section: NAVIGATION

alias c="clear"                                                                         # clear
alias cl="printf '\033[2J\033[3J\033[H'; [[ -n \$TMUX ]] && tmux clear-history || true" # clear + scrollback
# @cheat: ..  | cd ..
alias ..="cd .."
# @cheat: ... | cd ../..
alias ...="cd ../.."

# @cheat: mkcd <dir> | mkdir + cd
mkcd() { mkdir -p "$1" && cd "$1"; }

# directory back/forward navigation (browser-style).
# cdb: previous directory; cdf: forward (after going back)
typeset -ga _dir_back_stack _dir_forward_stack
_dir_nav_active=0

_dir_track_chpwd() {
    # skip tracking when cdb/cdf triggered the change
    if ((_dir_nav_active)); then return; fi
    _dir_back_stack+=("$OLDPWD")
    _dir_forward_stack=()
    ((${#_dir_back_stack} > 50)) && _dir_back_stack=("${_dir_back_stack[@]: -50}")
}
chpwd_functions+=(_dir_track_chpwd)

# @cheat: cd back (browser)
cdb() {
    if ((${#_dir_back_stack} == 0)); then
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

# @cheat: cd forward (after cdb)
cdf() {
    if ((${#_dir_forward_stack} == 0)); then
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

# directory history picker for the command line; the Opt+A widget has its own inline copy
autoload -Uz _cdl

# @cheat: Opt+A | cd from history (fzf)

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^g' edit-command-line # Ctrl+G: edit the command line in $EDITOR

bindkey ' ' magic-space # Space: history expansion

# @section: FILES

# BSD ls uses -G, GNU ls uses --color=auto
if [[ "$IS_MACOS" == "1" ]]; then
    alias ls="ls -G" # ls (colour-aware)
else
    alias ls="ls --color=auto"
fi
alias ll="ls -alF" # ls -alF
alias la="ls -A"   # ls -A
alias l="ls -CF"   # ls -CF

alias cp="cp -i" # cp -i (safe overwrite)
alias mv="mv -i" # mv -i (safe overwrite)

alias -s md='glow -t' # open .md files with glow

# yazi: cd the shell to the last-browsed directory on quit (--cwd-file)
# @cheat: yazi file manager (cd to last dir on quit)
y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# @section: SEARCH & PROCESS

alias grep="grep --color=auto" # grep --color=auto
# @cheat: rg | ripgrep (fast search)
# @cheat: psg <name> | ps aux | grep
alias psg="ps aux | grep -v grep | grep"
alias ports="lsof -i -P -n | grep LISTEN" # lsof ports (local)

# @section: GIT

alias gs="git status -sb"                                                                                                            # git status -sb
alias gd="git diff"                                                                                                                  # git diff
alias gdn="git diff | diffnav"                                                                                                       # git diff (diffnav)
alias gds="git diff --stat"                                                                                                          # git diff --stat
alias gl="git log --graph --decorate --format='%C(yellow)%h%C(reset) %s %C(dim)(%ar, %an)%C(reset)' -20"                             # git log (last 20)
alias glf="git log --graph --decorate --format='%C(yellow)%h%C(reset) %s %C(dim)(%ad, %an)%C(reset)' --date=format:'%d %B %Y %H:%M'" # git log (full)
alias gco="git checkout"                                                                                                             # git checkout
alias gsw="git switch"                                                                                                               # git switch
alias gb="git branch -vv"                                                                                                            # git branch -vv
alias gp="git push"                                                                                                                  # git push
alias gpl="git pull"                                                                                                                 # git pull
alias gst="git stash"                                                                                                                # git stash
alias gfp="git fetch -pf"                                                                                                            # git fetch --prune --force
alias gpr="git branch -vv | grep ': gone]' | awk '{print \$1}' | xargs -r git branch -D"                                             # prune local branches
alias grmc="git rm --cached"                                                                                                         # git rm --cached
alias gca="git commit --amend"                                                                                                       # git commit --amend

# make: forward to repo root when no Makefile in current directory
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

# @section: TMUX

alias tls="~/.tmux/scripts/resurrect/restore.sh --list" # list session backups
# @cheat: ta/tattach | attach/restore session
alias ta="tattach"
# @cheat: ac | clear all tmux alerts
alias alerts-clear="rm -rf ${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts"
alias ac="alerts-clear"
alias tcleanup="~/.tmux/scripts/tests/cleanup-tests.sh" # clean test resources

# asciinema demo recording (no cheatsheet entry)
alias demo-rec='asciinema rec --idle-time-limit 2 --cols 120 --rows 35'

# functions (instead of aliases) for tab completion support
# @cheat: restore from backup
trestore() {
    ~/.tmux/scripts/resurrect/restore.sh "$@"
}

# attach to tmux session, restoring from backup if needed
tattach() {
    if tmux a -t "$1" 2>/dev/null; then return 0; fi

    local backup="${HOME}/.tmux/resurrect/sessions/$1.txt"
    if [[ -f "$backup" ]]; then
        echo "Restoring '$1' from backup..."
        if ~/.tmux/scripts/resurrect/restore.sh --session "$1" && tmux a -t "$1"; then
            return 0
        fi
        echo "Backup stale, removing: $1"
        rm -f "$backup"
        return 1
    fi
    echo "No session or backup found: $1"
    return 1
}

# terminal entry to the launcher system: no args opens the launcher picker,
# with a query it resolves a directory via zoxide and opens a dev session
# there (attaches if the session already exists, creates it otherwise)
# @cheat: tl | launcher picker (no args) or zoxide query into a dev session
tl() {
    if (($# == 0)); then
        ~/.tmux/scripts/launchers/picker.sh
        return
    fi

    local dir
    if [[ -d "$1" ]]; then
        dir="$1"
    elif ! dir=$(zoxide query -- "$@" 2>/dev/null); then
        echo "tl: no directory match for '$*'" >&2
        return 1
    fi

    # keep frecency fresh when launched from an explicit path
    zoxide add "$dir" 2>/dev/null || true
    dev "$dir"
}

# tab completion for tmux commands
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
    # complete with running tmux sessions (for tattach)
    local -a sessions
    sessions=(${(f)"$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"})
    _describe 'running tmux sessions' sessions
}

compdef _trestore_complete trestore
compdef _tmux_sessions_running tattach

# @section: SYSTEM & NETWORK

alias df="df -h"                 # df -h
alias du="du -sh"                # du -sh
alias myip="curl -s ifconfig.me" # curl ifconfig.me
alias v="cl && nvim"             # clear + nvim

# edit a root-owned file with the user's nvim config: sudoedit copies it to a
# temp path, opens it unprivileged, then writes it back elevated. SUDO_EDITOR
# must be an absolute path: sudoedit resolves a bare name against sudo's
# secure_path, which lacks homebrew's bin, and falls back to its compiled
# default editor
# @cheat: svim <file> | sudo-edit a root-owned file (sudoedit + nvim)
svim() { SUDO_EDITOR="$(command -v nvim)" sudoedit "$@"; }

if [[ "$IS_MACOS" == "1" ]]; then
    alias o="open"        # open file/dir
    alias finder="open ." # open in Finder (macOS)
else
    alias o="xdg-open"
fi

alias config="v ~/.config"                       # open nvim in ~/.config (dir)
alias cache="v ~/.cache"                         # open nvim in ~/.cache (dir)
alias zshrc="v ~/.zshrc"                         # open nvim in ~/.zshrc (file)
alias secrets="v ~/.config/zsh/secrets.zsh"      # open nvim in secrets.zsh (file)
alias launchers="v ~/.config/dotfiles/launchers" # open launcher configs (dir)
alias nconf="v ~/.config/nvim/local.lua"         # open nvim local config (file)
alias gconf="v ~/.config/ghostty/local"          # open ghostty local config (file)
alias tconf="v ~/.config/tmux/local.conf"        # open tmux local config (file)

# font preview (figlet/toilet font browser with fzf)
# @cheat: font-preview | font browser (fzf)
autoload -Uz font-preview

# clipboard: `<cmd> | clip` copies, bare `clip` pastes, -p forces paste. the
# backend follows the live display server, not binary presence: a wayland
# session usually has xclip too (via XWayland), and its clipboard is not the
# one wayland apps read. with no display server (headless, ssh) it uses OSC 52,
# which tmux forwards to the outer terminal via `set-clipboard on`. mirrors
# scripts/_lib/clipboard.sh
# @cheat: clip [-p] | copy stdin to clipboard, bare or -p pastes
clip() {
    emulate -L zsh
    local paste=0

    case "$1" in
        -p | -o | --paste) paste=1 ;;
        -h | --help)
            printf 'usage: <cmd> | clip    copy stdin to the clipboard\n'
            printf '       clip [-p]       paste the clipboard to stdout\n'
            return 0
            ;;
        # nothing piped in: paste. stdin is not a tty in a script, so bare `clip`
        # copies there and blocks on empty stdin like bare `pbcopy`; -p forces paste
        '') [[ -t 0 ]] && paste=1 ;;
        *)
            printf 'clip: unknown option: %s\n' "$1" >&2
            return 2
            ;;
    esac

    local backend
    if [[ "$IS_MACOS" == "1" ]]; then
        backend=pb
    elif [[ -n "$WAYLAND_DISPLAY" ]] && ((${+commands[wl-copy]})); then
        backend=wayland
    elif [[ -n "$DISPLAY" ]] && (($+commands[xclip])); then
        backend=xclip
    elif [[ -n "$DISPLAY" ]] && (($+commands[xsel])); then
        backend=xsel
    elif (($+commands[clip.exe])); then
        backend=wsl
    elif ((${+commands[termux-clipboard-set]})); then
        backend=termux
    elif [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]]; then
        # a display server is running but its tool is missing. OSC 52 here would
        # send the payload out through the terminal and any ssh hop instead of
        # to the local clipboard
        backend=missing
    else
        backend=osc52
    fi

    if ((paste)); then
        case "$backend" in
            pb) pbpaste ;;
            wayland) wl-paste --no-newline ;;
            xclip) xclip -selection clipboard -o ;;
            xsel) xsel --clipboard --output ;;
            wsl) powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\r' ;;
            termux) termux-clipboard-get ;;
            missing) _clip_missing ;;
            # OSC 52 reads are refused or prompt-gated by most terminals, so there is
            # nothing to fall back to here
            osc52)
                printf 'clip: no clipboard to read from (no display server; OSC 52 is write-only)\n' >&2
                return 1
                ;;
        esac
    else
        case "$backend" in
            pb) pbcopy ;;
            wayland) wl-copy ;;
            xclip) xclip -selection clipboard ;;
            xsel) xsel --clipboard --input ;;
            wsl) clip.exe ;;
            termux) termux-clipboard-set ;;
            missing) _clip_missing ;;
            osc52) _clip_osc52 ;;
        esac
    fi
}

# a display server is running but no tool for it is installed. name the one that
# matches the session rather than listing all of them
_clip_missing() {
    emulate -L zsh
    if [[ -n "$WAYLAND_DISPLAY" ]]; then
        printf 'clip: no clipboard tool for this wayland session; install wl-clipboard\n' >&2
    else
        printf 'clip: no clipboard tool for this X11 session; install xclip or xsel\n' >&2
    fi
    return 1
}

# write stdin to the terminal clipboard via OSC 52. needs a writable tty, and
# terminals cap the payload, so oversized input is refused rather than silently
# truncated into a half-copy. writes to /dev/tty, never stdout, so redirecting
# clip's output never lands the escape sequence in a file
_clip_osc52() {
    emulate -L zsh
    local b64
    b64=$(base64 | tr -d '\r\n') || return 1

    if [[ ! -w /dev/tty ]]; then
        printf 'clip: no tty available for OSC 52\n' >&2
        return 1
    fi
    if ((${#b64} > 74994)); then
        printf 'clip: input too large for OSC 52 (%d encoded bytes)\n' "${#b64}" >&2
        return 1
    fi

    printf '\033]52;c;%s\a' "$b64" >/dev/tty
}

# compat shims, Linux only: macOS has the real binaries, and anything piping to
# pbcopy keeps working. no cheatsheet entry (clip is the documented name)
if [[ "$IS_MACOS" != "1" ]]; then
    alias pbcopy="clip"
    alias pbpaste="clip -p"
fi

# @section: DEVELOPMENT

alias opencode="cl && opencode" # cl + opencode
alias oc="opencode"
alias claude="cl && claude" # cl + claude
alias ralph="cl && ralph"
alias ralf="cl && ralf"
alias copilot="cl && copilot" # cl + copilot
alias btop="cl && btop"
alias drs="dash-repo-sync"                                                            # sync repo paths
alias ff="fastfetch"                                                                  # fastfetch system info
alias dash="cl && gh dash"                                                            # cl + gh dash
alias j="cl && jiru"                                                                  # cl + jiru (Jira TUI)
alias lg="cl && lazygit"                                                              # cl + lazygit
alias ld="cl && lazydocker"                                                           # cl + lazydocker
alias gols="ls ~/go/bin"                                                              # list Go binaries
alias rsls="ls ~/.cargo/bin"                                                          # list Rust binaries
alias nvim-clear="rm -rf ~/.cache/nvim/luac/ && echo 'Cleared Neovim bytecode cache'" # clear nvim cache

# @cheat: nvim-sync | sync Lazy.nvim plugins
nvim-sync() {
    printf "Syncing Neovim plugins...\n"
    nvim --headless "+Lazy! sync" +qa
    printf "\033[0;32m✔\033[0m Neovim plugins synced\n"
}

# render code or terminal output to an image in a monospace family: freeze's
# built-in default family is not installed and falls back to a proportional
# sans. -F picks another installed mono font via fzf and keeps it in
# $FREEZE_FONT for the session. an explicit --font.family / --font.file wins
# @cheat: freeze [-F] <file> | render code/output to an image (mono font)
freeze() {
    emulate -L zsh
    local default_font="JetBrainsMono Nerd Font Mono"
    local -a args
    local a picked=0

    for a in "$@"; do
        case "$a" in
            -F | --pick-font) picked=1 ;;
            *) args+=("$a") ;;
        esac
    done

    if ((picked)); then
        local chosen
        # installed monospace families, collapsed to base names: drop style/weight
        # variants, the non-mono "Nerd Font" spelling and the NF/NFM abbreviations
        # (keeping Monaspace, whose canonical family name ends in NF)
        chosen=$(fc-list :spacing=mono family 2>/dev/null |
            tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' |
            grep -v '^\.' | grep -viE 'emoji|lastresort|times lt mm' |
            grep -viE 'extrabold|extralight|semibold|semiwide|medium|light|thin|bold|italic|wide|narrow|black|retina|condensed|oblique' |
            awk '/ Nerd Font$/ {next} /Monaspace/ {print; next} / NFM?$/ {next} {print}' |
            sort -u |
            fzf --prompt='freeze font ❯ ' --height=40% --reverse)
        [[ -n "$chosen" ]] && export FREEZE_FONT="$chosen" &&
            printf '\033[0;32m✔\033[0m freeze font → %s\n' "$chosen"
        ((${#args})) || return 0
    fi

    if [[ "${args[*]}" != *--font.family* && "${args[*]}" != *--font.file* ]]; then
        args=(--font.family "${FREEZE_FONT:-$default_font}" "${args[@]}")
    fi

    command freeze "${args[@]}"
}

# completion for the freeze wrapper: carapace's spec completes flags and their
# values but nothing for the file positional, and errors on -F. delegates to
# carapace with -F hidden, then adds file completion unless the previous word
# is a value flag. this compdef runs after carapace's catch-all, so it wins
_freeze() {
    local -a _ws _fw
    local _cur _i _rm

    if (($+functions[_carapace_completer])); then
        _ws=("${words[@]}")
        _cur=$CURRENT
        _rm=0
        for ((_i = 1; _i <= $#words; _i++)); do
            if ((_i != CURRENT)) && [[ ${words[_i]} == (-F|--pick-font) ]]; then
                ((_i < CURRENT)) && ((_rm++))
                continue
            fi
            _fw+=("${words[_i]}")
        done
        words=("${_fw[@]}")
        ((CURRENT -= _rm))
        _carapace_completer
        words=("${_ws[@]}")
        CURRENT=$_cur
    fi

    case ${words[CURRENT - 1]} in
        -l | --language | -t | --theme | -w | --wrap | -x | --execute | -b | --background | -m | --margin | -p | --padding | -W | --width | -H | --height | -r | --border.radius | --border.width | --border.color | --shadow.blur | --shadow.x | --shadow.y | --font.family | --font.size | --line-height) ;;
        *)
            _files
            compadd -- -F --pick-font
            ;;
    esac
}
(($+functions[compdef])) && compdef _freeze freeze

alias brewup="brew update && brew upgrade"                                                                                                                                                                                                                                                   # brew update + upgrade
alias nuke-node='killall -9 node 2>/dev/null && echo "done" || echo "no node processes"'                                                                                                                                                                                                     # kill all node procs
alias nuke-nvim='ps -eo pid,ppid,args | awk "/nvim --embed/ && \$2 == 1 {print \$1}" | xargs kill 2>/dev/null && echo "done" || echo "no stale nvim processes"'                                                                                                                              # kill stale nvim procs
alias nuke-dotnet='dotnet build-server shutdown 2>/dev/null; pkill -f "OmniSharp.dll" 2>/dev/null; pkill -f "EasyDotnet.BuildServer.dll" 2>/dev/null; pkill -f "dotnet-easydotnet" 2>/dev/null; pkill -f "VBCSCompiler" 2>/dev/null; pkill -f "vstest.console.dll" 2>/dev/null; echo "done"' # kill stale dotnet procs
alias dot="dotfiles"

# relocate claude code per-project data (session transcripts + memories) so it
# follows a moved project. claude keys the dir on the absolute path with every
# non-alphanumeric char replaced by '-'. refuses to merge onto an existing
# destination to avoid clobbering a memory index; leaves the source in place
_move_claude_data() {
    emulate -L zsh
    local base="$HOME/.claude/projects"
    local src_dir="$base/${1//[^A-Za-z0-9]/-}"
    local dest_dir="$base/${2//[^A-Za-z0-9]/-}"

    [[ -d "$src_dir" && "$src_dir" != "$dest_dir" ]] || return 0

    if [[ -e "$dest_dir" ]]; then
        printf "\033[0;33m!\033[0m claude history exists at the destination; left it at %s\n" "${src_dir:t}" >&2
        return 0
    fi

    command mv "$src_dir" "$dest_dir" &&
        printf "\033[0;32m✔\033[0m claude history + memories moved\n"
}

# move a project between playground (PROJECTS_ROOT) and code (DEV_ROOT).
# graduate promotes playground → code; relegate sends code → playground.
# moves claude history, repoints gh-dash paths, then cd into the new home
_move_project() {
    emulate -L zsh
    local src_root="$1" dest_root="$2" name="${3:t}" verb="$4"

    if [[ -z "$name" ]]; then
        printf "usage: %s <project>\n" "$verb" >&2
        return 2
    fi

    local src="$src_root/$name" dest="$dest_root/$name"
    if [[ ! -d "$src" ]]; then
        printf "\033[0;31m✘\033[0m not found: %s\n" "$src" >&2
        return 1
    fi
    if [[ -e "$dest" ]]; then
        printf "\033[0;31m✘\033[0m already exists: %s\n" "$dest" >&2
        return 1
    fi

    command mkdir -p "$dest_root"
    command mv "$src" "$dest" || return 1
    printf "\033[0;32m✔\033[0m %s → %s\n" "$src" "$dest"

    _move_claude_data "$src" "$dest"

    if command -v dash-repo-sync >/dev/null 2>&1; then
        dash-repo-sync >/dev/null 2>&1 && printf "\033[0;32m✔\033[0m gh-dash paths synced\n"
    fi

    cd "$dest"
}

# @cheat: promote to code
graduate() {
    local name="${1:t}"
    _move_project "${PROJECTS_ROOT:-$HOME/playground}" "${DEV_ROOT:-$HOME/code}" "$name" graduate || return
    # nvim resolves local dev plugins from playground only (lazy dev.path), so a
    # graduated plugin silently falls back to its remote; flag it
    if [[ "$name" == *.nvim || -d "$PWD/lua" ]]; then
        printf "\033[0;33m!\033[0m looks like an nvim plugin: lazy dev.path points at playground, so this'll fall back to the remote. keep it in playground or update nvim/init.lua\n" >&2
    fi
}

# @cheat: demote to playground
relegate() {
    _move_project "${DEV_ROOT:-$HOME/code}" "${PROJECTS_ROOT:-$HOME/playground}" "${1:t}" relegate
}

# graduate completes from playground dirs, relegate from code dirs
_graduate_complete() {
    local root="${PROJECTS_ROOT:-$HOME/playground}"
    local -a projects
    projects=(${root}/*(/N:t))
    _describe 'playground projects' projects
}
_relegate_complete() {
    local root="${DEV_ROOT:-$HOME/code}"
    local -a projects
    projects=(${root}/*(/N:t))
    _describe 'code projects' projects
}
compdef _graduate_complete graduate
compdef _relegate_complete relegate

# promote/demote synonyms (completion follows the alias automatically)
alias promote="graduate"
alias demote="relegate"

# =============================================================================
# ZSH LINE EDITOR (ZLE) KEYBINDINGS
# =============================================================================
# bindkey -e and KEYTIMEOUT are set earlier, before plugins

bindkey '^[^?' backward-kill-word # Option+Backspace: delete word backwards
bindkey '^W' backward-kill-word   # Ctrl+W: delete word backwards

# Shift+Tab walks backwards through menu completions (complements Tab going forward)
bindkey '^[[Z' reverse-menu-complete

# bind Home/End in both forms: ghostty sends CSI H/F directly; tmux with
# extended-keys re-encodes them as VT220-style \x1b[1~ and \x1b[4~
bindkey '\e[H' beginning-of-line  # Home (Ghostty, CSI)
bindkey '\e[F' end-of-line        # End (Ghostty, CSI)
bindkey '\e[1~' beginning-of-line # Home (tmux-encoded)
bindkey '\e[4~' end-of-line       # End (tmux-encoded)
# \e[1~ shares the prefix \e[1 with modifier+arrow sequences (\e[1;2A etc).
# binding the full sequences resolves the ambiguity so ZLE doesn't garble them
bindkey '\e[1;2A' up-line-or-history   # Shift+Up
bindkey '\e[1;2B' down-line-or-history # Shift+Down
bindkey '\e[1;2C' forward-word         # Shift+Right
bindkey '\e[1;2D' backward-word        # Shift+Left
bindkey '\e[1;3A' up-line-or-history   # Opt+Up
bindkey '\e[1;3B' down-line-or-history # Opt+Down
bindkey '\e[1;5H' beginning-of-line    # Cmd+Up (via Ghostty: super+up → Ctrl+Home)
bindkey '\e[1;5F' end-of-line          # Cmd+Down (via Ghostty: super+down → Ctrl+End)

# Ctrl+J / Ctrl+K as Down/Up for menu + line nav (overrides accept-line/kill-line;
# Return still submits via ^M). scoped to zsh so nvim's own C-j/C-k are untouched
# @cheat: Ctrl+J / Ctrl+K | down / up in history, line, and completion menu
bindkey '^j' down-line-or-history # Ctrl+J → Down
bindkey '^k' up-line-or-history   # Ctrl+K → Up
# and move the highlight inside the tab-completion menu
zmodload -i zsh/complist 2>/dev/null
bindkey -M menuselect '^j' down-line-or-history
bindkey -M menuselect '^k' up-line-or-history
# @cheat: Cmd+Backspace | delete to line start
bindkey '\e[127;5u' backward-kill-line # Cmd+Backspace (via Ghostty: super+backspace → Ctrl+Backspace)

# ghostty sends these sequences for modifier+enter combos; bind them to
# accept-line so they act as Enter in zsh instead of printing garbage
bindkey '\e[13;5u' accept-line  # Ctrl+Enter (kitty protocol)
bindkey '\e[13;6u' accept-line  # Ctrl+Shift+Enter (kitty protocol)
bindkey '\e[;5;13~' accept-line # Ctrl+Enter (Ghostty variant)
bindkey '\e[;6;13~' accept-line # Ctrl+Shift+Enter (Ghostty variant)

# Ctrl+key combos with no legacy control-char encoding (Ctrl+-, Ctrl+=)
# arrive as CSI-u sequences (extended-keys-format csi-u). bind the actual
# csi-u form so ZLE consumes the whole sequence instead of leaking the tail
# (e.g. ';5u') as literal text. Ctrl+Shift+- already maps to undo via the
# legacy ^_ byte, so wire Ctrl+- to redo as its mirror
bindkey '\e[45;5u' redo  # Ctrl+- → redo (mirrors Ctrl+Shift+- → undo)
bindkey -s '\e[61;5u' '' # Ctrl+= (swallow)
# legacy modifyOtherKeys fallback (if extended-keys-format ever changes)
bindkey '\e[27;5;45~' redo  # Ctrl+- → redo
bindkey -s '\e[27;5;61~' '' # Ctrl+= (swallow)

# =============================================================================
# DOTFILES CLI
# =============================================================================
# tab completion for dotfiles command (autoloaded from zsh/functions/_dotfiles)
autoload -Uz _dotfiles
compdef _dotfiles dotfiles
compdef _dotfiles dot

# =============================================================================
# COMMAND EXIT ALERTS (auto-alert for long-running commands)
# =============================================================================
# sends a tmux alert when a command outlives $_CMD_ALERT_MIN_SECONDS and its
# window is not being viewed
[[ -f "$DOTFILES_ROOT/scripts/hooks/cmd-alert-hook.zsh" ]] && source "$DOTFILES_ROOT/scripts/hooks/cmd-alert-hook.zsh"

# =============================================================================
# ZOXIDE
# =============================================================================
# eager init so the zoxide `cd` is defined in every shell mode: interactive,
# `zsh -i -c` and `zsh -c`. __zoxide_doctor is a no-op: it checks
# chpwd_functions for __zoxide_hook, but claude code's shell snapshots capture
# function definitions without that array, so the check fails on every replay,
# and _ZO_DOCTOR=0 does not survive snapshotting
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init --cmd cd zsh)"
    __zoxide_doctor() { :; }
fi

# =============================================================================
# SHELL STARTUP PROFILING
# =============================================================================
# @section: PROFILING

# @cheat: benchmark startup (5x)
zsh-profile() {
    echo "Running 5 iterations..."
    for i in {1..5}; do
        time zsh -i -c exit
    done
}

# @cheat: detailed (ZPROF)
zsh-profile-detailed() {
    ZPROF=1 zsh -i -c exit
}

# =============================================================================
# DOTFILES CLI CHEATSHEET
# =============================================================================
# `dotfiles` subcommands, declared as free-form rows so `dotfiles aliases`
# renders them with the shell shortcuts above
# @section: DOTFILES CLI
# @cheat: update  -u | smart update
# @cheat: status  -s | version + sync + changes
# @cheat: health | full health check
# @cheat: links   -l | managed symlinks
# @cheat: theme   -t | colour themes
# @cheat: set dev <d> | set DEV_ROOT
# @cheat: diff    -d | copy-on-install diffs
# @cheat: sync | sync copy-on-install
# @cheat: export | local layer to private repo
# @cheat: import | local layer from private repo
# @cheat: local | manage local-layer repo
# @cheat: notes   -n | browse changelog
# @cheat: version -v | version, preset, theme
# @cheat: edit    -e | open in $EDITOR
# @cheat: cd | print dotfiles path
# @cheat: aliases -a | show this reference
# @cheat: dot | shorthand for dotfiles
# @cheat: help | show help message

# =============================================================================
# ZPROF OUTPUT (end of startup)
# =============================================================================
[[ -n "$ZPROF" ]] && zprof || true
