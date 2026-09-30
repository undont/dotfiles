#!/usr/bin/env bash
set -euo pipefail

# sets the default shell to zsh

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

ZSH_PATH="$(command -v zsh 2>/dev/null || true)"

if [[ -z "$ZSH_PATH" ]]; then
    warn "zsh not found in PATH. Install zsh first."
    exit 0
fi

if [[ "$SHELL" == *zsh ]]; then
    echo "Default shell is already zsh."
    exit 0
fi

echo "Changing default shell to zsh ($ZSH_PATH)..."

# chsh requires zsh to be listed in /etc/shells. sudo's password prompt goes
# to stderr, so stderr stays unredirected
if [[ -f /etc/shells ]] && ! grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "Adding $ZSH_PATH to /etc/shells (may require sudo password)..."
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null ||
        warn "Could not add zsh to /etc/shells"
fi

# chsh prompts for the login password on stderr, so stderr stays unredirected
info "chsh may prompt for your login password..."
if chsh -s "$ZSH_PATH"; then
    success "Default shell changed to zsh"
else
    warn "Could not change default shell automatically."
    echo "Run manually: chsh -s $ZSH_PATH"
fi
