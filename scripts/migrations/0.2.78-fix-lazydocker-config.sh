#!/usr/bin/env bash
set -euo pipefail

# Fix lazydocker config YAML structure:
# - returnImmediately was incorrectly nested under gui.theme (should be gui)
# - logs.timestamps was nested under gui.theme (should be top-level logs)
# - timestamp key was misspelled (should be timestamps)

if [[ "$(uname)" == "Darwin" ]]; then
    conf="$HOME/Library/Application Support/lazydocker/config.yml"
else
    conf="$HOME/.config/lazydocker/config.yml"
fi

if [[ ! -f "$conf" ]]; then
    echo "    No lazydocker config found — nothing to migrate"
    exit 0
fi

# Only patch if the file still has the broken nesting
if grep -q '^ *returnImmediately:' "$conf" && grep -B5 'returnImmediately' "$conf" | grep -q 'theme:'; then
    echo "    Fixing YAML structure in lazydocker config..."
    DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    cp "$DOTFILES_DIR/lazydocker/config.yml" "$conf"
    echo "    Config replaced with corrected version"
else
    echo "    Config structure looks correct — nothing to change"
fi
