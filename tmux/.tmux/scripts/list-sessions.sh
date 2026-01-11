#!/bin/bash
# List tmux sessions sorted by activity (most recent first)
# Used by the session switcher (prefix + s)

tmux list-sessions -F '#{session_activity} #{session_name}' | sort -rn | cut -d' ' -f2-
