#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# ghostty config reload helper
# ══════════════════════════════════════════════════════════════
# reloads Ghostty config by sending SIGUSR2 signal

# ghostty main process (the .app binary, not child shells), via ps. || true
# keeps pipefail quiet when grep finds no match
# shellcheck disable=SC2009  # ps | grep intentional: pgrep misses .app path on macOS
ghostty_pid=$(ps -eo pid,comm | grep -E '/ghostty$' | awk '{print $1}' | head -1 || true)

if [[ -z "$ghostty_pid" ]]; then
    exit 0
fi

kill -USR2 "$ghostty_pid" 2>/dev/null || true
