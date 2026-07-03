#!/usr/bin/env bash
# shellcheck disable=SC1091
# Slice framework: install individual components ("slices") on top of a preset.
#
# A slice is a standalone, idempotent script under scripts/install/slices/<name>.sh
# that owns one component: which Homebrew packages it needs (read from the
# Brewfile via a "@slice: <name>" tag, so package lists are never duplicated),
# plus its config/symlink and post-install steps.
#
# Each slice sources this file, sets a few SLICE_* vars, optionally overrides
# slice_link / slice_postinstall / slice_packages, then calls slice_main "$@".
# The installer composes slices; a slice can also be run directly, e.g.
#   scripts/install/slices/nvim.sh          # packages + link + postinstall
#   scripts/install/slices/nvim.sh link     # just the config symlinks
#
# source this file: source "${BASH_SOURCE%/*}/slices.sh"
# Requires common.sh (colours + success/info/warn/error) sourced first, and
# DOTFILES_DIR set. Slices that link config also source symlink.sh.

# guard against multiple sourcing
[[ -n "${_DOTFILES_SLICES_SH_LOADED:-}" ]] && return 0
_DOTFILES_SLICES_SH_LOADED=1

: "${DOTFILES_DIR:?DOTFILES_DIR must be set before sourcing slices.sh}"
SLICES_DIR="$DOTFILES_DIR/scripts/install/slices"

# slice contract vars: each slice script sets these before calling slice_main.
# declared empty here so the helpers below can reference them safely when this
# lib is sourced outside a slice (e.g. by install.sh for discovery only).
SLICE_NAME="${SLICE_NAME:-}"
SLICE_DESC="${SLICE_DESC:-}"
SLICE_PRESET="${SLICE_PRESET:-}"
SLICE_REQUIRES="${SLICE_REQUIRES:-}"

# ── Discovery ──────────────────────────────────────────────────────────

