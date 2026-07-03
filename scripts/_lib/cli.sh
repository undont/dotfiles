#!/usr/bin/env bash
# CLI helpers shared by the dotfiles dispatcher and any future tools that
# need to read the changelog or preset state.
# source this file: source "${BASH_SOURCE%/*}/cli.sh"
# requires common.sh sourced first (for colour vars + error/warn)

[[ -n "${_DOTFILES_CLI_SH_LOADED:-}" ]] && return 0
_DOTFILES_CLI_SH_LOADED=1

# fail fast if common.sh has not been sourced; we rely on its colour vars
# and error/warn helpers
[[ -z "${_DOTFILES_COMMON_SH_LOADED:-}" ]] && {
    echo "cli.sh requires common.sh to be sourced first" >&2
    return 1
}

# DOTFILES_DIR must be set by the caller; CONFIG_DIR derives from XDG
: "${DOTFILES_DIR:?DOTFILES_DIR must be set before sourcing cli.sh}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
PRESET_FILE="$CONFIG_DIR/preset"
SLICES_FILE="$CONFIG_DIR/slices"
STATE_DIR="$CONFIG_DIR/.state"

# ── Preset / branch ────────────────────────────────────────────────────

# get the saved preset, default to "full"
get_preset() {
    if [[ -f "$PRESET_FILE" ]]; then
        cat "$PRESET_FILE"
    else
        echo "full"
    fi
}

# get the saved add-on slices (one per line), empty if none. these are extra
# components installed on top of the preset (e.g. `install.sh --minimal nvim`);
# `dotfiles update` replays them so they stay current.
get_slices() {
    [[ -f "$SLICES_FILE" ]] || return 0
    grep -v '^[[:space:]]*$' "$SLICES_FILE" 2>/dev/null || true
}

# true if a slice name is in the saved set
slice_is_saved() {
    [[ -f "$SLICES_FILE" ]] && grep -qxF "$1" "$SLICES_FILE"
}

# add slice names to the saved set (union, deduped, sorted)
slices_add_saved() {
    mkdir -p "$(dirname "$SLICES_FILE")"
    {
        [[ -f "$SLICES_FILE" ]] && cat "$SLICES_FILE"
        printf '%s\n' "$@"
    } | grep -v '^[[:space:]]*$' | sort -u > "$SLICES_FILE.tmp"
    mv "$SLICES_FILE.tmp" "$SLICES_FILE"
}

# remove slice names from the saved set; deletes the file when it empties out
slices_remove_saved() {
    [[ -f "$SLICES_FILE" ]] || return 0
    local tmp name
    tmp="$(mktemp)"
    cp "$SLICES_FILE" "$tmp"
    for name in "$@"; do
        grep -vxF "$name" "$tmp" > "$tmp.next" || true
        mv "$tmp.next" "$tmp"
    done
    if [[ -s "$tmp" ]]; then
        mv "$tmp" "$SLICES_FILE"
    else
        rm -f "$tmp" "$SLICES_FILE"
    fi
}

