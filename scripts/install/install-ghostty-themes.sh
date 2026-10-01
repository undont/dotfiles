#!/usr/bin/env bash
set -euo pipefail

# installs ghostty's theme catalogue into ~/.local/share/ghostty/themes on
# linux machines without ghostty, from mbadolato/iTerm2-Color-Schemes.
# `dotfiles theme generate <builtin>` reads palettes from those files
# usage: install-ghostty-themes.sh [--force]    --force refetches an existing catalogue

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

SCHEMES_REPO="https://github.com/mbadolato/iTerm2-Color-Schemes"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/ghostty/themes"
FORCE="${1:-}"

if is_macos; then
    info "Ghostty ships its own themes on macOS — skipping."
    exit 0
fi

# a system-wide ghostty install provides the catalogue
for d in /usr/share/ghostty/themes /usr/local/share/ghostty/themes; do
    if [[ -d "$d" ]]; then
        info "Ghostty theme catalogue already present ($d)."
        exit 0
    fi
done

if [[ "$FORCE" != "--force" ]] && compgen -G "$DEST/*" >/dev/null 2>&1; then
    echo "Ghostty theme catalogue already installed at $DEST."
    exit 0
fi

if ! command_exists git; then
    warn "git not found — skipping Ghostty theme catalogue."
    exit 0
fi

echo "Fetching Ghostty theme catalogue (enables 'dotfiles theme generate' without Ghostty)..."
tmp="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" EXIT

# partial + sparse clone: only the ghostty/ directory's blobs
if ! git clone --depth 1 --filter=blob:none --sparse "$SCHEMES_REPO" "$tmp/repo" 2>/dev/null; then
    warn "Failed to clone theme catalogue (network issue?). Skipping."
    exit 0
fi
if ! git -C "$tmp/repo" sparse-checkout set ghostty 2>/dev/null; then
    warn "Failed to sparse-checkout ghostty themes. Skipping."
    exit 0
fi

if [[ ! -d "$tmp/repo/ghostty" ]]; then
    warn "ghostty/ directory not found in theme catalogue. Skipping."
    exit 0
fi

mkdir -p "$DEST"
count=0
for f in "$tmp/repo/ghostty"/*; do
    if [[ -f "$f" ]]; then
        cp "$f" "$DEST/"
        count=$((count + 1))
    fi
done

if [[ "$count" -gt 0 ]]; then
    success "Installed $count Ghostty themes to $DEST"
    echo "  Try: dotfiles theme generate kanagawa-dragon"
else
    warn "No Ghostty theme files found in catalogue."
fi
