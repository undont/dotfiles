#!/usr/bin/env bash
# shellcheck disable=SC2059,SC2016
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# New Launcher Wizard
# ══════════════════════════════════════════════════════════════
# Step-based wizard for creating/editing session launchers.
# Supports ctrl+z to go back a step.
#
# Usage: new-launcher.sh [name]
#        new-launcher.sh --edit SOURCE [name]

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=scripts/_lib/common.sh
source "$DOTFILES_ROOT/scripts/_lib/common.sh"

USER_LAUNCHERS="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/launchers"

# Ensure stdin/stdout use terminal (needed when called via fzf become() in a pipeline).
# Security note: this redirects to the controlling terminal, bypassing any pipe isolation.
# Safe here because this script is only invoked interactively from the launcher picker.
exec < /dev/tty > /dev/tty

# ─────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────
edit_source=""
name=""

if [[ "${1:-}" == "--edit" ]]; then
    edit_source="${2:-}"
    shift 2
fi

name="${1:-}"

# ─────────────────────────────────────────
# Helpers for edit mode
# ─────────────────────────────────────────
resolve_edit_source() {
    local source="$1"
    source=$(basename "$source")
    if [[ "$source" == "." ]] || [[ "$source" == ".." ]] || [[ "$source" == *"/"* ]]; then
        printf '%s' ""
        return 1
    fi
    if [[ -x "$USER_LAUNCHERS/$source" ]]; then
        printf '%s' "$USER_LAUNCHERS/$source"
        return 0
    fi
    if [[ -x "$SCRIPT_DIR/../launchers/$source" ]]; then
        printf '%s' "$SCRIPT_DIR/../launchers/$source"
        return 0
    fi
    printf '%s' ""
    return 1
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

load_existing_launcher() {
    local file="$1"

    description=$(grep -m1 '# @description:' "$file" 2>/dev/null | sed 's/.*# @description: *//' || true)
    if grep -q '# @instance: *prompt' "$file" 2>/dev/null; then
        instance_mode="y"
    else
        instance_mode="n"
    fi
    project_dir=$(grep -m1 '^PROJECT_DIR=' "$file" 2>/dev/null | sed 's/^PROJECT_DIR=//' | tr -d '"' || true)
    # Extract fallback from ${VAR:-default} pattern
    if [[ "$project_dir" =~ :-(.+)\}$ ]]; then
        project_dir="${BASH_REMATCH[1]}"
    fi
    project_dir="${project_dir/#\$HOME/\~}"

    # Detect worktree configuration
    if grep -q 'WORKTREES_DIR=' "$file" 2>/dev/null; then
        worktree_aware="y"
        worktrees_dir=$(grep -m1 '^WORKTREES_DIR=' "$file" 2>/dev/null | sed 's/^WORKTREES_DIR=//' | tr -d '"' || true)
        if [[ "$worktrees_dir" =~ :-(.+)\}$ ]]; then
            worktrees_dir="${BASH_REMATCH[1]}"
        fi
        worktrees_dir="${worktrees_dir/#\$HOME/\~}"
    else
        worktree_aware="n"
    fi

    win_names=()
    win_cmds=()
    win_splits=()
    win_split_cmds=()

    local current_win=""
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
            local split_win="${BASH_REMATCH[1]}"
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
    done < "$file"

    if [[ ${#win_names[@]} -gt 0 ]]; then
        num_windows="${#win_names[@]}"
    fi

    # Recalculate total steps with pre-loaded window count
    if [[ -n "$num_windows" ]]; then
        total_steps=$((5 + num_windows))
    fi
}

# ─────────────────────────────────────────
# Additional colour definitions
# ─────────────────────────────────────────
DIM=$'\033[2m'

# ─────────────────────────────────────────
# Ctrl+B back navigation
# ─────────────────────────────────────────
# read -e enables readline. Rebind ctrl+b to: clear line → insert
# text marker → auto-submit. The ask functions detect the marker
# and return 1 (go back). Left arrow still works for cursor movement.
BACK_MARKER="__BACK__"
bind '"\C-b": "\C-a\C-k__BACK__\C-m"' 2>/dev/null

# ─────────────────────────────────────────
# UI helpers
# ─────────────────────────────────────────

# Draw wizard header with step indicator
# Usage: draw_header "step_num" "total_steps"
draw_header() {
    local step="$1"
    local total="$2"
    local width=62
    local title
    if [[ -n "$edit_source" ]]; then
        title="Edit Launcher"
    else
        title="New Launcher"
    fi
    local indicator="step $step of $total"
    local label_plain="$title  ·  $indicator"
    local label="$title  ${DIM}·  $indicator${NC}"

    # Centre the box horizontally
    local term_width=${COLUMNS:-$(tput cols)}
    local box_width=$((width + 2))  # ╭ + inner + ╮
    local margin=$(( (term_width - box_width) / 2 ))
    [[ $margin -lt 0 ]] && margin=0
    local pad
    pad=$(printf '%*s' "$margin" '')

    clear
    printf "\n"
    printf "%s${CYAN}╭%s╮${NC}\n" "$pad" "$(printf '─%.0s' $(seq 1 $width))"
    printf "%s${CYAN}│${NC}  %s%*s${CYAN}│${NC}\n" "$pad" "$label" $((width - ${#label_plain} - 2)) ""
    printf "%s${CYAN}╰%s╯${NC}\n" "$pad" "$(printf '─%.0s' $(seq 1 $width))"
    printf "\n"
}

# Draw footer with controls (fzf border-label style)
# Usage: draw_footer "back_hint"
#   "false"  = no back option (not shown)
#   "true"   = ^b back
#   "rename" = ^b rename
draw_footer() {
    local back_hint="$1"
    local hints=" enter"
    case "$back_hint" in
        true)   hints="$hints · ^b back" ;;
        rename) hints="$hints · ^b rename" ;;
    esac
    hints="$hints · ^c cancel "

    # Centre the footer and pin to bottom of screen
    local term_width=${COLUMNS:-$(tput cols)}
    local term_height=${LINES:-$(tput lines)}
    local hints_len=${#hints}
    local side_len=$(( (term_width - hints_len) / 2 ))
    [[ $side_len -lt 1 ]] && side_len=1
    local left_border
    left_border=$(printf '─%.0s' $(seq 1 $side_len))
    local right_border
    right_border=$(printf '─%.0s' $(seq 1 $side_len))

    local footer_line="${DIM}${left_border}${NC}${CYAN}${hints}${NC}${DIM}${right_border}${NC}"

    # Save cursor, jump to bottom, print footer, restore cursor
    printf '\033[s'
    printf '\033[%d;1H' "$((term_height - 1))"
    printf '%s' "$footer_line"
    printf '\033[u'
}

# Show context from previous steps (dim)
# Usage: show_context "label" "value"
show_context() {
    local label="$1"
    local value="$2"
    if [[ -n "$value" ]]; then
        printf "  ${DIM}%s: %s${NC}\n" "$label" "$value"
    fi
}

# Prompt for input with default value, respects ctrl+z
# Usage: ask "label" "default_value" result_var
# Returns 1 if ctrl+z was pressed (go back)
ask() {
    local label="$1"
    local default="$2"
    local -n _result="$3"

    # Use \001/\002 to mark non-printing chars so readline calculates width correctly
    local rl_cyan=$'\001'"${CYAN}"$'\002'
    local rl_nc=$'\001'"${NC}"$'\002'
    local prompt
    if [[ -n "$default" ]]; then
        prompt="  ${rl_cyan}${label}${rl_nc}: "
        read -er -i "$default" -p "$prompt" _result || true
    else
        prompt="  ${rl_cyan}${label}${rl_nc}: "
        read -er -p "$prompt" _result || true
    fi

    # Detect literal ctrl+z in input (tmux popup doesn't send SIGTSTP)
    if [[ "$_result" == *"$BACK_MARKER"* ]]; then
        return 1
    fi

    if [[ -z "$_result" && -n "$default" ]]; then
        _result="$default"
    fi
    return 0
}

# Prompt for yes/no with default, respects ctrl+z
# Usage: ask_yn "label" "default" result_var
# Returns 1 if ctrl+z was pressed (go back)
ask_yn() {
    local label="$1"
    local default="$2"
    local -n _yn_result="$3"
    local prompt_hint

    if [[ "$default" == "y" ]]; then
        prompt_hint="Y/n"
    else
        prompt_hint="y/N"
    fi

    # Use \001/\002 to mark non-printing chars so readline calculates width correctly
    local rl_cyan=$'\001'"${CYAN}"$'\002'
    local rl_nc=$'\001'"${NC}"$'\002'
    local prompt="  ${rl_cyan}${label}${rl_nc} [${prompt_hint}]: "

    read -er -p "$prompt" _yn_result || true

    # Detect literal ctrl+z in input (tmux popup doesn't send SIGTSTP)
    if [[ "$_yn_result" == *"$BACK_MARKER"* ]]; then
        return 1
    fi

    if [[ -z "$_yn_result" ]]; then
        _yn_result="$default"
    fi
    return 0
}

# ─────────────────────────────────────────
# State variables
# ─────────────────────────────────────────
description=""
instance_mode=""
project_dir=""
num_windows=""
declare -a win_names=()
declare -a win_cmds=()
declare -a win_splits=()
declare -a win_split_cmds=()
worktree_aware=""
worktrees_dir=""
default_names=("dev" "edit" "shell")

# Calculate total steps (recalculated after step 5)
total_steps=5
step=1

# Handle edit mode: resolve source and load existing values
if [[ -n "$edit_source" ]]; then
    edit_source=$(basename "$edit_source")
    edit_file=$(resolve_edit_source "$edit_source")
    if [[ -z "$edit_file" ]]; then
        clear
        printf "\n"
        printf "  ${RED}Launcher '%s' not found${NC}\n\n" "$edit_source"
        exit 1
    fi
    load_existing_launcher "$edit_file"
    if [[ -z "$name" ]]; then
        name="$edit_source"
    fi
fi

# If name was provided, start at step 1 (description)
# but validate/sanitise it first
if [[ -n "$name" ]]; then
    name=$(sanitise_launcher_name "$name")
    if [[ -z "$edit_source" && -f "$USER_LAUNCHERS/$name" ]]; then
        clear
        printf "\n"
        printf "  ${RED}Launcher '%s' already exists${NC}\n\n" "$name"
        printf "  ${DIM}%s/%s${NC}\n" "$USER_LAUNCHERS" "$name"

        # Pin hint to bottom (prefixed to avoid polluting global namespace)
        _err_tw=${COLUMNS:-$(tput cols)}
        _err_th=${LINES:-$(tput lines)}
        _err_hint=" spc/enter back · q/esc close "
        _err_side=$(( (_err_tw - ${#_err_hint}) / 2 ))
        [[ $_err_side -lt 1 ]] && _err_side=1
        _err_border=$(printf '─%.0s' $(seq 1 $_err_side))
        printf '\033[%d;1H' "$((_err_th - 1))"
        printf "${DIM}%s${NC}${CYAN}%s${NC}${DIM}%s${NC}" "$_err_border" "$_err_hint" "$_err_border"
        printf '\033[6;1H'

        while true; do
            read -rsn1 _err_key
            case "$_err_key" in
                r|' '|'') exec "$SCRIPT_DIR/prompt.sh" ;;
                q|$'\x1b') exit 0 ;;
            esac
        done
    fi
fi

# ─────────────────────────────────────────
# Main wizard loop
# ─────────────────────────────────────────
while true; do
    case $step in
        1)
            # Step 1: Description
            draw_header 1 "$total_steps"
            printf "  ${GREEN}What does this launcher do?${NC}\n\n"
            show_context "Name" "$name"
            draw_footer "rename"

            local_desc=""
            if ask "Description" "${description:-$name project session}" local_desc; then
                description="$local_desc"
                step=2
            else
                # ctrl+b on step 1 — go back to name prompt
                if [[ -n "$edit_source" ]]; then
                    exec "$SCRIPT_DIR/prompt.sh" --edit "$edit_source"
                fi
                exec "$SCRIPT_DIR/prompt.sh"
            fi
            ;;

        2)
            # Step 2: Instance mode
            draw_header 2 "$total_steps"
            printf "  ${GREEN}Prompt for name when creating instances?${NC}\n"
            printf "  ${DIM}e.g. ticket numbers: %s-1234${NC}\n\n" "$name"
            show_context "Name" "$name"
            show_context "Desc" "$description"
            draw_footer "true"

            local_instance=""
            if ask_yn "Prompt for instance name?" "${instance_mode:-n}" local_instance; then
                if [[ "$local_instance" =~ ^[Yy] ]]; then
                    instance_mode="y"
                else
                    instance_mode="n"
                fi
                step=3
            else
                step=1
            fi
            ;;

        3)
            # Step 3: Project directory (inline fzf picker)
            load_fzf_theme
            draw_header 3 "$total_steps"
            printf "  ${GREEN}Where is the project?${NC}\n\n"
            show_context "Name" "$name"
            show_context "Desc" "$description"
            printf "\n"

            local_default_dir="${project_dir:-~/src/$name}"

            local_fzf_result=""
            local_fzf_exit=0
            local_fzf_result=$(list_project_dirs | fzf \
                --print-query \
                --query="$local_default_dir" \
                --prompt='  Directory: ' \
                --header='  opt-enter: use typed path' \
                --height=~60% \
                --layout=reverse \
                --no-info \
                --pointer='▸' \
                --bind 'enter:accept' \
                --bind 'alt-enter:become(echo {q})' \
                --bind 'esc:abort' \
                2>/dev/null) || local_fzf_exit=$?

            # exit 130 = esc/abort, exit 2 = error → go back
            # exit 1 = no match → use the typed query
            # alt-enter uses become() so exits 0 with just the query (no line 2)
            if [[ $local_fzf_exit -gt 1 ]]; then
                step=2
                continue
            fi

            # --print-query: line 1 = query, line 2 = selected item
            local_query=$(printf '%s' "$local_fzf_result" | sed -n '1p' | sed 's/^[[:space:]]*//')
            local_selected=$(printf '%s' "$local_fzf_result" | sed -n '2p' | sed 's/^[[:space:]]*//')
            local_dir="${local_selected:-$local_query}"

            if [[ -z "$local_dir" ]]; then
                local_dir="$local_default_dir"
            fi

            # Check if directory exists (expand ~ for the check)
            local_expanded="${local_dir/#\~/$HOME}"
            if [[ ! -d "$local_expanded" ]]; then
                printf "\n"
                printf "  ${YELLOW}Directory not found:${NC} %s\n" "$local_dir"
                local_create=""
                if ask_yn "Create it?" "y" local_create; then
                    if [[ "$local_create" =~ ^[Yy] ]]; then
                        mkdir -p "$local_expanded"
                    fi
                else
                    # ctrl+b → stay on step 3
                    continue
                fi
            fi

            project_dir="$local_dir"
            # Expand ~ for template but keep $HOME in generated script
            if [[ "$project_dir" == "~" ]]; then
                project_dir="\$HOME"
            else
                project_dir="${project_dir/#\~\//\$HOME/}"
            fi
            step=4
            ;;

        4)
            # Step 4: Worktree awareness
            draw_header 4 "$total_steps"
            printf "  ${GREEN}Resolve worktree directories for instances?${NC}\n"
            printf "  ${DIM}e.g. %s-1252 → worktrees/%s-1252-*${NC}\n\n" "$name" "$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
            show_context "Name" "$name"
            show_context "Desc" "$description"
            show_context "Dir" "$project_dir"
            draw_footer "true"

            local_wt=""
            if ! ask_yn "Worktree aware?" "${worktree_aware:-n}" local_wt; then
                step=3
                continue
            fi

            if [[ "$local_wt" =~ ^[Yy] ]]; then
                worktree_aware="y"
                local_wtdir=""
                if ! ask "Worktrees directory" "${worktrees_dir:-\$HOME/src/$name-worktrees}" local_wtdir; then
                    step=3
                    continue
                fi
                worktrees_dir="$local_wtdir"
                if [[ "$worktrees_dir" == "~" ]]; then
                    worktrees_dir="\$HOME"
                else
                    worktrees_dir="${worktrees_dir/#\~\//\$HOME/}"
                fi
            else
                worktree_aware="n"
                worktrees_dir=""
            fi
            step=5
            ;;

        5)
            # Step 5: Number of windows
            draw_header 5 "$total_steps"
            printf "  ${GREEN}How many windows?${NC}\n\n"
            show_context "Name" "$name"
            show_context "Desc" "$description"
            show_context "Dir" "$project_dir"
            if [[ "$worktree_aware" == "y" ]]; then
                show_context "Worktrees" "$worktrees_dir"
            fi
            draw_footer "true"

            local_num=""
            if ask "Number of windows" "${num_windows:-3}" local_num; then
                # Validate it's a number between 1 and 20
                if ! [[ "$local_num" =~ ^[0-9]+$ ]] || [[ "$local_num" -lt 1 ]]; then
                    local_num=3
                elif [[ "$local_num" -gt 20 ]]; then
                    local_num=20
                fi
                # Only reset window arrays if count changed
                if [[ "$local_num" != "$num_windows" ]]; then
                    win_names=()
                    win_cmds=()
                    win_splits=()
                    win_split_cmds=()
                fi
                num_windows="$local_num"
                total_steps=$((5 + num_windows))
                step=6
            else
                step=4
            fi
            ;;

        *)
            # Steps 6+: Window configuration
            local_win_idx=$((step - 5))  # 1-based window index

            if [[ $local_win_idx -gt $num_windows ]]; then
                # Past last window — done
                break
            fi

            draw_header "$step" "$total_steps"
            printf "  ${GREEN}Window %d${NC}\n\n" "$local_win_idx"
            show_context "Name" "$name"
            show_context "Desc" "$description"
            show_context "Dir" "$project_dir"
            if [[ "$worktree_aware" == "y" ]]; then
                show_context "Worktrees" "$worktrees_dir"
            fi

            # Show previously configured windows
            for ((p = 1; p < local_win_idx; p++)); do
                local_p_idx=$((p - 1))
                if [[ $local_p_idx -lt ${#win_names[@]} ]]; then
                    local_split_info=""
                    if [[ "${win_splits[$local_p_idx]:-no}" == "yes" ]]; then
                        local_split_info=" (split)"
                    fi
                    show_context "Win $p" "${win_names[$local_p_idx]}${local_split_info}"
                fi
            done
            draw_footer "true"

            local_default="${default_names[$((local_win_idx - 1))]:-window-$local_win_idx}"

            # Get existing values for this window if going back
            local_prev_name="${win_names[$((local_win_idx - 1))]:-}"
            local_prev_cmd="${win_cmds[$((local_win_idx - 1))]:-}"
            local_prev_split="${win_splits[$((local_win_idx - 1))]:-no}"
            local_prev_scmd="${win_split_cmds[$((local_win_idx - 1))]:-}"

            local_wname=""
            if ! ask "Name" "${local_prev_name:-$local_default}" local_wname; then
                step=$((step - 1))
                continue
            fi

            local_wcmd=""
            if ! ask "Command" "${local_prev_cmd}" local_wcmd; then
                step=$((step - 1))
                continue
            fi

            local_wsplit=""
            local_wsplit_default="n"
            if [[ "$local_prev_split" == "yes" ]]; then
                local_wsplit_default="y"
            fi
            if ! ask_yn "Split pane?" "$local_wsplit_default" local_wsplit; then
                step=$((step - 1))
                continue
            fi

            local_wscmd=""
            if [[ "$local_wsplit" =~ ^[Yy] ]]; then
                if ! ask "Split command" "${local_prev_scmd}" local_wscmd; then
                    step=$((step - 1))
                    continue
                fi
            fi

            # Store window config (replace if going forward again)
            local_arr_idx=$((local_win_idx - 1))
            win_names[local_arr_idx]="$local_wname"
            win_cmds[local_arr_idx]="$local_wcmd"
            if [[ "$local_wsplit" =~ ^[Yy] ]]; then
                win_splits[local_arr_idx]="yes"
            else
                win_splits[local_arr_idx]="no"
            fi
            win_split_cmds[local_arr_idx]="$local_wscmd"

            step=$((step + 1))
            ;;
    esac
done

# ─────────────────────────────────────────
# Generate launcher file (edit-aware)
# ─────────────────────────────────────────

mkdir -p "$USER_LAUNCHERS"

target_name="$name"
target_path="$USER_LAUNCHERS/$target_name"

# If editing a user launcher and the name changed, remove the old file
if [[ -n "$edit_source" ]]; then
    if [[ -f "$USER_LAUNCHERS/$edit_source" && "$edit_source" != "$target_name" ]]; then
        rm -f "$USER_LAUNCHERS/$edit_source"
    fi
fi

session_var=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

{
    instance_tag=""
    if [[ "$instance_mode" == "y" ]]; then
        instance_tag=$'\n'"# @instance: prompt"
    fi

    cat << PREAMBLE
#!/usr/bin/env bash
set -euo pipefail

# @description: $description${instance_tag}

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

    # Generate SESSION and PROJECT_DIR (worktree-aware or simple)
    if [[ "$worktree_aware" == "y" ]]; then
        worktree_prefix=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')
        cat << WTBLOCK
SESSION="\${SESSION_NAME:-$name}"
WORKTREES_DIR="\${${session_var}_WORKTREES:-$worktrees_dir}"
BASE_DIR="\${${session_var}_ROOT:-$project_dir}"

# Resolve project directory — check for a matching worktree when session has a suffix
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
        cat << SIMPLE
SESSION="\${SESSION_NAME:-$name}"
PROJECT_DIR="\${${session_var}_ROOT:-$project_dir}"
SIMPLE
    fi

    cat << 'VALIDATE'

# Validate project directory exists
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory not found: $PROJECT_DIR" >&2
    exit 1
fi

# Check if session already exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$SESSION"
    else
        tmux attach-session -t "$SESSION"
    fi
    exit 0
fi

VALIDATE

    # Generate window commands
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        wname="${win_names[$i]}"
        wcmd="${win_cmds[$i]}"
        wsplit="${win_splits[$i]}"
        wscmd="${win_split_cmds[$i]}"

        # Escape single quotes for safe embedding in generated send-keys commands
        wcmd="${wcmd//\'/\'\\\'\'}"
        wscmd="${wscmd//\'/\'\\\'\'}"

        if [[ $i -eq 0 ]]; then
            printf '# Window 1: %s\n' "$wname"
            printf 'tmux new-session -d -s "$SESSION" -n "%s" -c "$PROJECT_DIR"\n' "$wname"
        else
            printf '\n# Window %d: %s\n' "$((i + 1))" "$wname"
            printf 'tmux new-window -t "$SESSION" -n "%s" -c "$PROJECT_DIR"\n' "$wname"
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

    cat << 'FOOTER'

# Select first window
tmux select-window -t "$SESSION:1"
tmux select-pane -t "$SESSION:1.1"

# Attach to session
if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$SESSION"
else
    tmux attach-session -t "$SESSION"
fi
FOOTER
} > "$target_path"

chmod +x "$target_path"

# Show success
clear
printf "\n\n"
if [[ -n "$edit_source" ]]; then
    printf "  ${GREEN}Launcher updated${NC}\n\n"
else
    printf "  ${GREEN}Launcher created${NC}\n\n"
fi
printf "  ${DIM}%s/%s${NC}\n" "$USER_LAUNCHERS" "$target_name"
printf "  ${DIM}It will appear in the launcher picker (prefix + p)${NC}\n"
sleep 2
