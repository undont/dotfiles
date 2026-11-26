#!/usr/bin/env bash
set -euo pipefail

# rex resumes sessions and programs itself, so rexurrect's config link,
# autosave agent, formula and tap go

LINK="${XDG_CONFIG_HOME:-$HOME/.config}/rexurrect/config.toml"

if [[ -L "$LINK" ]]; then
    rm "$LINK"
    rmdir "$(dirname "$LINK")" 2>/dev/null || true
    echo "    Removed $LINK"
fi

if command -v rexurrect >/dev/null; then
    if ! rexurrect autosave uninstall >/dev/null 2>&1; then
        echo "    rexurrect autosave uninstall failed; leaving rexurrect installed"
        exit 1
    fi
    echo "    Stopped rexurrect autosave"
fi

if command -v brew >/dev/null; then
    if brew list --formula cemcatik/tap/rexurrect >/dev/null 2>&1; then
        brew uninstall cemcatik/tap/rexurrect
        echo "    Uninstalled rexurrect"
    fi
    if brew tap | grep -qx cemcatik/tap; then
        brew untap cemcatik/tap
        echo "    Removed the cemcatik/tap tap"
    fi
fi
