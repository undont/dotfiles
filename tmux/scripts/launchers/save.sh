#!/usr/bin/env bash
# shellcheck disable=SC2059
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# save a session as a launcher
# ══════════════════════════════════════════════════════════════
# captures a session (capture.sh), maps it onto the launcher wizard's model and
# writes it with generate_launcher. one screen: a summary of what will be saved
# above a name prompt
#
#   name = the session's @launcher, when that launcher is wizard-generated:
#          update it in place (keeps its directory, description, instance and
#          worktree settings; replaces the windows)
#   name = anything else: save a new launcher rooted at the session's directory
#
# the wizard's model is one optional side-by-side split per window, so a window
# with more panes keeps its first two, side by side. agent CLIs lose the args
# that pin them to one conversation (claude --resume <id> → claude)
#
# usage: save.sh [session]    (default: the current session)

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=tmux/scripts/_lib/ui.sh
source "$SCRIPT_DIR/../_lib/ui.sh"
# shellcheck source=tmux/scripts/_lib/launcher-gen.sh
source "$SCRIPT_DIR/../_lib/launcher-gen.sh"
# shellcheck source=tmux/scripts/_lib/layout.sh
source "$SCRIPT_DIR/../_lib/layout.sh"

DIM=$'\033[2m'

# filled by build_state_from_capture
cap_session=""
cap_tag=""
cap_dir=""
declare -a save_notes=()

# drop the args that resume one specific agent conversation. a flag without an
# id after it is kept: a bare `claude -r` opens the resume picker
strip_resume_args() {
    local cmd="$1" prog i w
    prog="${cmd%% *}"
    case "${prog##*/}" in
        claude | codex | opencode | copilot) ;;
        *)
            printf '%s' "$cmd"
            return
            ;;
    esac
    local -a words out=()
    read -ra words <<<"$cmd"
    for ((i = 0; i < ${#words[@]}; i++)); do
        w="${words[$i]}"
        case "$w" in
            --resume | -r | --session | -s)
                if [[ -n "${words[i + 1]:-}" && "${words[i + 1]}" != -* ]]; then
                    i=$((i + 1))
                    continue
                fi
                out+=("$w")
                ;;
            --resume=* | --session=*) ;;
            *) out+=("$w") ;;
        esac
    done
    printf '%s' "${out[*]}"
}

# launchers target windows by name ("$SESSION:<name>"), so a name must be
# unambiguous there: no '.' or ':' (pane/window separators), no spaces or
# quotes (the generator writes -n "<name>"), and not all digits (read as an index)
sanitise_window_name() {
    local n
    n=$(printf '%s' "$1" | tr -c '[:alnum:]_-' '-' | sed 's/^-*//; s/-*$//')
    [[ -n "$n" ]] || n="window"
    [[ "$n" =~ ^[0-9]+$ ]] && n="w$n"
    printf '%s' "$n"
}

# ~/... display form of an absolute path
display_path() {
    local p="$1"
    printf '%s' "${p/#$HOME/\~}"
}

# $HOME/... form that generate_launcher expects (accepts absolute or ~ paths)
generator_path() {
    local p="$1"
    p="${p/#\~/$HOME}"
    if [[ "$p" == "$HOME" ]]; then
        printf '%s' '$HOME'
    else
        printf '%s' "${p/#$HOME\//\$HOME/}"
    fi
}

# map capture.sh rows onto the wizard state (win_* arrays) and collect notes
# usage: build_state_from_capture "$(capture.sh session)"
# a pane's directory, relative to the project directory when it's under it,
# else absolute ($HOME form when under home)
pane_dir_relative() {
    local cwd="$1"
    if [[ "$cwd" == "$cap_dir" ]]; then
        printf ''
    elif [[ "$cwd" == "$cap_dir/"* ]]; then
        printf '%s' "${cwd#"$cap_dir"/}"
    elif [[ "$cwd" == "$HOME/"* ]]; then
        printf '%s' "$(generator_path "$cwd")"
    else
        printf '%s' "$cwd"
    fi
}

