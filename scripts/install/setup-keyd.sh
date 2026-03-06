#!/usr/bin/env bash
set -euo pipefail

# Setup keyd (Linux keyboard remapping daemon) - equivalent of Karabiner on macOS
# Installs keyd, deploys config, and enables the systemd service.

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
KEYD_CONF="$DOTFILES_DIR/keyd/default.conf"

if is_macos; then
    info "keyd is Linux-only — use Karabiner Elements on macOS"
    exit 0
fi

if [[ ! -f "$KEYD_CONF" ]]; then
    error "keyd config not found at $KEYD_CONF"
    exit 1
fi

# Install keyd if not present
if ! command_exists keyd; then
    echo "Installing keyd..."
    install_system_package "keyd" "fatal"
fi

# Deploy config
echo "Deploying keyd config..."
sudo mkdir -p /etc/keyd
if sudo cp "$KEYD_CONF" /etc/keyd/default.conf; then
    success "Deployed keyd config to /etc/keyd/default.conf"
else
    error "Failed to deploy keyd config"
    exit 1
fi

# Enable and start service
echo "Enabling keyd service..."
if sudo systemctl enable --now keyd 2>/dev/null; then
    success "keyd service enabled and started"
elif sudo systemctl restart keyd 2>/dev/null; then
    success "keyd service restarted"
else
    warn "Could not start keyd service — you may need to reboot"
fi

# Reload config in case service was already running
sudo keyd reload 2>/dev/null || true

success "keyd setup complete"
echo "  Caps Lock -> Escape (global)"
echo "  Right Alt -> Control (global)"
echo "  Grave/Tilde <-> Non-US Backslash (Apple keyboard only)"
