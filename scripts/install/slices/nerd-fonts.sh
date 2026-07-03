#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# nerd-fonts slice: terminal icon fonts.
#   macOS: installed as Homebrew casks (via the Brewfile @slice tag)
#   Linux: casks are macOS-only, so packages() is empty and postinstall()
#          fetches the matching release archives via install-fonts.sh

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
export DOTFILES_DIR

source "$DOTFILES_DIR/scripts/_lib/common.sh"
source "$DOTFILES_DIR/scripts/_lib/slices.sh"

SLICE_NAME="nerd-fonts"
SLICE_DESC="Nerd Fonts for terminal icons"
SLICE_PRESET="core"
SLICE_REQUIRES=""

slice_postinstall() {
    # macOS gets the fonts from the Brewfile casks; nothing more to do
    is_macos && return 0

    # Linux: install TTFs from upstream releases (idempotent)
    if [[ -x "$DOTFILES_DIR/scripts/install/install-fonts.sh" ]]; then
        "$DOTFILES_DIR/scripts/install/install-fonts.sh" \
            || warn "Nerd Font install failed — see output above."
    else
        warn "install-fonts.sh not found; cannot install Nerd Fonts on Linux."
    fi
}

slice_main "$@"
