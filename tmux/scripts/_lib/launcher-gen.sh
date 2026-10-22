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
#   worktree_prefix instance <n> opens <worktrees_dir>/<prefix>-<n>-*; empty =
#                   the launcher name in capitals
#   win_names, win_cmds, win_splits (yes/no), win_split_cmds   parallel arrays
#   win_autonames   1 = automatic-rename names the window once it's built; its
#                   name only targets it while the launcher runs
#
# a window the wizard's model can't describe (more panes, stacked splits, a
# directory per pane) is "rich": win_panes[i] holds its pane count and the
# simple fields above are ignored for it
#   win_panes       pane count per window, empty for a simple window
#   win_layouts     split steps per window, one per line: <pane> <h|v> <pct> <new>
#                   (layout_splits format); panes are numbered 1..N, 1 = top-left
#   pane_cmds       ["<window index>:<pane>"] command, empty for a shell
#   pane_dirs       ["<window index>:<pane>"] directory: empty = the project
#                   directory, relative = under it, absolute or $HOME/... as is

[[ -n "${_TMUX_LAUNCHER_GEN_SH_LOADED:-}" ]] && return 0
_TMUX_LAUNCHER_GEN_SH_LOADED=1

declare -ga win_panes=() win_layouts=() win_autonames=()
declare -gA pane_cmds=() pane_dirs=()

