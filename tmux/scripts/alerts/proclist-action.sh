#!/usr/bin/env bash
# proclist x-binding dispatcher: stop a running process or dismiss a finished one.
#   run  <pane target> <pane_id>     -> interrupt the pane's foreground command
#   done <window_id>   <epoch> <wid> -> drop the entry from finished history
# called from the prefix+P fzf binding with the row's hidden fields.
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/alerts.sh"

TYPE="${1:-}"
TARGET="${2:-}"
A="${3:-}"
B="${4:-}"

case "$TYPE" in
    run)
        # interrupt the pane's foreground command; the shell's precmd then
        # clears the registry. remove the file too so the list updates at once
        [[ -n "$TARGET" ]] && tmux send-keys -t "$TARGET" C-c 2>/dev/null || true
        [[ -n "$A" ]] && rm -f "$RUNNING_DIR/${A#%}" 2>/dev/null || true
        ;;
    done)
        # A=finish epoch, B=window_id: drop that one entry from the history file
        row_sess=""; row_wname=""
        if [[ -n "$A" && -f "$FINISHED_FILE" ]]; then
            # capture the row's stored session + window name (fields 3 and 5)
            # before deleting it; the alerts file keys its exit line on that
            # name, which the live window may have since renamed away from
            IFS=$'\t' read -r row_sess row_wname < <(awk -F'\t' \
                -v e="$A" -v w="$B" '$1==e && $4==w {print $3"\t"$5; exit}' \
                "$FINISHED_FILE")
            tmpf=$(mktemp "${FINISHED_FILE}.XXXXXX") || exit 0
            if awk -F'\t' -v e="$A" -v w="$B" '!($1 == e && $4 == w)' \
                "$FINISHED_FILE" > "$tmpf" 2>/dev/null; then
                mv "$tmpf" "$FINISHED_FILE" 2>/dev/null || rm -f "$tmpf"
            else
                rm -f "$tmpf"
            fi
        fi
        # clear the window's exit indicator (status-right + window-status) on the
        # same keystroke. the indicator is one-per-window, decoupled from how many
        # finished rows the window has, so gating on a remaining-rows count
        # stranded it whenever the other rows aged out via GC instead of being
        # dismissed here. dismiss it outright
        [[ -n "$B" ]] && clear_window_exit_alert "$B" "$row_sess" "$row_wname"
        ;;
esac
