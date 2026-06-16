#!/usr/bin/env bash
# clean up stale alerts (sessions/windows that no longer exist)
# called by session-closed and session-renamed hooks
# always exits 0; best-effort cleanup should never cause hook errors

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/alerts.sh"

cleanup_stale_alerts || true