# "$PROJECT_DIR"-relative form of a pane directory, for generated -c arguments
pane_dir_expr() {
    local dir="$1"
    case "$dir" in
        "") printf '%s' '$PROJECT_DIR' ;;
        /* | '$HOME' | '$HOME/'*) printf '%s' "$dir" ;;
        *) printf '%s' "\$PROJECT_DIR/$dir" ;;
    esac
}

# the reverse of pane_dir_expr
pane_dir_from_expr() {
    local expr="$1"
    case "$expr" in
        '$PROJECT_DIR') printf '' ;;
        '$PROJECT_DIR/'*) printf '%s' "${expr#\$PROJECT_DIR/}" ;;
        *) printf '%s' "$expr" ;;
    esac
}

# marks a launcher written by generate_launcher. only these are safe to
# regenerate in place: load_existing_launcher understands nothing else
LAUNCHER_GENERATED_MARKER="# @generated"

is_generated_launcher() {
    grep -qxF "$LAUNCHER_GENERATED_MARKER" "$1" 2>/dev/null
}

# the default a launcher assigns to VAR, through nested fallbacks:
# VAR="${A:-${B:-$HOME/x}}" → $HOME/x. a plain VAR="value" gives the value
# usage: launcher_assignment FILE VAR
launcher_assignment() {
    local value
    value=$(grep -m1 "^$2=" "$1" 2>/dev/null | sed "s/^$2=//" | tr -d '"' || true)
    while [[ "$value" =~ ^\$\{[A-Za-z0-9_]+:-(.*)\}$ ]]; do
        value="${BASH_REMATCH[1]}"
    done
    printf '%s' "$value"
}

# base tmux session a launcher creates (SESSION="${SESSION_NAME:-acme}" → acme),
# empty when the name is computed at run time
launcher_session_name() {
    local value
    value=$(launcher_assignment "$1" SESSION)
    [[ "$value" == *'$'* ]] && value=""
    printf '%s' "$value"
}

# where a pane of a rich window sits, from the split that created it:
# "top-left" for pane 1, else "right of 1" / "below 2"
# usage: pane_position_label WINDOW_INDEX PANE
pane_position_label() {
    local idx="$1" pane="$2" holder dir pct new
    if [[ "$pane" == 1 ]]; then
        printf 'top-left'
        return
    fi
    while read -r holder dir pct new; do
        [[ "$new" == "$pane" ]] || continue
        if [[ "$dir" == h ]]; then
            printf 'right of %s' "$holder"
        else
            printf 'below %s' "$holder"
        fi
        return
    done <<<"${win_layouts[$idx]:-}"
    printf 'pane %s' "$pane"
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
    # `PROJECT_DIR="${VAR:-default}"` form is read too, and hand-written
    # worktree launchers that set PROJECT_DIR="$BASE_DIR"
    project_dir=$(grep -m1 '^_[A-Z0-9_]*_ROOT_DEFAULT=' "$file" 2>/dev/null |
        sed 's/^[^=]*=//' | sed 's/^"//; s/"$//' || true)
    if [[ -z "$project_dir" ]]; then
        project_dir=$(launcher_assignment "$file" PROJECT_DIR)
        if [[ "$project_dir" == '$BASE_DIR' ]]; then
            project_dir=$(launcher_assignment "$file" BASE_DIR)
        fi
    fi
    project_dir="${project_dir/#\$HOME/\~}"

    # detect worktree configuration
    if grep -q '^WORKTREES_DIR=\|^_[A-Z0-9_]*_WORKTREES_DEFAULT=' "$file" 2>/dev/null; then
        worktree_aware="y"
        worktrees_dir=$(grep -m1 '^_[A-Z0-9_]*_WORKTREES_DEFAULT=' "$file" 2>/dev/null |
            sed 's/^[^=]*=//' | sed 's/^"//; s/"$//' || true)
        if [[ -z "$worktrees_dir" ]]; then
            worktrees_dir=$(launcher_assignment "$file" WORKTREES_DIR)
        fi
        worktrees_dir="${worktrees_dir/#\$HOME/\~}"
        # for wt in "$WORKTREES_DIR"/<prefix>-"${ticket_num}"-*; do
        worktree_prefix=""
        local glob_line
        glob_line=$(grep -m1 'ticket_num}"-' "$file" 2>/dev/null || true)
        if [[ "$glob_line" =~ \"\$WORKTREES_DIR\"/(.+)-\"\$\{ticket_num\}\" ]]; then
            worktree_prefix="${BASH_REMATCH[1]}"
        fi
    else
        worktree_aware="n"
        worktrees_dir=""
        worktree_prefix=""
    fi

    win_names=()
    win_cmds=()
    win_splits=()
    win_split_cmds=()
    win_panes=()
    win_layouts=()
    win_autonames=()
    pane_cmds=()
    pane_dirs=()

    # rich windows (see the header) name their panes $p1..$pN; their lines
    # follow the window's new-session/new-window, so they belong to the last
    # window read. first_dir is that window's -c, which is pane 1's directory
    local current_win="" line idx w first_dir="" k
    while IFS= read -r line; do
        if [[ "$line" =~ ^tmux\ new-(session|window).*-n\ \"?([^\"]+)\"? ]]; then
            current_win="${BASH_REMATCH[2]}"
            win_names+=("$current_win")
            win_cmds+=("")
            win_splits+=("no")
            win_split_cmds+=("")
            win_panes+=("")
            win_layouts+=("")
            win_autonames+=("")
            first_dir='$PROJECT_DIR'
            [[ "$line" =~ \ -c\ \"([^\"]*)\" ]] && first_dir="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^p1=\$\(tmux\ display-message\ -p\ -t\ \"\$SESSION: ]]; then
            w=$((${#win_names[@]} - 1))
            win_panes[w]=1
            pane_dirs["$w:1"]=$(pane_dir_from_expr "$first_dir")
            pane_cmds["$w:1"]=""
        elif [[ "$line" =~ ^p([0-9]+)=\$\(tmux\ split-window\ -d\ -t\ \"\$p([0-9]+)\"\ -([hv])\ -l\ ([0-9]+)%\ -c\ \"([^\"]*)\" ]]; then
            w=$((${#win_names[@]} - 1))
            k="${BASH_REMATCH[1]}"
            win_layouts[w]+="${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[4]} $k"$'\n'
            win_panes[w]=$((${win_panes[w]:-1} + 1))
            pane_dirs["$w:$k"]=$(pane_dir_from_expr "${BASH_REMATCH[5]}")
            pane_cmds["$w:$k"]=""
        elif [[ "$line" =~ ^tmux\ send-keys\ -t\ \"\$p([0-9]+)\"\ \'(.*)\'\ Enter ]]; then
            w=$((${#win_names[@]} - 1))
            pane_cmds["$w:${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^tmux\ set-option\ -w\ -t\ \"\$SESSION:([^\"]+)\"\ automatic-rename\ on ]]; then
            if idx=$(index_for_window "${BASH_REMATCH[1]}"); then
                win_autonames[idx]=1
            fi
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
    for idx in "${!pane_cmds[@]}"; do
        pane_cmds[$idx]="${pane_cmds[$idx]//\'\\\'\'/\'}"
    done
    # steps end with a newline as they're read; layout_splits output doesn't
    for idx in "${!win_layouts[@]}"; do
        win_layouts[idx]="${win_layouts[idx]%$'\n'}"
    done
}

# write a launcher script for the state variables to stdout
# usage: generate_launcher >"$USER_LAUNCHERS/$name"
# shellcheck disable=SC2154  # reads the caller's state variables (see header)
generate_launcher() {
    local session_name session_var instance_tag wt_prefix
    local i wname wcmd wsplit wscmd wdir

    # session name: strip dots (tmux uses '.' as pane separator in target syntax)
    session_name=$(printf '%s' "$name" | tr '.' '-' | sed 's/-*$//')
    session_var=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '.-' '_')

    instance_tag=""
    if [[ "$instance_mode" == "y" ]]; then
        instance_tag=$'\n'"# @instance: prompt"
    fi

    wt_prefix="${worktree_prefix:-}"
    [[ -n "$wt_prefix" ]] || wt_prefix=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')

    # --help: what the instance suffix does, and the overrides read below
    local help_worktrees="" help_env
    help_env="    SESSION_NAME    tmux session name (default: $session_name)
    ${session_var}_ROOT    project directory (default: ${project_dir/#\$HOME/\~})"
    if [[ "$worktree_aware" == "y" ]]; then
        help_worktrees="

    A session named $session_name-<n> opens the worktree $wt_prefix-<n>-*,
    any other $session_name-<suffix> the worktree named <suffix>, from
    ${session_var}_WORKTREES"
        help_env+="
    ${session_var}_WORKTREES    worktrees directory (default: ${worktrees_dir/#\$HOME/\~})"
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
    Creates or attaches to the '$name' tmux session.${help_worktrees}

OPTIONS:
    -h, --help   Show this help message

ENVIRONMENT:
$help_env
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
        cat <<WTBLOCK
SESSION="\${SESSION_NAME:-$session_name}"
_${session_var}_WORKTREES_DEFAULT="$worktrees_dir"
_${session_var}_ROOT_DEFAULT="$project_dir"
WORKTREES_DIR="\${${session_var}_WORKTREES:-\$_${session_var}_WORKTREES_DEFAULT}"
BASE_DIR="\${${session_var}_ROOT:-\$_${session_var}_ROOT_DEFAULT}"
WORKTREES_DIR="\${WORKTREES_DIR/#\\~/\$HOME}"
BASE_DIR="\${BASE_DIR/#\\~/\$HOME}"

# resolve project directory: a numeric session suffix opens the worktree for
# that number, any other suffix the worktree with exactly that name
PROJECT_DIR="\$BASE_DIR"
if [[ "\$SESSION" =~ -([0-9]+)\$ ]]; then
    ticket_num="\${BASH_REMATCH[1]}"
    for wt in "\$WORKTREES_DIR"/${wt_prefix}-"\${ticket_num}"-*; do
        if [[ -d "\$wt" ]]; then
            PROJECT_DIR="\$wt"
            break
        fi
    done
elif [[ "\$SESSION" == "${session_name}-"* && -d "\$WORKTREES_DIR/\${SESSION#${session_name}-}" ]]; then
    PROJECT_DIR="\$WORKTREES_DIR/\${SESSION#${session_name}-}"
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

    # a rich layout is a set of proportions, so the session must be created at
    # the client's size: tmux builds detached sessions at 80x24 and the resize
    # on attach hands out the difference unevenly, which would skew them
    has_rich=0
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        [[ -n "${win_panes[$i]:-}" ]] && has_rich=1
    done
    if [[ $has_rich -eq 1 ]]; then
        cat <<'SIZING'

# create the session at the client's size (see above)
_cols=$(tmux display-message -p '#{client_width}' 2>/dev/null || true)
_rows=$(tmux display-message -p '#{client_height}' 2>/dev/null || true)
[[ -n "$_cols" ]] || _cols=$(tput cols 2>/dev/null || echo 80)
[[ -n "$_rows" ]] || _rows=$(tput lines 2>/dev/null || echo 24)

SIZING
    fi

    # generate window commands
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        wname="${win_names[$i]}"
        wcmd="${win_cmds[$i]}"
        wsplit="${win_splits[$i]}"
        wscmd="${win_split_cmds[$i]}"

        # escape single quotes for safe embedding in generated send-keys commands
        wcmd="${wcmd//\'/\'\\\'\'}"
        wscmd="${wscmd//\'/\'\\\'\'}"

        # a rich window's first pane starts in its own directory
        wdir='$PROJECT_DIR'
        if [[ -n "${win_panes[$i]:-}" ]]; then
            wdir=$(pane_dir_expr "${pane_dirs["$i:1"]:-}")
        fi

        if [[ $i -eq 0 ]]; then
            printf '# Window 1: %s\n' "$wname"
            printf 'tmux new-session -d -s "$SESSION" -n "%s" -c "%s"' "$wname" "$wdir"
            [[ $has_rich -eq 1 ]] && printf ' -x "$_cols" -y "$_rows"'
            printf '\n'
            printf 'tmux set-option -t "=$SESSION:" @launcher %s\n' "$name"
        else
            printf '\n# Window %d: %s\n' "$((i + 1))" "$wname"
            printf 'tmux new-window -t "$SESSION:" -n "%s" -c "%s"\n' "$wname" "$wdir"
        fi

        if [[ -n "${win_panes[$i]:-}" ]]; then
            # panes are addressed by id ($p1..$pN), which stays valid while
            # splits renumber pane indexes. -d keeps the first pane active
            printf 'p1=$(tmux display-message -p -t "$SESSION:%s" '\''#{pane_id}'\'')\n' "$wname"
            local holder dir pct new k pcmd
            while read -r holder dir pct new; do
                [[ -n "$holder" ]] || continue
                printf 'p%s=$(tmux split-window -d -t "$p%s" -%s -l %s%% -c "%s" -P -F '\''#{pane_id}'\'')\n' \
                    "$new" "$holder" "$dir" "$pct" "$(pane_dir_expr "${pane_dirs["$i:$new"]:-}")"
            done <<<"${win_layouts[$i]:-}"
            for ((k = 1; k <= win_panes[i]; k++)); do
                pcmd="${pane_cmds["$i:$k"]:-}"
                [[ -n "$pcmd" ]] || continue
                printf 'tmux send-keys -t "$p%s" '\''%s'\'' Enter\n' "$k" "${pcmd//\'/\'\\\'\'}"
            done
        elif [[ "$wsplit" == "yes" ]]; then
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

    # last: renaming a window breaks the name-based targets above
    local auto_header=0
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        [[ "${win_autonames[$i]:-}" == 1 ]] || continue
        if [[ $auto_header -eq 0 ]]; then
            printf '\n# hand these windows back to automatic-rename\n'
            auto_header=1
        fi
        printf 'tmux set-option -w -t "$SESSION:%s" automatic-rename on\n' "${win_names[$i]}"
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