# list available slice names (one per line, sorted)
slice_list() {
    local f name
    for f in "$SLICES_DIR"/*.sh; do
        [[ -e "$f" ]] || continue
        name="$(basename "$f" .sh)"
        printf '%s\n' "$name"
    done
}

# true if a slice with this name exists
slice_exists() {
    [[ -f "$SLICES_DIR/$1.sh" ]]
}

# absolute path to a slice script
slice_path() {
    printf '%s\n' "$SLICES_DIR/$1.sh"
}

# run a slice script with a subcommand (meta/packages/link/postinstall/all).
# runs as a subprocess; DOTFILES_DIR is inherited and rollback records flow
# through the shared .install-state log
slice_run() {
    local name="$1"; shift
    local path="$SLICES_DIR/$name.sh"
    if [[ ! -f "$path" ]]; then
        error "Unknown slice: $name"
        return 1
    fi
    bash "$path" "$@"
}

# ── Metadata ───────────────────────────────────────────────────────────

# meta fields are tab-separated: 1=name 2=desc 3=preset 4=requires
slice_meta_field() {
    slice_run "$1" meta 2>/dev/null | cut -f"$2"
}
slice_desc()     { slice_meta_field "$1" 2; }
slice_preset()   { slice_meta_field "$1" 3; }
slice_requires() { slice_meta_field "$1" 4; }

# print "name  description" for every available slice (for --list-slices)
slice_list_verbose() {
    local name desc preset
    while read -r name; do
        desc="$(slice_desc "$name")"
        preset="$(slice_preset "$name")"
        printf '  %-14s %s%s\n' "$name" "$desc" \
            "${preset:+ (in $preset+)}"
    done < <(slice_list)
}

# ── Dependency resolution ──────────────────────────────────────────────

# expand requested slices with their transitive SLICE_REQUIRES, dependency
# first and deduped, so e.g. "nvim" pulls in "nerd-fonts" ahead of itself.
_SLICE_RESOLVE_SEEN=""
_SLICE_RESOLVE_OUT=""
_slice_visit() {
    local n="$1" reqs r
    local -a req_arr
    case " $_SLICE_RESOLVE_SEEN " in *" $n "*) return 0 ;; esac
    _SLICE_RESOLVE_SEEN+=" $n"
    reqs="$(slice_requires "$n" 2>/dev/null || true)"
    read -ra req_arr <<< "$reqs"
    for r in "${req_arr[@]}"; do
        [[ -n "$r" ]] || continue
        slice_exists "$r" && _slice_visit "$r"
    done
    _SLICE_RESOLVE_OUT+=" $n"
}
slice_resolve() {
    _SLICE_RESOLVE_SEEN=""
    _SLICE_RESOLVE_OUT=""
    local s n
    local -a out_arr
    for s in "$@"; do
        if ! slice_exists "$s"; then
            error "Unknown slice: $s"
            return 1
        fi
        _slice_visit "$s"
    done
    read -ra out_arr <<< "$_SLICE_RESOLVE_OUT"
    for n in "${out_arr[@]}"; do
        printf '%s\n' "$n"
    done
}

# ── Brewfile packages ──────────────────────────────────────────────────

# print the brew/cask lines tagged for a slice via "@slice: <name>" in the
# Brewfile. platform-aware: casks and "# macOS-only" formulae are dropped on
# Linux, mirroring filter_brewfile. a line may list several slices, e.g.
# "@slice: nvim, search".
slice_brewfile_packages() {
    local name="$1"
    local brewfile="${2:-$DOTFILES_DIR/Brewfile}"
    local is_darwin="true"
    [[ "$(uname)" != "Darwin" ]] && is_darwin="false"

    awk -v want="$name" -v darwin="$is_darwin" '
    # only real package lines carry usable tags (skip commented docs/headers)
    $0 !~ /^(brew|cask) / { next }
    darwin != "true" && /^cask / { next }
    darwin != "true" && /# macOS-only/ { next }
    {
        idx = index($0, "@slice:")
        if (idx == 0) next
        rest = substr($0, idx + 7)
        n = split(rest, toks, /[^A-Za-z0-9_-]+/)
        for (i = 1; i <= n; i++) {
            if (toks[i] == want) { print; next }
        }
    }
    ' "$brewfile"
}

# ── Slice hooks (defaults; slices override as needed) ──────────────────

# default: packages come from the Brewfile @slice tag
slice_packages()    { slice_brewfile_packages "${SLICE_NAME:-}"; }
# default no-ops for slices that only ship packages
slice_link()        { :; }
slice_postinstall() { :; }

# install this slice's Brewfile packages via a one-off `brew bundle`
_slice_install_packages() {
    local pkgs
    pkgs="$(slice_packages)"

    # nothing to install (e.g. a cask-only slice on Linux)
    if [[ -z "${pkgs//[[:space:]]/}" ]]; then
        return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew not found; skipping packages for slice '${SLICE_NAME}'"
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    # slices declared so far use core/cask formulae only (no third-party taps);
    # if a future slice needs a tap, add it and its trust handling here
    printf '%s\n' "$pkgs" > "$tmp"

    if brew bundle check --file="$tmp" --quiet >/dev/null 2>&1; then
        success "Slice '${SLICE_NAME}' packages already installed"
    else
        echo "Installing packages for slice '${SLICE_NAME}'..."
        brew bundle install --upgrade --file="$tmp" \
            || warn "Some packages for slice '${SLICE_NAME}' may have failed to install"
    fi
    rm -f "$tmp"
}

# ── Slice dispatcher (called at the end of each slice script) ──────────

slice_main() {
    local cmd="${1:-all}"
    case "$cmd" in
        meta)
            printf '%s\t%s\t%s\t%s\n' \
                "${SLICE_NAME:-}" "${SLICE_DESC:-}" "${SLICE_PRESET:-}" "${SLICE_REQUIRES:-}"
            ;;
        packages)          slice_packages ;;
        install-packages)  _slice_install_packages ;;
        link)              slice_link ;;
        postinstall)       slice_postinstall ;;
        all)
            print_section "Slice: ${SLICE_NAME}${SLICE_DESC:+ — $SLICE_DESC}"
            _slice_install_packages
            slice_link
            slice_postinstall
            ;;
        *)
            error "Unknown slice command: $cmd"
            echo "Valid commands: meta, packages, install-packages, link, postinstall, all" >&2
            return 1
            ;;
    esac
}
