#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# capture a session's layout
# ══════════════════════════════════════════════════════════════
# reads a tmux session and prints its shape as tab-separated rows, for
# "save session as launcher" (launchers/save.sh). reports only, no decisions:
# the caller chooses how to map this onto a launcher
#
# usage: capture.sh [session]    (default: the current session)
#
# output rows (fields are tab-separated, in this order):
#   session   <name>
#   launcher  <@launcher tag, empty if untagged>
#   dir       <most common pane cwd; ties go to the earliest pane>
#   window    <index> <name> <pane count> <automatic-rename: 1 or 0>
#   pane      <window index> <pane index> <left> <top> <width> <height> <cwd> <command> <note>
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

# quote one argument for a shell command line, only when it needs it
shell_quote() {
    local s="$1"
    if [[ -n "$s" && "$s" =~ ^[A-Za-z0-9_@%+=:,./~-]+$ ]]; then
        printf '%s' "$s"
    else
        printf "'%s'" "${s//\'/\'\\\'\'}"
    fi
}

# ps joins argv with spaces, so an argument containing a space arrives as
# several words. rejoin a run of words when the joined text is a path that
# exists (relative paths against the pane's cwd), preferring the longest run.
# words that aren't part of an existing path stay as they are
# usage: rejoin_path_words CWD WORD... (prints one argument per line)
rejoin_path_words() {
    local cwd="$1"
    shift
    local -a words=("$@")
    local i j best candidate path
    for ((i = 0; i < ${#words[@]}; i++)); do
        best=$i
        candidate="${words[$i]}"
        # argv[0] is the program; flags can't start a path
        if ((i > 0)) && [[ "${words[$i]}" != -* ]]; then
            for ((j = i + 1; j < ${#words[@]}; j++)); do
                candidate+=" ${words[$j]}"
                path="${candidate/#\~/$HOME}"
                [[ "$path" == /* ]] || path="$cwd/$path"
                [[ -e "$path" ]] && best=$j
            done
        fi
        candidate="${words[$i]}"
        for ((j = i + 1; j <= best; j++)); do
            candidate+=" ${words[$j]}"
        done
        printf '%s\n' "$candidate"
        i=$best
    done
}

# one argument, quoted, with paths written to replay from another checkout or
# machine: the program by name when that name is on PATH, a path under the
# pane's cwd relative to it, any other path under $HOME as ~/…
# usage: portable_arg POSITION ARG CWD
portable_arg() {
    local i="$1" arg="$2" cwd="$3" rel
    if [[ "$i" -eq 0 && "$arg" == /* ]] && command -v "${arg##*/}" >/dev/null 2>&1; then
        shell_quote "${arg##*/}"
        return
    fi
    if [[ "$arg" == "$cwd" ]]; then
        printf '.'
    elif [[ "$cwd" != / && "$arg" == "$cwd/"* ]]; then
        rel="${arg#"$cwd"/}"
        [[ "$i" -eq 0 ]] && rel="./$rel"
        shell_quote "$rel"
    elif [[ "$arg" == "$HOME/"* ]]; then
        # shellcheck disable=SC2088  # a literal ~, expanded when the launcher replays it
        printf '~/%s' "$(shell_quote "${arg#"$HOME"/}")"
    else
        shell_quote "$arg"
    fi
}

# a process's arguments, shell-quoted into one command line. linux exposes the
# exact argv (/proc/PID/cmdline, NUL-separated); elsewhere ps's space-joined
# args are split and paths with spaces rejoined
# usage: quoted_command PID CWD
quoted_command() {
    local pid="$1" cwd="$2" arg out="" i=0
    local -a args=()
    if [[ -r "/proc/$pid/cmdline" ]]; then
        while IFS= read -r -d '' arg; do
            args+=("$arg")
        done <"/proc/$pid/cmdline"
    else
        local -a words
        read -ra words <<<"$(ps -o args= -p "$pid" 2>/dev/null)"
        [[ ${#words[@]} -gt 0 ]] || return 0
        while IFS= read -r arg; do
            args+=("$arg")
        done < <(rejoin_path_words "$cwd" "${words[@]}")
    fi
    for arg in "${args[@]}"; do
        out+="${out:+ }$(portable_arg "$i" "$arg" "$cwd")"
        i=$((i + 1))
    done
    printf '%s' "$out"
}

# foreground job on a pane's tty, as a shell command line. the job is the
# process group that owns the terminal (tpgid); its stages are the members
# whose parent is outside the group (forked by the shell), so the children of
# `npm run dev` are left out while each stage of `a | b` is kept
# usage: foreground_command TTY CWD
foreground_command() {
    local tty="${1#/dev/}" cwd="$2" pid out=""
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        out+="${out:+ | }$(quoted_command "$pid" "$cwd")"
    done < <(ps -t "$tty" -o pid=,ppid=,pgid=,tpgid= 2>/dev/null | awk '
        $3 == $4 { pid[NR] = $1; ppid[NR] = $2; in_group[$1] = 1 }
        END {
            for (i = 1; i <= NR; i++)
                if ((i in pid) && !(ppid[i] in in_group)) print pid[i]
        }')
    printf '%s' "$out"
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
            # only with an id: a bare `claude -r` opens the resume picker,
            # which replays fine
            if [[ " $cmd " =~ \ (--resume|-r|--session|-s)(=[^\ ]+|\ [^-\ ][^\ ]*)\  ]]; then
                printf 'resumes a specific session'
            fi
            ;;
    esac
}

main() {
    local session="${1:-}" windows panes dir cmd note
    local w_index w_name w_panes w_auto p_window p_index p_left p_top p_width p_height p_cwd p_tty
    if [[ -z "$session" ]]; then
        # the popup's client session, or the session of the pane this runs in
        session=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)
    fi
    if [[ -z "$session" ]] || ! tmux has-session -t "=$session" 2>/dev/null; then
        echo "capture.sh: no such session: ${session:-<none>}" >&2
        exit 1
    fi

    printf 'session\t%s\n' "$session"
    printf 'launcher\t%s\n' "$(tmux show-options -qv -t "=$session:" @launcher 2>/dev/null || true)"

    windows=$(tmux list-windows -t "=$session" -F '#{window_index}	#{window_name}	#{window_panes}	#{automatic-rename}')
    panes=$(tmux list-panes -s -t "=$session" -F '#{window_index}	#{pane_index}	#{pane_left}	#{pane_top}	#{pane_width}	#{pane_height}	#{pane_current_path}	#{pane_tty}')

    # most common cwd, ties to the earliest pane (list-panes -s is in window,pane order)
    dir=$(printf '%s\n' "$panes" | awk -F'\t' '
        { if (!($7 in count)) order[++n] = $7; count[$7]++ }
        END { best = order[1]; for (i = 2; i <= n; i++) if (count[order[i]] > count[best]) best = order[i]; print best }')
    printf 'dir\t%s\n' "$dir"

    while IFS=$'\t' read -r w_index w_name w_panes w_auto; do
        printf 'window\t%s\t%s\t%s\t%s\n' "$w_index" "$(clean_field "$w_name")" "$w_panes" "$w_auto"
    done <<<"$windows"

    while IFS=$'\t' read -r p_window p_index p_left p_top p_width p_height p_cwd p_tty; do
        cmd=$(foreground_command "$p_tty" "$p_cwd")
        if is_shell "$cmd"; then
            cmd=""
        fi
        cmd=$(clean_field "$cmd")
        note=""
        [[ -n "$cmd" ]] && note=$(replay_note "$cmd")
        printf 'pane\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$p_window" "$p_index" "$p_left" "$p_top" "$p_width" "$p_height" \
            "$(clean_field "$p_cwd")" "$cmd" "$note"
    done <<<"$panes"
}

# run only when executed, so tests can source the helpers above
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
