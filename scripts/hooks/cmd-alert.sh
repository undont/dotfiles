#!/usr/bin/env bash
# command exit alert hook: set tmux alert when a monitored command finishes
# usage: cmd-alert.sh <exit_code> <label> [pane_id]
# called by the zsh preexec/precmd hooks in cmd-alert-hook.zsh

EXIT_CODE="${1:-0}"
LABEL="${2:-command}"
PANE_ID="${3:-}"

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALERTS_LIB="$DOTFILES_DIR/tmux/scripts/_lib/alerts.sh"

if [[ -f "$ALERTS_LIB" ]]; then
    # shellcheck source=../../tmux/scripts/_lib/alerts.sh
    source "$ALERTS_LIB"

    # the origin pane, so the alert lands on the window the command ran in
    if [[ -n "$PANE_ID" ]]; then
        export TMUX_PANE="$PANE_ID"
    fi

    set_exit_alert "$EXIT_CODE" "$LABEL" "true"
fi
