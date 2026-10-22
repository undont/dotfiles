#!/usr/bin/env bash
# OpenCode state script: record per-pane agent state for the tmux switcher
# set as OPENCODE_STATE_SCRIPT; opencode-tmux-alert passes the state in env
# vars (OPENCODE_AGENT_STATE, OPENCODE_STATE_EVENT, OPENCODE_SESSION_ID,
# OPENCODE_DIRECTORY) and expects stdin to be left alone

# skip when running as ACP subprocess inside nvim (e.g. codecompanion.nvim)
[[ -n "${NVIM:-}" ]] && exit 0

# without a state agent-state.sh would fall back to reading hook JSON on stdin
[[ -n "${OPENCODE_AGENT_STATE:-}" ]] || exit 0

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
AGENT_STATE="$OPENCODE_AGENT_STATE" \
    AGENT_EVENT="${OPENCODE_STATE_EVENT:-}" \
    AGENT_SESSION_ID="${OPENCODE_SESSION_ID:-}" \
    AGENT_CWD="${OPENCODE_DIRECTORY:-}" \
    exec "$SCRIPT_DIR/agent-state.sh" opencode
