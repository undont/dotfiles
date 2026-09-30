#!/usr/bin/env bash
# agent alert clear hook: clear alert when user interacts
# called from agent hook wrappers when the user sends a message or the session
# ends (e.g. Claude Code UserPromptSubmit, SessionEnd)
# passes no target: clear.sh resolves the window from TMUX_PANE, which the
# agent inherits from the pane it runs in. an untargeted resolve would answer
# for the attached client's current window instead

[[ -z "$TMUX" ]] && exit 0

CLEAR_SCRIPT="${HOME}/.tmux/scripts/alerts/clear.sh"

# regular file only, not a symlink
if [[ ! -f "$CLEAR_SCRIPT" ]] || [[ -L "$CLEAR_SCRIPT" ]]; then
    exit 0
fi

bash "$CLEAR_SCRIPT"
