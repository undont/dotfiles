#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Delete Launcher (with confirmation)
# ══════════════════════════════════════════════════════════════
# Deletes a user-created launcher file after showing a
# confirmation dialog. Repo launchers cannot be deleted.
#
# Usage: delete-launcher.sh <launcher_name>

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/_lib/common.sh"
# shellcheck source=tmux/scripts/_lib/ui.sh
source "$SCRIPT_DIR/_lib/ui.sh"

# Load current theme colours for fzf
load_fzf_theme

name="${1:-}"
[[ -n "$name" ]] || exit 0

# Prevent path traversal — strip to basename and reject path separators
name=$(basename "$name")
if [[ "$name" == *"/"* ]] || [[ "$name" == "." ]] || [[ "$name" == ".." ]]; then
    show_error "Invalid launcher name: $name"
    exit 1
fi

# USER_LAUNCHERS and DOTFILES_LAUNCHERS provided by common.sh

# Only user launchers can be deleted
if [[ -f "$USER_LAUNCHERS/$name" ]]; then
    if ! show_visual_confirm "Delete Launcher" "Delete launcher '${name}'?"; then
        exit 0
    fi
    rm "$USER_LAUNCHERS/$name"
elif [[ -f "$DOTFILES_LAUNCHERS/$name" ]]; then
    show_error "Cannot delete repo launcher '$name' — edit it in dotfiles instead"
    exit 1
else
    show_error "Launcher not found: $name"
    exit 1
fi
