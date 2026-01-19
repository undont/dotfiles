#!/usr/bin/env bash
# Visual confirmation dialog for tmux
# Usage: tmux-confirm.sh "Title" "Message" "command to execute on yes"

set -euo pipefail

TITLE="$1"
MESSAGE="$2"
COMMAND="$3"

# Colours
PURPLE=$'\033[38;5;141m'
GREY=$'\033[38;5;60m'
NC=$'\033[0m'

# Calculate centering
TERM_HEIGHT=$(tput lines)
TERM_WIDTH=$(tput cols)

# Calculate box dimensions
TITLE_LEN=${#TITLE}
MSG_LEN=${#MESSAGE}
MAX_LEN=$((TITLE_LEN > MSG_LEN ? TITLE_LEN : MSG_LEN))
BOX_WIDTH=$((MAX_LEN + 4))

# Vertical padding
V_PAD=$(( (TERM_HEIGHT - 6) / 2 ))
[[ $V_PAD -lt 0 ]] && V_PAD=0

# Horizontal padding
H_PAD=$(( (TERM_WIDTH - BOX_WIDTH) / 2 ))
[[ $H_PAD -lt 0 ]] && H_PAD=0

PAD=$(printf '%*s' "$H_PAD" '')

# Clear screen and display centred message
clear

# Vertical padding
for ((i=0; i<V_PAD; i++)); do
    printf '\n'
done

# Title
printf '%s%s%s%s\n' "$PAD" "$PURPLE" "$TITLE" "$NC"
printf '%s%s%s%s\n' "$PAD" "$GREY" "$(printf '%.0s─' $(seq 1 ${#TITLE}))" "$NC"
printf '\n'

# Message
printf '%s%s\n' "$PAD" "$MESSAGE"
printf '\n'

# Prompt
printf '%s%sPress %sy%s to confirm, any other key to cancel%s' "$PAD" "$GREY" "$PURPLE" "$GREY" "$NC"

# Read single character
read -rsn1 response

# Execute command if confirmed
if [[ "$response" =~ ^[Yy]$ ]]; then
    eval "$COMMAND"
    exit 0
fi

exit 1