# map capture.sh rows onto the launcher state (win_* arrays) and collect notes
# usage: build_state_from_capture "$(capture.sh session)"
build_state_from_capture() {
    local rows="$1"
    local kind f1 f2 f3 f4 f5 f6 f7 f8 f9
    local -a order=()
    # per window: name and ordered pane ids; per pane, by "<win>:<id>":
    # geometry, command, note text, directory
    local -A wname=() plist=() p_left=() p_top=() p_w=() p_h=() p_cmd=() p_text=() p_cwd=() seen=()

    win_names=()
    win_cmds=()
    win_splits=()
    win_split_cmds=()
    win_panes=()
    win_layouts=()
    pane_cmds=()
    pane_dirs=()
    save_notes=()

    while IFS=$'\t' read -r kind f1 f2 f3 f4 f5 f6 f7 f8 f9; do
        case "$kind" in
            session) cap_session="$f1" ;;
            launcher) cap_tag="$f1" ;;
            dir) cap_dir="$f1" ;;
            window)
                order+=("$f1")
                wname[$f1]="$f2"
                plist[$f1]=""
                ;;
            pane)
                # f1 window, f2 pane, f3 left, f4 top, f5 width, f6 height,
                # f7 cwd, f8 cmd, f9 note. note text is worded once the
                # window's final name and layout are known
                local w="$f1" id="$f2" cmd="$f8" note="$f9" text="" stripped
                if [[ "$note" == "resumes a specific session" ]]; then
                    stripped=$(strip_resume_args "$cmd")
                    text="'$cmd' → '$stripped'"
                    cmd="$stripped"
                elif [[ -n "$note" ]]; then
                    text="'$cmd' is a $note, may not replay well"
                fi
                plist[$w]="${plist[$w]} $id"
                p_left["$w:$id"]="$f3"
                p_top["$w:$id"]="$f4"
                p_w["$w:$id"]="$f5"
                p_h["$w:$id"]="$f6"
                p_cmd["$w:$id"]="$cmd"
                p_text["$w:$id"]="$text"
                p_cwd["$w:$id"]="$f7"
                ;;
        esac
    done <<<"$rows"

    local w name base n i id holder dir pct new rank
    for w in "${order[@]}"; do
        base=$(sanitise_window_name "${wname[$w]}")
        name="$base"
        n=2
        while [[ -n "${seen[$name]:-}" ]]; do
            name="$base-$n"
            n=$((n + 1))
        done
        seen[$name]=1
        i=$((${#win_names[@]}))
        win_names+=("$name")
        win_panes+=("")
        win_layouts+=("")

        local -a ids=()
        read -ra ids <<<"${plist[$w]}"
        local rects="" steps=""
        for id in "${ids[@]}"; do
            rects+="${id} ${p_left[$w:$id]} ${p_top[$w:$id]} ${p_w[$w:$id]} ${p_h[$w:$id]}"$'\n'
        done
        if [[ ${#ids[@]} -gt 1 ]]; then
            if ! steps=$(printf '%s' "$rects" | layout_splits); then
                save_notes+=("$name window: layout not recognised, saving it with no splits")
            fi
        fi

        # renumber capture ids into creation ranks: pane 1 is the one no step
        # creates, then each step creates the next pane in order
        local -A rank_of=()
        rank=1
        for id in "${ids[@]}"; do
            if [[ -z "$steps" ]] || ! printf '%s\n' "$steps" | awk -v id="$id" '$4 == id { found = 1 } END { exit !found }'; then
                rank_of[$id]=$rank
                rank=$((rank + 1))
            fi
        done
        local renumbered=""
        while IFS=' ' read -r holder dir pct new; do
            [[ -n "$new" ]] || continue
            renumbered+="${rank_of[$holder]} $dir $pct $rank"$'\n'
            rank_of[$new]=$rank
            rank=$((rank + 1))
        done <<<"${steps:-}"

        # a window the wizard's model can describe (one optional side-by-side
        # split, every pane in the project directory) stays simple, so it can
        # still be edited as one; anything else is rich
        local simple=1
        if [[ ${#ids[@]} -gt 2 ]] || printf '%s\n' "${renumbered:-}" | grep -q ' v '; then
            simple=0
        fi

        local k cmd pcwd
        for ((k = 1; k <= ${#ids[@]}; k++)); do
            cmd="${p_cmd[$w:${ids[$((k - 1))]}]:-}"
            pcwd="${p_cwd[$w:${ids[$((k - 1))]}]:-}"
            [[ -n "$(pane_dir_relative "$pcwd")" ]] && simple=0
        done

        if [[ $simple -eq 1 ]]; then
            # ids are in capture order: pane 1 is the top-left one
            win_cmds+=("${p_cmd[$w:${ids[0]}]:-}")
            if [[ ${#ids[@]} -eq 2 ]]; then
                win_splits+=("yes")
                win_split_cmds+=("${p_cmd[$w:${ids[1]}]:-}")
            else
                win_splits+=("no")
                win_split_cmds+=("")
            fi
        else
            win_cmds+=("")
            win_splits+=("no")
            win_split_cmds+=("")
            win_panes[i]=${#ids[@]}
            win_layouts[i]="${renumbered%$'\n'}"
            for ((k = 1; k <= ${#ids[@]}; k++)); do
                id="${ids[$((k - 1))]}"
                pane_cmds["$i:$k"]="${p_cmd[$w:$id]:-}"
                pane_dirs["$i:$k"]="$(pane_dir_relative "${p_cwd[$w:$id]:-}")"
            done
        fi

        # name the panes a note is about by where they sit
        for ((k = 1; k <= ${#ids[@]}; k++)); do
            id="${ids[$((k - 1))]}"
            if [[ -n "${p_text[$w:$id]:-}" ]]; then
                if [[ $simple -eq 1 ]]; then
                    if [[ ${#ids[@]} -eq 2 && "$k" -eq 2 ]]; then
                        save_notes+=("$name window, right pane: ${p_text[$w:$id]}")
                    else
                        save_notes+=("$name window: ${p_text[$w:$id]}")
                    fi
                else
                    save_notes+=("$name window, $(pane_position_label "$i" "$k"): ${p_text[$w:$id]}")
                fi
            fi
        done
    done
}

# the wizard-generated user launcher this session can update in place, if any
update_target() {
    [[ -n "$cap_tag" ]] || return 1
    is_generated_launcher "$USER_LAUNCHERS/$cap_tag" || return 1
    printf '%s' "$cap_tag"
}

# write the current win_* state as a new launcher rooted at the session's dir
write_new_launcher() {
    # a failed capture leaves no windows; never write an empty launcher
    [[ ${#win_names[@]} -gt 0 ]] || return 1
    name="$1"
    description="Saved from the '$cap_session' session"
    instance_mode="n"
    worktree_aware="n"
    worktrees_dir=""
    project_dir=$(generator_path "$cap_dir")
    mkdir -p "$USER_LAUNCHERS"
    generate_launcher >"$USER_LAUNCHERS/$name"
    chmod +x "$USER_LAUNCHERS/$name"
}

# replace the windows of a wizard-generated launcher, keeping everything else
update_launcher() {
    [[ ${#win_names[@]} -gt 0 ]] || return 1
    name="$1"
    local -a keep_names=("${win_names[@]}") keep_cmds=("${win_cmds[@]}")
    local -a keep_splits=("${win_splits[@]}") keep_split_cmds=("${win_split_cmds[@]}")
    local -a keep_panes=("${win_panes[@]}") keep_layouts=("${win_layouts[@]}")
    local -A keep_pane_cmds=() keep_pane_dirs=()
    local key
    for key in "${!pane_cmds[@]}"; do keep_pane_cmds[$key]="${pane_cmds[$key]}"; done
    for key in "${!pane_dirs[@]}"; do keep_pane_dirs[$key]="${pane_dirs[$key]}"; done

    load_existing_launcher "$USER_LAUNCHERS/$name"
    project_dir=$(generator_path "$project_dir")
    [[ -n "$worktrees_dir" ]] && worktrees_dir=$(generator_path "$worktrees_dir")

    win_names=("${keep_names[@]}")
    win_cmds=("${keep_cmds[@]}")
    win_splits=("${keep_splits[@]}")
    win_split_cmds=("${keep_split_cmds[@]}")
    win_panes=("${keep_panes[@]}")
    win_layouts=("${keep_layouts[@]}")
    pane_cmds=()
    pane_dirs=()
    for key in "${!keep_pane_cmds[@]}"; do pane_cmds[$key]="${keep_pane_cmds[$key]}"; done
    for key in "${!keep_pane_dirs[@]}"; do pane_dirs[$key]="${keep_pane_dirs[$key]}"; done

    generate_launcher >"$USER_LAUNCHERS/$name"
}

# summary shown above the name prompt
render_summary() {
    local target="${1:-}" message="${2:-}" i cmd split_cmd k pane_cmds_line
    printf "  ${GREEN}Save session '%s' as a launcher${NC}\n" "$cap_session"
    printf "  ${DIM}dir${NC}  %s\n\n" "$(display_path "$cap_dir")"
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        if [[ -n "${win_panes[$i]:-}" ]]; then
            # a rich window: its panes' commands in creation order
            pane_cmds_line=""
            for ((k = 1; k <= win_panes[i]; k++)); do
                cmd="${pane_cmds["$i:$k"]:-—}"
                pane_cmds_line+="${pane_cmds_line:+ ${DIM}·${NC} }$cmd"
            done
            printf "  ${DIM}%d${NC}  %-12s ${DIM}(%s panes)${NC} %s\n" \
                "$((i + 1))" "${win_names[$i]}" "${win_panes[$i]}" "$pane_cmds_line"
        elif [[ "${win_splits[$i]}" == "yes" ]]; then
            cmd="${win_cmds[$i]:-—}"
            split_cmd="${win_split_cmds[$i]:-—}"
            printf "  ${DIM}%d${NC}  %-12s %s ${DIM}│${NC} %s\n" "$((i + 1))" "${win_names[$i]}" "$cmd" "$split_cmd"
        else
            printf "  ${DIM}%d${NC}  %-12s %s\n" "$((i + 1))" "${win_names[$i]}" "${win_cmds[$i]:-—}"
        fi
    done
    if [[ ${#save_notes[@]} -gt 0 ]]; then
        printf '\n'
        for note in "${save_notes[@]}"; do
            printf "  ${YELLOW}⚠${NC} %s\n" "$note"
        done
    fi
    printf '\n'
    if [[ -n "$target" ]]; then
        printf "  ${DIM}'%s' updates that launcher (keeps its dir, description, instances);${NC}\n" "$target"
        printf "  ${DIM}any other name saves a new one${NC}\n"
    fi
    if [[ -n "$message" ]]; then
        printf "  ${RED}%s${NC}\n" "$message"
    fi
}

main() {
    exec </dev/tty >/dev/tty
    load_fzf_theme
    require_fzf

    local rows
    if ! rows=$("$SCRIPT_DIR/capture.sh" "$@"); then
        show_error "Could not read the session"
        exit 1
    fi
    build_state_from_capture "$rows"

    local target default_name
    target=$(update_target || true)
    if [[ -n "$target" ]]; then
        default_name="$target"
    else
        default_name=$(sanitise_launcher_name "$cap_session")
        if [[ -e "$DOTFILES_LAUNCHERS/$default_name" || -e "$USER_LAUNCHERS/$default_name" ]]; then
            default_name="$default_name-saved"
        fi
    fi

    local message="" query="$default_name" input
    while true; do
        input=$(printf '' | fzf \
            --ansi \
            --print-query \
            --query="$query" \
            --prompt='  Name: ' \
            --header="$(render_summary "$target" "$message")" \
            --header-first \
            --height=100% \
            --layout=reverse \
            --border=rounded \
            --border-label=' ⏎ save · esc cancel ' \
            --border-label-pos=bottom \
            --no-info \
            --pointer=' ' \
            --bind 'enter:print-query' \
            --bind 'esc:abort' \
            2>/dev/null | head -1) || exit 130

        query="$input"
        name=$(sanitise_launcher_name "$input")
        if [[ -z "$name" ]]; then
            message="Enter a name"
            continue
        fi

        if [[ -e "$USER_LAUNCHERS/$name" ]]; then
            if ! is_generated_launcher "$USER_LAUNCHERS/$name"; then
                message="'$name' was written by hand and can't be overwritten, pick another name"
                continue
            fi
            if ! show_visual_confirm "Update launcher" \
                "Replace the windows of '$name' with this session's?\nIts directory, description and instance settings stay."; then
                message=""
                continue
            fi
            update_launcher "$name"
            show_centered_message "Launcher updated" "$USER_LAUNCHERS/$name"
        elif [[ -e "$DOTFILES_LAUNCHERS/$name" ]]; then
            message="'$name' is a built-in launcher, pick another name"
            continue
        else
            write_new_launcher "$name"
            show_centered_message "Launcher saved" "$USER_LAUNCHERS/$name" \
                "It will appear in the launcher picker (prefix + p)"
        fi
        sleep 1
        # tell the launcher picker which launcher to select on return
        if [[ -n "${SAVE_RESULT_FILE:-}" ]]; then
            printf '%s\n' "$name" >"$SAVE_RESULT_FILE"
        fi
        exit 0
    done
}

# run only when executed, so tests can source the helpers above
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
