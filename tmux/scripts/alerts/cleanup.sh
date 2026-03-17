#!/usr/bin/env bash
# Clean up stale alerts (sessions/windows that no longer exist)
# Called by session-closed and session-renamed hooks
# Always exits 0 — best-effort cleanup should never cause hook errors.

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/alerts.sh"

cleanup_stale_alerts || true
