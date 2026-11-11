#!/usr/bin/env bash
# copy stdin to the clipboard of the machine running the app, through the home
# server's copy_text action: the app ignores OSC 52 from another host's panes
set -euo pipefail

text=$(cat)
server=()
home=$(rex hosts --json 2>/dev/null | jq -r 'if .home.this_machine then "" else .home.endpoint end')
[[ -n "$home" ]] && server=(-S "$home")
rex "${server[@]}" "do" copy_text "text=$text" >/dev/null
