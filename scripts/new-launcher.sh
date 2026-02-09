#!/usr/bin/env bash
# shellcheck disable=SC2059,SC2016
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# New Launcher Wizard
# ══════════════════════════════════════════════════════════════
# Step-based wizard for creating session launchers.
# Supports ctrl+z to go back a step.
#
# Usage: new-launcher [name]

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=scripts/_lib/colours.sh
source "$SCRIPT_DIR/_lib/colours.sh"

USER_LAUNCHERS="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/launchers"

# Ensure stdin/stdout use terminal (needed when called via fzf become() in a pipeline).
# Security note: this redirects to the controlling terminal, bypassing any pipe isolation.
# Safe here because this script is only invoked interactively from the launcher picker.
exec < /dev/tty > /dev/tty

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
    local title="New Launcher"
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
        prompt="  ${rl_cyan}${label}${rl_nc} [${default}]: "
    else
        prompt="  ${rl_cyan}${label}${rl_nc}: "
    fi

    read -er -p "$prompt" _result || true

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
name="${1:-}"
description=""
instance_mode=""
project_dir=""
num_windows=""
declare -a win_names=()
declare -a win_cmds=()
declare -a win_splits=()
declare -a win_split_cmds=()
default_names=("dev" "edit" "shell")

# Calculate total steps (recalculated after step 4)
total_steps=4
step=1

# If name was provided, start at step 1 (description)
# but validate/sanitise it first
if [[ -n "$name" ]]; then
    # Sanitise: lowercase, strip invalid chars, strip leading dots/dashes, truncate to 64 chars
    name=$(printf '%s' "$name" | tr -c '[:alnum:]_.-' '_' | tr '[:upper:]' '[:lower:]')
    name="${name#"${name%%[[:alnum:]_]*}"}"  # strip leading dots/dashes
    name="${name:0:64}"
    # Block shell reserved words that would shadow commands
    case "$name" in
        test|cd|ls|rm|cp|mv|cat|echo|printf|export|source|exec|eval|exit) name="${name}_launcher" ;;
    esac
    if [[ -f "$USER_LAUNCHERS/$name" ]]; then
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
                r|' '|'') exec "$SCRIPT_DIR/../tmux/scripts/new-launcher-prompt.sh" ;;
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
                # ctrl+z on step 1 — go back to name prompt
                exec "$SCRIPT_DIR/../tmux/scripts/new-launcher-prompt.sh"
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
            # Step 3: Project directory
            draw_header 3 "$total_steps"
            printf "  ${GREEN}Where is the project?${NC}\n\n"
            show_context "Name" "$name"
            show_context "Desc" "$description"
            draw_footer "true"

            local_dir=""
            if ask "Project directory" "${project_dir:-~/src/$name}" local_dir; then
                project_dir="$local_dir"
                # Expand ~ for template but keep $HOME in generated script
                project_dir="${project_dir/#\~\//\$HOME/}"
                step=4
            else
                step=2
            fi
            ;;

        4)
            # Step 4: Number of windows
            draw_header 4 "$total_steps"
            printf "  ${GREEN}How many windows?${NC}\n\n"
            show_context "Name" "$name"
            show_context "Desc" "$description"
            show_context "Dir" "$project_dir"
            draw_footer "true"

            local_num=""
            if ask "Number of windows" "${num_windows:-3}" local_num; then
                num_windows="$local_num"
                # Validate it's a number between 1 and 20
                if ! [[ "$num_windows" =~ ^[0-9]+$ ]] || [[ "$num_windows" -lt 1 ]]; then
                    num_windows=3
                elif [[ "$num_windows" -gt 20 ]]; then
                    num_windows=20
                fi
                total_steps=$((4 + num_windows))
                # Reset window arrays if count changed
                win_names=()
                win_cmds=()
                win_splits=()
                win_split_cmds=()
                step=5
            else
                step=3
            fi
            ;;

        *)
            # Steps 4+: Window configuration
            local_win_idx=$((step - 4))  # 1-based window index

            if [[ $local_win_idx -gt $num_windows ]]; then
                # Past last window — done
                break
            fi

            draw_header "$step" "$total_steps"
            printf "  ${GREEN}Window %d${NC}\n\n" "$local_win_idx"
            show_context "Name" "$name"
            show_context "Desc" "$description"
            show_context "Dir" "$project_dir"

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
# Generate launcher file
# ─────────────────────────────────────────

mkdir -p "$USER_LAUNCHERS"

session_var=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

{
    instance_tag=""
    if [[ "$instance_mode" == "y" ]]; then
        instance_tag=$'\n'"# @instance: prompt"
    fi

    cat << HEADER
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

SESSION="\${SESSION_NAME:-$name}"
PROJECT_DIR="\${${session_var}_ROOT:-$project_dir}"

# Validate project directory exists
if [[ ! -d "\$PROJECT_DIR" ]]; then
    echo "Error: Project directory not found: \$PROJECT_DIR" >&2
    exit 1
fi

# Check if session already exists
if tmux has-session -t "\$SESSION" 2>/dev/null; then
    if [[ -n "\${TMUX:-}" ]]; then
        tmux switch-client -t "\$SESSION"
    else
        tmux attach-session -t "\$SESSION"
    fi
    exit 0
fi

HEADER

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
} > "$USER_LAUNCHERS/$name"

chmod +x "$USER_LAUNCHERS/$name"

# Show success
clear
printf "\n\n"
printf "  ${GREEN}Launcher created${NC}\n\n"
printf "  ${DIM}%s/%s${NC}\n" "$USER_LAUNCHERS" "$name"
printf "  ${DIM}It will appear in the launcher picker (prefix + p)${NC}\n"
sleep 2
