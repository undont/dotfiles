#!/usr/bin/env bash
# exports FZF_DEFAULT_OPTS and the theme-derived vars for the current theme.
# sourced by the zsh framework and by individual scripts

# DOTFILES_ROOT set by the caller skips the subshell detection
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        # bash
        DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        # zsh; eval avoids a bash parse error
        DOTFILES_ROOT="$(cd "$(dirname "$(eval 'echo ${(%):-%x}')")/.." && pwd)"
    else
        DOTFILES_ROOT="${HOME}/dotfiles"
    fi
fi

THEMES_DIR="$DOTFILES_ROOT/themes"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
CURRENT_THEME_FILE="$CONFIG_DIR/current-theme"

if [[ -f "$CURRENT_THEME_FILE" ]]; then
    CURRENT_THEME=$(cat "$CURRENT_THEME_FILE")
else
    CURRENT_THEME="dracula"
fi

# only safe characters, to prevent path traversal
if [[ ! "$CURRENT_THEME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    CURRENT_THEME="dracula"
fi

# ─── Cache fast-path ────────────────────────────────────────────────
# a cache file holds every export the full source produces. it is stale when
# any input is newer than it: the current-theme selector, the active theme
# file, theme-defaults.sh, this script, or the ghostty config (which sets
# FZF_BG for transparency). the cache holds only `export` statements
_FZF_THEME_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
_FZF_THEME_CACHE_FILE="$_FZF_THEME_CACHE_DIR/fzf-env"

if [[ -f "$_FZF_THEME_CACHE_FILE" && -f "$CURRENT_THEME_FILE" &&
    "$_FZF_THEME_CACHE_FILE" -nt "$CURRENT_THEME_FILE" ]]; then
    _fzf_cache_stale=0
    for _fzf_input in \
        "$THEMES_DIR/$CURRENT_THEME.theme" \
        "$THEMES_DIR/generated/$CURRENT_THEME.theme" \
        "$THEMES_DIR/theme-defaults.sh" \
        "$DOTFILES_ROOT/scripts/fzf-theme.sh" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/local"; do
        [[ -f "$_fzf_input" ]] || continue
        if [[ ! "$_FZF_THEME_CACHE_FILE" -nt "$_fzf_input" ]]; then
            _fzf_cache_stale=1
            break
        fi
    done
    unset _fzf_input
    if [[ $_fzf_cache_stale -eq 0 ]]; then
        unset _fzf_cache_stale
        # shellcheck disable=SC1090
        source "$_FZF_THEME_CACHE_FILE"
        unset _FZF_THEME_CACHE_DIR _FZF_THEME_CACHE_FILE
        # shellcheck disable=SC2317  # `exit 0` runs when script is executed, not sourced
        return 0 2>/dev/null || exit 0
    fi
    unset _fzf_cache_stale
fi
# ─── End cache fast-path ────────────────────────────────────────────

# theme file: hand-crafted, then generated, then dracula
THEME_FILE="$THEMES_DIR/$CURRENT_THEME.theme"
if [[ -f "$THEME_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$THEME_FILE"
elif [[ -f "$THEMES_DIR/generated/$CURRENT_THEME.theme" ]]; then
    # shellcheck disable=SC1090
    source "$THEMES_DIR/generated/$CURRENT_THEME.theme"
elif [[ -f "$THEMES_DIR/dracula.theme" ]]; then
    # shellcheck disable=SC1091
    source "$THEMES_DIR/dracula.theme"
else
    # last resort: minimal defaults
    FZF_BG="#1e1e1e"
    FZF_FG="#d4d4d4"
    FZF_BG_PLUS="#2e2e2e"
    FZF_FG_PLUS="#ffffff"
    FZF_HL="#569cd6"
    FZF_HL_PLUS="#4fc1ff"
    FZF_BORDER="#3e3e3e"
    FZF_PROMPT="#ce9178"
    FZF_POINTER="#4ec9b0"
    FZF_MARKER="#c586c0"
fi

# derives the fzf colours from the base theme
# shellcheck disable=SC1091
source "$THEMES_DIR/theme-defaults.sh"
apply_theme_defaults

# transparent backgrounds when ghostty background-opacity < 1
_ghostty_opacity=""
for _ghostty_file in "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/local"; do
    [[ -r "$_ghostty_file" ]] || continue
    while IFS= read -r _ghostty_line; do
        _ghostty_line="${_ghostty_line#"${_ghostty_line%%[![:space:]]*}"}"
        case "$_ghostty_line" in
            \#* | '') ;;
            background-opacity*=*)
                _ghostty_opacity="${_ghostty_line#*=}"
                _ghostty_opacity="${_ghostty_opacity#"${_ghostty_opacity%%[![:space:]]*}"}"
                ;;
        esac
    done <"$_ghostty_file"
done
if [[ "${_ghostty_opacity:-1}" == 0.* ]]; then
    FZF_BG="-1"
    FZF_PREVIEW_BG="-1"
fi
unset _ghostty_file _ghostty_line _ghostty_opacity

# ${VAR:-default} covers themes that don't define every var
export FZF_DEFAULT_OPTS="--color=bg:${FZF_BG:-#1e1e1e},fg:${FZF_FG:-#d4d4d4},bg+:${FZF_BG_PLUS:-#2e2e2e},fg+:${FZF_FG_PLUS:-#ffffff},hl:${FZF_HL:-#569cd6},hl+:${FZF_HL_PLUS:-#4fc1ff},border:${FZF_BORDER:-#3e3e3e},prompt:${FZF_PROMPT:-#ce9178},pointer:${FZF_POINTER:-#4ec9b0},marker:${FZF_MARKER:-#c586c0},spinner:${FZF_SPINNER:-#4ec9b0},header:${FZF_HEADER:-#569cd6},info:${FZF_INFO:-#d4d4d4},separator:${FZF_SEPARATOR:-#3e3e3e},scrollbar:${FZF_SCROLLBAR:-#569cd6},label:${FZF_LABEL:-#ffffff},preview-bg:${FZF_PREVIEW_BG:-#1e1e1e},preview-fg:${FZF_PREVIEW_FG:-#d4d4d4} --bind=ctrl-d:half-page-down,ctrl-u:half-page-up,ctrl-l:clear-query,ctrl-j:down,ctrl-k:up"

# individual colours for scripts that need direct access
export FZF_THEME_BG="$FZF_BG"
export FZF_THEME_FG="$FZF_FG"
export FZF_THEME_BORDER="$FZF_BORDER"
export FZF_THEME_PROMPT="$FZF_PROMPT"
export FZF_THEME_POINTER="$FZF_POINTER"
export FZF_THEME_HEADER="$FZF_HEADER"

# theme-derived vars that tmux scripts read at runtime. exported so child
# processes (popup-spawned scripts) need not re-source the theme
export TMUX_ACCENT_PURPLE="${TMUX_ACCENT_PURPLE:-}"
export TMUX_ACCENT_PINK="${TMUX_ACCENT_PINK:-}"
export TMUX_ACCENT_CYAN="${TMUX_ACCENT_CYAN:-}"
export TMUX_ACCENT_GREEN="${TMUX_ACCENT_GREEN:-}"
export TMUX_ACCENT_YELLOW="${TMUX_ACCENT_YELLOW:-}"
export TMUX_ACCENT_RED="${TMUX_ACCENT_RED:-}"
export NVIM_COLORSCHEME="${NVIM_COLORSCHEME:-}"

# write the cache for the next source: temp file + mv, so a reader never sees
# a partial file. on failure the next call does the full work again
mkdir -p "$_FZF_THEME_CACHE_DIR" 2>/dev/null
_FZF_THEME_TMP="${_FZF_THEME_CACHE_FILE}.$$.tmp"
if {
    printf '# auto-generated by scripts/fzf-theme.sh, do not edit\n'
    printf 'export FZF_DEFAULT_OPTS=%q\n' "$FZF_DEFAULT_OPTS"
    printf 'export FZF_THEME_BG=%q\n' "${FZF_THEME_BG:-}"
    printf 'export FZF_THEME_FG=%q\n' "${FZF_THEME_FG:-}"
    printf 'export FZF_THEME_BORDER=%q\n' "${FZF_THEME_BORDER:-}"
    printf 'export FZF_THEME_PROMPT=%q\n' "${FZF_THEME_PROMPT:-}"
    printf 'export FZF_THEME_POINTER=%q\n' "${FZF_THEME_POINTER:-}"
    printf 'export FZF_THEME_HEADER=%q\n' "${FZF_THEME_HEADER:-}"
    printf 'export TMUX_ACCENT_PURPLE=%q\n' "${TMUX_ACCENT_PURPLE:-}"
    printf 'export TMUX_ACCENT_PINK=%q\n' "${TMUX_ACCENT_PINK:-}"
    printf 'export TMUX_ACCENT_CYAN=%q\n' "${TMUX_ACCENT_CYAN:-}"
    printf 'export TMUX_ACCENT_GREEN=%q\n' "${TMUX_ACCENT_GREEN:-}"
    printf 'export TMUX_ACCENT_YELLOW=%q\n' "${TMUX_ACCENT_YELLOW:-}"
    printf 'export TMUX_ACCENT_RED=%q\n' "${TMUX_ACCENT_RED:-}"
    printf 'export NVIM_COLORSCHEME=%q\n' "${NVIM_COLORSCHEME:-}"
} >"$_FZF_THEME_TMP" 2>/dev/null; then
    mv -f "$_FZF_THEME_TMP" "$_FZF_THEME_CACHE_FILE" 2>/dev/null || rm -f "$_FZF_THEME_TMP" 2>/dev/null
else
    rm -f "$_FZF_THEME_TMP" 2>/dev/null
fi
unset _FZF_THEME_CACHE_DIR _FZF_THEME_CACHE_FILE _FZF_THEME_TMP
