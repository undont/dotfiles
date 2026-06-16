#!/usr/bin/env bash
# agent alert clear hook: clear alert when user interacts
# called from agent hook wrappers when the user sends a message
# (e.g. Claude Code UserPromptSubmit)

[[ -z "$TMUX" ]] && exit 0

CLEAR_SCRIPT="${HOME}/.tmux/scripts/alerts/clear.sh"

# validate script exists and is a regular file (not a symlink)
if [[ ! -f "$CLEAR_SCRIPT" ]] || [[ -L "$CLEAR_SCRIPT" ]]; then
    exit 0
fi

# call the tmux clear script (handles validation and timestamp update)
bash "$CLEAR_SCRIPT"
