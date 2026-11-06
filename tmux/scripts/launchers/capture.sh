#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# capture a session's layout
# ══════════════════════════════════════════════════════════════
# reads a tmux or rex session (launcher-backend.sh picks) and prints its shape
# as tab-separated rows, for "save session as launcher" (launchers/save.sh).
# reports only, no decisions: the caller chooses how to map this onto a launcher
#
# usage: capture.sh [session]    (default: the current session)
#
# output rows (fields are tab-separated, in this order):
#   session   <name>
#   launcher  <@launcher tag, empty if untagged>
#   dir       <most common pane cwd; ties go to the earliest pane>
#   active    <window index> <pane index> of the session's current pane
#   window    <index> <name> <pane count> <automatic-rename: 1 or 0>
#   pane      <window index> <pane index> <left> <top> <width> <height> <cwd> <command> <note>
#   split     <window index> <pane> <h|v> <percent> <new pane>
#
# split rows are the steps that build a window, in order, in layout_splits'
# format; only rex prints them, as its layout is already a split tree. a tmux
# window's steps come from its pane rectangles instead, and a rex pane's
# rectangle is 0 0 0 0
#
# <command> is the pane's foreground job with its arguments, empty when the
# pane sits at a shell prompt. <note> is empty, or a short reason the command
# may not replay well from a launcher

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=tmux/scripts/_lib/launcher-backend.sh
source "$SCRIPT_DIR/../_lib/launcher-backend.sh"

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

# read a tmux session into session, launcher_tag, window_rows, pane_rows and
# active (the rows as tab-separated rows in the window/pane row order, the
# pane rows ending in the pane's tty)
read_tmux_session() {
    session="${1:-}"
    if [[ -z "$session" ]]; then
        # the popup's client session, or the session of the pane this runs in
        session=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)
    fi
    if [[ -z "$session" ]] || ! tmux has-session -t "=$session" 2>/dev/null; then
        echo "capture.sh: no such session: ${session:-<none>}" >&2
        exit 1
    fi
    launcher_tag=$(tmux show-options -qv -t "=$session:" @launcher 2>/dev/null || true)
    split_rows=""
    window_rows=$(tmux list-windows -t "=$session" -F '#{window_index}	#{window_name}	#{window_panes}	#{automatic-rename}')
    pane_rows=$(tmux list-panes -s -t "=$session" -F '#{window_index}	#{pane_index}	#{pane_left}	#{pane_top}	#{pane_width}	#{pane_height}	#{pane_current_path}	#{pane_tty}')
    active=$(tmux display-message -p -t "=$session:" '#{window_index}	#{pane_index}')
}

