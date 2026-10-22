#!/usr/bin/env bash
# read and write generated session launchers
# source this file: source "${BASH_SOURCE%/*}/../_lib/launcher-gen.sh"
#
# both directions share one set of state variables, so a launcher can be loaded,
# changed and written back:
#   name            launcher file name (also the @launcher session tag)
#   description     one-line summary for the picker
#   instance_mode   y = prompt for an instance name (# @instance: prompt), n = auto
#   project_dir     project root; generate expects a $HOME/... form, load
#                   returns a ~/... form for display
#   worktree_aware  y/n, resolve instance suffixes to worktree directories
#   worktrees_dir   worktree root (same $HOME/~ convention as project_dir)
#   win_names, win_cmds, win_splits (yes/no), win_split_cmds   parallel arrays

[[ -n "${_TMUX_LAUNCHER_GEN_SH_LOADED:-}" ]] && return 0
_TMUX_LAUNCHER_GEN_SH_LOADED=1

# marks a launcher written by generate_launcher. only these are safe to
# regenerate in place: load_existing_launcher understands nothing else
LAUNCHER_GENERATED_MARKER="# @generated"

is_generated_launcher() {
    grep -qxF "$LAUNCHER_GENERATED_MARKER" "$1" 2>/dev/null
}

index_for_window() {
    local target="$1"
    local i
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        if [[ "${win_names[$i]}" == "$target" ]]; then
            printf '%s' "$i"
            return 0
        fi
    done
    return 1
}