# get the default remote branch (origin/HEAD, with main/master fallback)
get_remote_branch() {
    local ref
    if ref=$(git -C "$DOTFILES_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null); then
        echo "${ref#refs/remotes/}"
        return
    fi
    if git -C "$DOTFILES_DIR" rev-parse --verify origin/main &>/dev/null; then
        echo "origin/main"
    elif git -C "$DOTFILES_DIR" rev-parse --verify origin/master &>/dev/null; then
        echo "origin/master"
    else
        echo "origin/main"
    fi
}

# ── Changelog ──────────────────────────────────────────────────────────

# latest non-Unreleased version from CHANGELOG.md
_changelog_local_version() {
    sed -n 's/^## \[\([0-9][^]]*\)\].*/\1/p' "$DOTFILES_DIR/CHANGELOG.md" | head -1
}

# release date (YYYY-MM-DD) for the latest non-Unreleased version. reads the
# "## [X.Y.Z] - YYYY-MM-DD" heading; empty if the heading carries no date
_changelog_local_date() {
    sed -n 's/^## \[[0-9][^]]*\][[:space:]]*-[[:space:]]*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p' \
        "$DOTFILES_DIR/CHANGELOG.md" | head -1
}

# release timestamp for a version. when the matching "vX.Y.Z" tag exists, use
# its commit time (YYYY-MM-DD HH:MM). untagged (-dev) versions have no tag, so
# fall back to the date-only CHANGELOG heading
_release_datetime() {
    local version="$1"
    [[ -z "$version" ]] && return
    local tag="v${version}"
    if git -C "$DOTFILES_DIR" rev-parse "$tag" &>/dev/null; then
        git -C "$DOTFILES_DIR" log -1 --date=format:'%Y-%m-%d %H:%M' --format=%cd "$tag" 2>/dev/null
    else
        _changelog_local_date
    fi
}

# path to the last-update marker. install.sh writes a pre-formatted local
# timestamp here at the end of every install/update apply (see UPDATE_STAMP_FILE
# below); cmd_update reaches install.sh only when changes are actually applied
UPDATE_STAMP_FILE="$STATE_DIR/last-update"

# timestamp (YYYY-MM-DD HH:MM) of the last successful install/update. empty if
# install.sh has never completed on this machine
_last_update_datetime() {
    [[ -f "$UPDATE_STAMP_FILE" ]] && head -1 "$UPDATE_STAMP_FILE"
}

# latest non-Unreleased version from CHANGELOG.md at a given git ref
_changelog_version_at_ref() {
    local ref="$1"
    git -C "$DOTFILES_DIR" show "$ref:CHANGELOG.md" 2>/dev/null \
        | sed -n 's/^## \[\([0-9][^]]*\)\].*/\1/p' | head -1
}

# append "-dev" to a version if the matching git tag doesn't exist yet
_format_version() {
    local version="$1"
    [[ -z "$version" ]] && return
    if git -C "$DOTFILES_DIR" rev-parse "v${version}" &>/dev/null; then
        printf '%s' "$version"
    else
        printf '%s-dev' "$version"
    fi
}

# show changelog entries from $remote_branch newer than the local version
_changelog_incoming() {
    local remote_branch="$1"
    local local_version
    local_version=$(_changelog_local_version) || return 1
    [[ -z "$local_version" ]] && return 1

    local remote_changelog
    remote_changelog=$(git -C "$DOTFILES_DIR" show "$remote_branch:CHANGELOG.md" 2>/dev/null) || return 1

    printf '%s\n' "$remote_changelog" | awk -v ver="$local_version" '
        /^## \[Unreleased\]/ { next }
        /^## \[/ {
            if (index($0, "[" ver "]")) exit
            found = 1
        }
        found { print }
    '
}

# colourise changelog markdown for terminal display
_changelog_colorise() {
    local cyan=$'\033[0;36m' green=$'\033[0;32m' magenta=$'\033[0;35m' bold_magenta=$'\033[1;35m'
    local yellow=$'\033[0;33m' red=$'\033[0;31m' grey=$'\033[0;90m' nc=$'\033[0m'
    sed \
        -e "s|^\(## \[.*\]\) ★ current\(.*\)|${magenta}\1 ${bold_magenta}★ current${magenta}\2${nc}|" \
        -e "s|^## \[.*|${cyan}&${nc}|" \
        -e "s|^### Added.*|${green}&${nc}|" \
        -e "s|^### Changed.*|${yellow}&${nc}|" \
        -e "s|^### Fixed.*|${yellow}&${nc}|" \
        -e "s|^### Removed.*|${red}&${nc}|" \
        -e "s|^- |  ${grey}•${nc} |"
}

# compare semantic versions: returns 0 if $1 > $2
_version_gt() {
    [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -1)" == "$2" ]]
}