# the same for a rex session (default: this terminal's session), plus
# split_rows. a window with rex's default label is auto-named after its first
# pane's program. floating layers (pickers) are left out
# shellcheck disable=SC2016 # jq source
read_rex_session() {
    local sid="" view rows kind a b c d e block proc pid cwd tty
    session="${1:-}"
    if [[ -n "$session" ]]; then
        sid=$(rex_session_id "$session")
    else
        sid="${REX_SESSION:-}"
        session=$(rex ls --json | jq -r --arg s "$sid" '[.sessions[] | select(.session_id == $s)][0].label // empty')
    fi
    if [[ -z "$sid" || -z "$session" ]]; then
        echo "capture.sh: no such session: ${session:-<none>}" >&2
        exit 1
    fi
    launcher_tag=""
    view=$(rex api call -s "$sid" session.view '{}')
    # an open picker is the session's focused block, so the pane it opened
    # from (PICK_ORIGIN_BLOCK, when it's in this session) counts as active
    rows=$(jq -r --arg origin "${PICK_ORIGIN_BLOCK:-}" '
        def leaves: if .split then (.split.before | leaves), (.split.after | leaves) else . end;
        def tiled: [.layers[] | select(.kind == "tiled") | .layout | leaves | .block_id];
        def first: if .split then .split.before | first else .block_id end;
        # outer split first, then each side: the order that rebuilds the tree
        def steps: if .split then
            [(.split.before | first), (if .split.direction == "horizontal" then "h" else "v" end),
             ((1 - .split.ratio) * 100 | round | [., 1] | max | [., 99] | min), (.split.after | first)],
            (.split.before | steps), (.split.after | steps)
            else empty end;
        ([.windows[] | select(tiled | index($origin)) | .window_id][0]) as $ow |
        ($ow // .active_window_id) as $aw |
        .windows | to_entries[] | (.key + 1) as $w | .value |
        (if $ow then $origin else .focused_block_id end) as $fb |
        ([.layers[] | select(.kind == "tiled") | .layout][0]) as $layout |
        ([$layout | leaves]) as $blocks |
        ([$blocks[].block_id]) as $ids |
        (if (.label | test("^Window [0-9a-f]{8}$")) then "" else .label end) as $name |
        ["W", $w, $name, ($blocks | length)],
        ($ids | to_entries[] | ["P", $w, (.key + 1), .value]),
        ($layout | steps as $s | ["S", $w, ($ids | index($s[0])) + 1, $s[1], $s[2], ($ids | index($s[3])) + 1]),
        (if .window_id == $aw then ["A", $w, ($ids | index($fb) // 0) + 1] else empty end)
        | map(tostring) | join("\u001f")' <<<"$view")

    window_rows="" pane_rows="" split_rows="" active=""
    local -A auto_names=()
    # \x1f separates fields: read collapses runs of a whitespace IFS like tab,
    # which would shift the fields after an empty window name
    while IFS=$'\x1f' read -r kind a b c d e; do
        case "$kind" in
            W) window_rows+="$a"$'\x1f'"$b"$'\x1f'"$c"$'\x1f'"$([[ -z "$b" ]] && echo 1 || echo 0)"$'\n' ;;
            A) active="$a"$'\t'"$b" ;;
            S) split_rows+="$a"$'\t'"$b"$'\t'"$c"$'\t'"$d"$'\t'"$e"$'\n' ;;
            P)
                block="$c" cwd="" tty=""
                proc=$(rex block call -s "$sid" -b "$block" process 2>/dev/null || true)
                pid=$(jq -r '.foreground.pid // empty' <<<"$proc")
                cwd=$(jq -r '.foreground.cwd // empty' <<<"$proc")
                [[ -n "$pid" ]] && tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
                [[ -n "$tty" && "$tty" != "??" ]] && tty="/dev/$tty" || tty=""
                [[ "$b" == 1 ]] && auto_names[$a]=$(jq -r '.foreground.name // empty' <<<"$proc")
                pane_rows+="$a"$'\t'"$b"$'\t0\t0\t0\t0\t'"$cwd"$'\t'"$tty"$'\n'
                ;;
        esac
    done <<<"$rows"
    # an auto-named window takes its first pane's program name, as tmux's
    # automatic-rename would show it
    window_rows=$(while IFS=$'\x1f' read -r a b c d; do
        [[ -n "$a" ]] || continue
        [[ -z "$b" ]] && b="${auto_names[$a]:-shell}"
        printf '%s\t%s\t%s\t%s\n' "$a" "$b" "$c" "$d"
    done <<<"$window_rows")
    pane_rows="${pane_rows%$'\n'}"
    split_rows="${split_rows%$'\n'}"
}

main() {
    local session window_rows pane_rows split_rows active launcher_tag dir cmd note
    local w_index w_name w_panes w_auto p_window p_index p_left p_top p_width p_height p_cwd p_tty
    if [[ "$(launcher_backend)" == rex ]]; then
        read_rex_session "${1:-}"
    else
        read_tmux_session "${1:-}"
    fi

    printf 'session\t%s\n' "$session"
    printf 'launcher\t%s\n' "$launcher_tag"

    # most common cwd, ties to the earliest pane (panes are in window,pane order)
    dir=$(printf '%s\n' "$pane_rows" | awk -F'\t' '
        { if (!($7 in count)) order[++n] = $7; count[$7]++ }
        END { best = order[1]; for (i = 2; i <= n; i++) if (count[order[i]] > count[best]) best = order[i]; print best }')
    printf 'dir\t%s\n' "$dir"
    printf 'active\t%s\n' "$active"

    while IFS=$'\t' read -r w_index w_name w_panes w_auto; do
        printf 'window\t%s\t%s\t%s\t%s\n' "$w_index" "$(clean_field "$w_name")" "$w_panes" "$w_auto"
    done <<<"$window_rows"

    while IFS=$'\t' read -r p_window p_index p_left p_top p_width p_height p_cwd p_tty; do
        cmd=""
        [[ -n "$p_tty" ]] && cmd=$(foreground_command "$p_tty" "$p_cwd")
        if is_shell "$cmd"; then
            cmd=""
        fi
        cmd=$(clean_field "$cmd")
        note=""
        [[ -n "$cmd" ]] && note=$(replay_note "$cmd")
        printf 'pane\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$p_window" "$p_index" "$p_left" "$p_top" "$p_width" "$p_height" \
            "$(clean_field "$p_cwd")" "$cmd" "$note"
    done <<<"$pane_rows"
    if [[ -n "$split_rows" ]]; then
        printf '%s\n' "$split_rows" | sed 's/^/split\t/'
    fi
}

# run only when executed, so tests can source the helpers above
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
