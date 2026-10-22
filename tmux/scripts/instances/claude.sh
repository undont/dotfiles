#!/usr/bin/env bash
# list all running Claude Code instances across all tmux sessions
# emits a 7-line header (logo + state legend) then tab-delimited rows for fzf:
#   {1}=display(shown)  {2}=jump/preview target session:window.pane
# state comes from the agent-state registry (_lib/alerts.sh agent_state_*),
# written by the claude code hooks (scripts/hooks/agent-state.sh); "stuck" is
# derived here from event age plus the pane title losing claude's braille
# spinner, and a stale needs-input flips back to working when the spinner returns

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"
source "$SCRIPT_DIR/../_lib/process.sh"

# a working state older than this with no spinner in the title reads as stuck
STUCK_SECS="${AGENT_STUCK_SECS:-120}"

if ! command -v tmux &>/dev/null; then
    exit 1
fi

if ! tmux list-sessions &>/dev/null; then
    exit 0
fi

declare -A active_claude_ppids
while IFS= read -r pid; do
    active_claude_ppids[$pid]=1
done < <(agent_pane_pids claude)

# pre-fetch window names: "session:window_index window_name"
declare -A window_names
while IFS= read -r wline; do
    key="${wline%% *}"
    name="${wline#* }"
    window_names["$key"]="$name"
done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}')

TAB=$(printf '\t')
now=$(date +%s)

# claude code shows a braille char (U+2800-U+28FF) in the pane title while
# working, and U+2733 (\u2733) when idle. test the raw leading utf-8 bytes (E2 with
# a second byte in A0-A3 is exactly the braille block) rather than a codepoint
# range: a C/POSIX locale collapses [\u2800-\u28ff] to a byte range that also matches \u2733,
# which would silently hide every stuck instance. called only for stale working
# and needs-input panes, so the fork is rare
_title_has_spinner() {
    local hex
    hex=$(printf '%s' "$1" | od -An -tx1 -N2 2>/dev/null | tr -d ' \n')
    case "$hex" in e2a0 | e2a1 | e2a2 | e2a3) return 0 ;; *) return 1 ;; esac
}

# store results; track panes for the stale-state sweep below
claude_panes=()
live_panes="" claude_pane_ids=""

# iterate through all panes in all sessions, sorted by last viewed (most recent
# first). pane_title is last so an embedded tab in it can't shift other fields
while IFS="$TAB" read -r _viewed session window_idx pane_idx pane_id pane_pid title; do
    [[ -n "$pane_id" ]] || continue
    live_panes+="${pane_id}"$'\n'

    [[ -n "${active_claude_ppids[$pane_pid]:-}" ]] || continue
    claude_pane_ids+="${pane_id}"$'\n'

    target="${session}:${window_idx}.${pane_idx}"
    window_name="${window_names["${session}:${window_idx}"]:-}"

    # per-pane label from claude's own pane title, so split panes in one
    # window don't all inherit the active pane's name via automatic-rename.
    # squash tabs (title is untrusted), strip the leading state glyph, and
    # fall back to the window name until claude sets a session title
    label="${title//$TAB/ }"
    label="${label#"${label%%[a-zA-Z0-9]*}"}"
    case "$label" in "" | "Claude Code" | claude) label="$window_name" ;; esac

    state="" age=""
    IFS="$TAB" read -r state age <<<"$(agent_state_read claude "$pane_id" "$now")"
    # stuck: nominally working, no hook event for a while, and the pane title
    # no longer shows the spinner
    if [[ "$state" == "working" ]] && ((age > STUCK_SECS)) && ! _title_has_spinner "$title"; then
        state="stuck"
    fi
    # the reverse: no hook fires when a permission prompt is approved, so
    # needs-input goes stale while the agent runs. a spinner in the title means
    # it's actively working again
    if [[ "$state" == "needs-input" ]] && _title_has_spinner "$title"; then
        state="working"
    fi

    row=$(agent_state_row "$state" "$age" "$target" "$label")
    claude_panes+=("${row}${TAB}${target}")
done < <(tmux list-panes -a -F "#{?#{@pane-viewed},#{@pane-viewed},0}${TAB}#{session_name}${TAB}#{window_index}${TAB}#{pane_index}${TAB}#{pane_id}${TAB}#{pane_pid}${TAB}#{pane_title}" | sort -rn)

# opportunistic GC: drop state files for panes that are gone, and claude files
# for panes whose claude has exited
agent_state_sweep claude "$live_panes" "$claude_pane_ids"

# og Claude Code ghost (Anthropic terracotta: #D77757 = 215;119;87)
# echo ""
# printf "\033[38;2;215;119;87m ▐▛███▜▌\033[0m\n"
# printf "\033[38;2;215;119;87m▝▜█████▛▘\033[0m\n"
# printf "\033[38;2;215;119;87m  ▘▘ ▝▝\033[0m\n"
# echo ""

# add NEW Claude Code ghost at top (Anthropic terracotta: #D77757 = 215;119;87)
echo ""
printf "\033[38;2;215;119;87m ▐▛███▛█\033[0m\n"
printf "\033[38;2;215;119;87m▝▜██████▀\033[0m\n"
printf "\033[38;2;215;119;87m ▝▝   ▝▝\033[0m\n"
echo ""

# state legend (line 6 of the 7-line header)
agent_state_legend stuck
echo ""

# display results (empty list shows just the header)
if [[ ${#claude_panes[@]} -eq 0 ]]; then
    exit 0
fi

# tab-delimited rows below the header
for pane_info in "${claude_panes[@]}"; do
    printf '%s\n' "$pane_info"
done
