#!/usr/bin/env bash
set -euo pipefail

# Set default shell to zsh

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

# Ensure zsh is in /etc/shells (required by chsh on most systems)
if [[ -f /etc/shells ]] && ! grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "Adding $ZSH_PATH to /etc/shells (may require sudo)..."
    sudo bash -c "grep -qxF '$ZSH_PATH' /etc/shells || echo '$ZSH_PATH' >> /etc/shells" 2>/dev/null \
        || warn "Could not add zsh to /etc/shells"
fi

if chsh -s "$ZSH_PATH" 2>/dev/null; then
    success "Default shell changed to zsh"
else
    warn "Could not change default shell automatically."
    echo "Run manually: chsh -s $ZSH_PATH"
fi
