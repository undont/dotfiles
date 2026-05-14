#!/usr/bin/env bash
set -euo pipefail

# Uninstall postgresql@14 — the Brewfile pinned `postgresql@17` long ago,
# but `brew bundle install` only adds packages, so users who installed
# the original Brewfile still have postgresql@14 sitting around (and
# possibly running as a service). Data directories are left untouched
# in case the user wants to migrate them by hand.

if ! command -v brew >/dev/null 2>&1; then
    echo "    brew not found — skipping postgresql@14 uninstall"
    exit 0
fi

if ! brew list --formula --versions postgresql@14 >/dev/null 2>&1; then
    echo "    postgresql@14 not installed — nothing to remove"
    exit 0
fi

if brew services list 2>/dev/null | awk '$1 == "postgresql@14" {print $2}' | grep -qE '^(started|scheduled)$'; then
    echo "    Stopping postgresql@14 service..."
    brew services stop postgresql@14 >/dev/null
fi

echo "    Uninstalling postgresql@14..."
brew uninstall --formula postgresql@14
echo "    postgresql@14 removed (data directories left intact)"
