#!/bin/bash
# Migration: Remove cronboard and posting
# these were added in 0.2.58 but are being dropped: cronboard is a brew
# formula and posting was installed via pipx

set -euo pipefail

if command -v cronboard &>/dev/null; then
    echo "    Uninstalling cronboard..."
    brew uninstall cronboard 2>/dev/null || echo "    cronboard uninstall failed (remove manually: brew uninstall cronboard)"
else
    echo "    cronboard not installed, skipping"
fi

if command -v posting &>/dev/null; then
    echo "    Uninstalling posting..."
    pipx uninstall posting 2>/dev/null || echo "    posting uninstall failed (remove manually: pipx uninstall posting)"
else
    echo "    posting not installed, skipping"
fi
