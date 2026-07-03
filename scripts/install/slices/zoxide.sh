#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# zoxide slice: smarter `cd`. Package-only — the shell integration
# (`eval "$(zoxide init --cmd cd zsh)"`) already lives in zsh/dotfiles.zsh,
# so there is no config to link.

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
export DOTFILES_DIR

source "$DOTFILES_DIR/scripts/_lib/common.sh"
source "$DOTFILES_DIR/scripts/_lib/slices.sh"

SLICE_NAME="zoxide"
SLICE_DESC="Smarter cd (zoxide)"
SLICE_PRESET="core"
SLICE_REQUIRES=""

# packages come from the Brewfile @slice tag; no link/postinstall needed

slice_main "$@"
