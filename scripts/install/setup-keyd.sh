#!/usr/bin/env bash
set -euo pipefail

# setup keyd (Linux keyboard remapping daemon), equivalent of Karabiner on macOS
# installs keyd, deploys config, and enables the systemd service

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)}"
KEYD_CONF="$DOTFILES_DIR/keyd/default.conf"

if is_macos; then
    info "keyd is Linux-only — use Karabiner Elements on macOS"
    exit 0
fi

if [[ ! -f "$KEYD_CONF" ]]; then
    error "keyd config not found at $KEYD_CONF"
    exit 1
fi

# resolve the keyd binary: Debian/Raspberry Pi OS ship it as keyd.rvaiya
# (renamed to avoid a namespace clash), other distros use plain keyd.
keyd_bin() {
    if command_exists keyd; then
        echo keyd
    elif command_exists keyd.rvaiya; then
        echo keyd.rvaiya
    fi
}

# install keyd if not present
if [[ -z "$(keyd_bin)" ]]; then
    echo "Installing keyd..."
    install_system_package "keyd" "fatal"
fi

# deploy config
echo "Deploying keyd config..."
sudo mkdir -p /etc/keyd
if sudo cp "$KEYD_CONF" /etc/keyd/default.conf; then
    success "Deployed keyd config to /etc/keyd/default.conf"
else
    error "Failed to deploy keyd config"
    exit 1
fi

# enable and start service
echo "Enabling keyd service..."
if sudo systemctl enable --now keyd 2>/dev/null; then
    success "keyd service enabled and started"
elif sudo systemctl restart keyd 2>/dev/null; then
    success "keyd service restarted"
else
    warn "Could not start keyd service — you may need to reboot"
fi

# reload config in case service was already running
KEYD_BIN="$(keyd_bin)"
[[ -n "$KEYD_BIN" ]] && sudo "$KEYD_BIN" reload 2>/dev/null || true

success "keyd setup complete"
echo "  Caps Lock -> Escape (global)"
echo "  Right Alt -> Control (global)"
echo "  Grave/Tilde <-> Non-US Backslash (global)"
