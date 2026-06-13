#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Ghostty config reload helper
# ══════════════════════════════════════════════════════════════
# reloads Ghostty config by sending SIGUSR2 signal

# find Ghostty main process (the .app binary, not child shells)
# use ps instead of pgrep to reliably find the process across platforms
# the || true prevents pipefail from failing when grep finds no matches
# shellcheck disable=SC2009  # ps | grep intentional: pgrep misses .app path on macOS
ghostty_pid=$(ps -eo pid,comm | grep -E '/ghostty$' | awk '{print $1}' | head -1 || true)

if [[ -z "$ghostty_pid" ]]; then
    exit 0
fi

# send SIGUSR2 to trigger config reload
kill -USR2 "$ghostty_pid" 2>/dev/null || true