# usage: load_existing_launcher FILE
load_existing_launcher() {
    local file="$1"

    description=$(grep -m1 '# @description:' "$file" 2>/dev/null | sed 's/.*# @description: *//' || true)
    if grep -q '# @instance: *prompt' "$file" 2>/dev/null; then
        instance_mode="y"
    else
        instance_mode="n"
    fi
    # a separate `_<SESSION>_ROOT_DEFAULT="$HOME/path"` line handles paths
    # containing apostrophes (which break `"${VAR:-default}"` parsing). the inline
    # `PROJECT_DIR="${VAR:-default}"` form is read too
    project_dir=$(grep -m1 '^_[A-Z0-9_]*_ROOT_DEFAULT=' "$file" 2>/dev/null |
        sed 's/^[^=]*=//' | sed 's/^"//; s/"$//' || true)
    if [[ -z "$project_dir" ]]; then
        project_dir=$(grep -m1 '^PROJECT_DIR=' "$file" 2>/dev/null | sed 's/^PROJECT_DIR=//' | tr -d '"' || true)
        if [[ "$project_dir" =~ :-(.+)\}$ ]]; then
            project_dir="${BASH_REMATCH[1]}"
        fi
    fi
    project_dir="${project_dir/#\$HOME/\~}"

    # detect worktree configuration
    if grep -q '^WORKTREES_DIR=\|^_[A-Z0-9_]*_WORKTREES_DEFAULT=' "$file" 2>/dev/null; then
        worktree_aware="y"
        worktrees_dir=$(grep -m1 '^_[A-Z0-9_]*_WORKTREES_DEFAULT=' "$file" 2>/dev/null |
            sed 's/^[^=]*=//' | sed 's/^"//; s/"$//' || true)
        if [[ -z "$worktrees_dir" ]]; then
            worktrees_dir=$(grep -m1 '^WORKTREES_DIR=' "$file" 2>/dev/null | sed 's/^WORKTREES_DIR=//' | tr -d '"' || true)
            if [[ "$worktrees_dir" =~ :-(.+)\}$ ]]; then
                worktrees_dir="${BASH_REMATCH[1]}"
            fi
        fi
        worktrees_dir="${worktrees_dir/#\$HOME/\~}"
    else
        worktree_aware="n"
    fi

    win_names=()
    win_cmds=()
    win_splits=()
    win_split_cmds=()

    local current_win="" line idx
    while IFS= read -r line; do
        if [[ "$line" =~ ^tmux\ new-session.*-n\ \"?([^\"]+)\"? ]]; then
            current_win="${BASH_REMATCH[1]}"
            win_names+=("$current_win")
            win_cmds+=("")
            win_splits+=("no")
            win_split_cmds+=("")
        elif [[ "$line" =~ ^tmux\ new-window.*-n\ \"?([^\"]+)\"? ]]; then
            current_win="${BASH_REMATCH[1]}"
            win_names+=("$current_win")
            win_cmds+=("")
            win_splits+=("no")
            win_split_cmds+=("")
        elif [[ "$line" =~ ^tmux\ split-window.*-t\ \"?\$SESSION:([^\"\ ]+)\"? ]]; then
            # target may be the window name (generated launchers) or include a pane
            # index like `dev.1` (hand-written launchers); strip a trailing .N so the
            # window still matches and the split flag is preserved
            local split_win="${BASH_REMATCH[1]}"
            [[ "$split_win" =~ \.[0-9]+$ ]] && split_win="${split_win%.*}"
            if idx=$(index_for_window "$split_win"); then
                win_splits[idx]="yes"
            fi
        elif [[ "$line" =~ ^tmux\ send-keys\ -t\ \"?\$SESSION:([^\"\ ]+)\.([12])\"?\ \'(.*)\'\ Enter ]]; then
            local cmd_win="${BASH_REMATCH[1]}"
            local pane="${BASH_REMATCH[2]}"
            local cmd="${BASH_REMATCH[3]}"
            if idx=$(index_for_window "$cmd_win"); then
                if [[ "$pane" == "1" ]]; then
                    win_cmds[idx]="$cmd"
                else
                    win_split_cmds[idx]="$cmd"
                fi
            fi
        elif [[ "$line" =~ ^tmux\ send-keys\ -t\ \"?\$SESSION:([^\"\ ]+)\"?\ \'(.*)\'\ Enter ]]; then
            local cmd_win="${BASH_REMATCH[1]}"
            local cmd="${BASH_REMATCH[2]}"
            if idx=$(index_for_window "$cmd_win"); then
                win_cmds[idx]="$cmd"
            fi
        fi
    done <"$file"

    # undo generate_launcher's '\'' escaping, or every edit would escape again
    for idx in "${!win_cmds[@]}"; do
        win_cmds[idx]="${win_cmds[idx]//\'\\\'\'/\'}"
        win_split_cmds[idx]="${win_split_cmds[idx]//\'\\\'\'/\'}"
    done
}

# write a launcher script for the state variables to stdout
# usage: generate_launcher >"$USER_LAUNCHERS/$name"
# shellcheck disable=SC2154  # reads the caller's state variables (see header)
generate_launcher() {
    local session_name session_var instance_tag worktree_prefix
    local i wname wcmd wsplit wscmd

    # session name: strip dots (tmux uses '.' as pane separator in target syntax)
    session_name=$(printf '%s' "$name" | tr '.' '-' | sed 's/-*$//')
    session_var=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '.-' '_')

    instance_tag=""
    if [[ "$instance_mode" == "y" ]]; then
        instance_tag=$'\n'"# @instance: prompt"
    fi

    cat <<PREAMBLE
#!/usr/bin/env bash
set -euo pipefail

# @description: $description${instance_tag}
$LAUNCHER_GENERATED_MARKER

# Help flag handling
if [[ "\${1:-}" == "--help" ]] || [[ "\${1:-}" == "-h" ]]; then
    cat << 'EOF'
$name - Project tmux session launcher

USAGE:
    $name

DESCRIPTION:
    Creates or attaches to the '$name' tmux session.

OPTIONS:
    -h, --help   Show this help message
EOF
    exit 0
fi

PREAMBLE

    # generate SESSION and PROJECT_DIR (worktree-aware or simple)
    #
    # path defaults are staged in `_<SESSION>_…_DEFAULT` variables, not embedded
    # inline as `${VAR:-/path}`: a single quote inside a parameter-expansion
    # default breaks bash's quoting even within `"…"`, while a plain `VAR="…"`
    # assignment takes apostrophes. the `${PATH/#\~/$HOME}` lines expand a leading
    # `~` from an env-var override (e.g. `FOO_ROOT="~/x"`)
    if [[ "$worktree_aware" == "y" ]]; then
        worktree_prefix=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')
        cat <<WTBLOCK
SESSION="\${SESSION_NAME:-$session_name}"
_${session_var}_WORKTREES_DEFAULT="$worktrees_dir"
_${session_var}_ROOT_DEFAULT="$project_dir"
WORKTREES_DIR="\${${session_var}_WORKTREES:-\$_${session_var}_WORKTREES_DEFAULT}"
BASE_DIR="\${${session_var}_ROOT:-\$_${session_var}_ROOT_DEFAULT}"
WORKTREES_DIR="\${WORKTREES_DIR/#\\~/\$HOME}"
BASE_DIR="\${BASE_DIR/#\\~/\$HOME}"

# resolve project directory: check for a matching worktree when session has a suffix
PROJECT_DIR="\$BASE_DIR"
if [[ "\$SESSION" =~ -([0-9]+)\$ ]]; then
    ticket_num="\${BASH_REMATCH[1]}"
    for wt in "\$WORKTREES_DIR"/${worktree_prefix}-"\${ticket_num}"-*; do
        if [[ -d "\$wt" ]]; then
            PROJECT_DIR="\$wt"
            break
        fi
    done
fi
WTBLOCK
    else
        cat <<SIMPLE
SESSION="\${SESSION_NAME:-$session_name}"
_${session_var}_ROOT_DEFAULT="$project_dir"
PROJECT_DIR="\${${session_var}_ROOT:-\$_${session_var}_ROOT_DEFAULT}"
PROJECT_DIR="\${PROJECT_DIR/#\\~/\$HOME}"
SIMPLE
    fi

    cat <<'VALIDATE'

# Validate project directory exists
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory not found: $PROJECT_DIR" >&2
    exit 1
fi

# Check if session already exists (= forces exact match; bare names would
# prefix-match e.g. "foo-15" against an existing "foo-1533")
if tmux has-session -t "=$SESSION" 2>/dev/null; then
    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "=$SESSION"
    else
        tmux attach-session -t "=$SESSION"
    fi
    exit 0
fi

VALIDATE

    # generate window commands
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        wname="${win_names[$i]}"
        wcmd="${win_cmds[$i]}"
        wsplit="${win_splits[$i]}"
        wscmd="${win_split_cmds[$i]}"

        # escape single quotes for safe embedding in generated send-keys commands
        wcmd="${wcmd//\'/\'\\\'\'}"
        wscmd="${wscmd//\'/\'\\\'\'}"

        if [[ $i -eq 0 ]]; then
            printf '# Window 1: %s\n' "$wname"
            printf 'tmux new-session -d -s "$SESSION" -n "%s" -c "$PROJECT_DIR"\n' "$wname"
            printf 'tmux set-option -t "=$SESSION:" @launcher %s\n' "$name"
        else
            printf '\n# Window %d: %s\n' "$((i + 1))" "$wname"
            printf 'tmux new-window -t "$SESSION:" -n "%s" -c "$PROJECT_DIR"\n' "$wname"
        fi

        if [[ "$wsplit" == "yes" ]]; then
            printf 'tmux split-window -t "$SESSION:%s" -h -c "$PROJECT_DIR"\n' "$wname"
            if [[ -n "$wcmd" ]]; then
                printf 'tmux send-keys -t "$SESSION:%s.1" '\''%s'\'' Enter\n' "$wname" "$wcmd"
            fi
            if [[ -n "$wscmd" ]]; then
                printf 'tmux send-keys -t "$SESSION:%s.2" '\''%s'\'' Enter\n' "$wname" "$wscmd"
            fi
        elif [[ -n "$wcmd" ]]; then
            printf 'tmux send-keys -t "$SESSION:%s" '\''%s'\'' Enter\n' "$wname" "$wcmd"
        fi
    done

    cat <<'FOOTER'

# Select first window
tmux select-window -t "$SESSION:1"
tmux select-pane -t "$SESSION:1.1"

# Attach to session
if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "=$SESSION"
else
    tmux attach-session -t "=$SESSION"
fi
FOOTER
}
