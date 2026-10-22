#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# capture a session's layout
# ══════════════════════════════════════════════════════════════
# reads a tmux session and prints its shape as tab-separated rows, for
# "save session as launcher" (launchers/save.sh). reports only, no decisions:
# the caller chooses how to map this onto a launcher
#
# usage: capture.sh [session]    (default: the current client's session)
#
# output rows (fields are tab-separated, in this order):
#   session   <name>
#   launcher  <@launcher tag, empty if untagged>
#   dir       <most common pane cwd; ties go to the earliest pane>
#   window    <index> <name> <pane count> <layout>
#   pane      <window index> <pane index> <left> <top> <cwd> <command> <note>
#
# <command> is the pane's foreground job with its arguments, empty when the
# pane sits at a shell prompt. <note> is empty, or a short reason the command
# may not replay well from a launcher

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

# tabs and newlines would break the row format
clean_field() {
    local s="$1"
    s="${s//$'\t'/ }"
    printf '%s' "${s//$'\n'/ }"
}

# an idle prompt: a bare (or login, "-zsh") shell. a shell with arguments, like
# `bash -c '...'` or `zsh script.zsh`, is a command
is_shell() {
    local cmd="$1"
    [[ "$cmd" == *" "* ]] && return 1
    cmd="${cmd#-}"
    case "${cmd##*/}" in
        zsh | bash | sh | dash | fish | nu | ksh | tcsh) return 0 ;;
    esac
    return 1
}

# foreground job on a pane's tty. the job is the process group that owns the
# terminal (tpgid); its stages are the members whose parent is outside the
# group (forked by the shell), so the children of `npm run dev` are left out
# while each stage of `a | b` is kept. ps args lose the original quoting
foreground_command() {
    local tty="${1#/dev/}"
    ps -t "$tty" -o pid=,ppid=,pgid=,tpgid=,args= 2>/dev/null | awk '
        $3 == $4 { pid[NR] = $1; ppid[NR] = $2; in_group[$1] = 1
                   $1 = $2 = $3 = $4 = ""; sub(/^ +/, ""); args[NR] = $0 }
        END {
            out = ""
            for (i = 1; i <= NR; i++) {
                if (!(i in pid) || (ppid[i] in in_group)) continue
                out = out (out == "" ? "" : " | ") args[i]
            }
            print out
        }'
}

replay_note() {
    local cmd="$1"
    local prog="${cmd%% *}"
    prog="${prog##*/}"
    case "$prog" in
        ssh | mosh | et) printf 'remote session' ;;
        less | more | man | most) printf 'pager' ;;
        sudo | doas) printf 'needs a password' ;;
        claude | codex | opencode | copilot)
            if [[ " $cmd " =~ \ (--resume|-r|--session|-s)[\ =] ]]; then
                printf 'resumes a specific session'
            fi
            ;;
    esac
}

main() {
    local session="${1:-}" windows panes dir cmd note
    local w_index w_name w_panes w_layout p_window p_index p_left p_top p_cwd p_tty
    if [[ -z "$session" ]]; then
        session=$(tmux display-message -p '#{client_session}' 2>/dev/null || true)
    fi
    if [[ -z "$session" ]] || ! tmux has-session -t "=$session" 2>/dev/null; then
        echo "capture.sh: no such session: ${session:-<none>}" >&2
        exit 1
    fi

    printf 'session\t%s\n' "$session"
    printf 'launcher\t%s\n' "$(tmux show-options -qv -t "=$session:" @launcher 2>/dev/null || true)"

    windows=$(tmux list-windows -t "=$session" -F '#{window_index}	#{window_name}	#{window_panes}	#{window_layout}')
    panes=$(tmux list-panes -s -t "=$session" -F '#{window_index}	#{pane_index}	#{pane_left}	#{pane_top}	#{pane_current_path}	#{pane_tty}')

    # most common cwd, ties to the earliest pane (list-panes -s is in window,pane order)
    dir=$(printf '%s\n' "$panes" | awk -F'\t' '
        { if (!($5 in count)) order[++n] = $5; count[$5]++ }
        END { best = order[1]; for (i = 2; i <= n; i++) if (count[order[i]] > count[best]) best = order[i]; print best }')
    printf 'dir\t%s\n' "$dir"

    while IFS=$'\t' read -r w_index w_name w_panes w_layout; do
        printf 'window\t%s\t%s\t%s\t%s\n' "$w_index" "$(clean_field "$w_name")" "$w_panes" "$w_layout"
    done <<<"$windows"

    while IFS=$'\t' read -r p_window p_index p_left p_top p_cwd p_tty; do
        cmd=$(foreground_command "$p_tty")
        if is_shell "$cmd"; then
            cmd=""
        fi
        cmd=$(clean_field "$cmd")
        note=""
        [[ -n "$cmd" ]] && note=$(replay_note "$cmd")
        printf 'pane\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$p_window" "$p_index" "$p_left" "$p_top" "$(clean_field "$p_cwd")" "$cmd" "$note"
    done <<<"$panes"
}

# run only when executed, so tests can source the helpers above
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
