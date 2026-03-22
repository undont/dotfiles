#!/usr/bin/env bash
set -euo pipefail

# Remove openapi-tui binary (was installed to ~/.cargo/bin by install-packages.sh)

OPENAPI_TUI="$HOME/.cargo/bin/openapi-tui"

if [[ -f "$OPENAPI_TUI" ]]; then
    echo "    Removing openapi-tui from $OPENAPI_TUI..."
    rm -f "$OPENAPI_TUI"
    echo "    openapi-tui removed"
else
    echo "    openapi-tui not found — nothing to remove"
fi
