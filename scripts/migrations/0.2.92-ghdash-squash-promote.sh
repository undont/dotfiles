#!/usr/bin/env bash
set -euo pipefail

# migration: promote 'm' squash & merge keybinding from gh-dash local.yml to
# the base config (config.yml.template). the 0.2.64 migration originally
# planted this in local.yml as an override; now that it ships in the
# template, leaving the local copy would cause yq's *+ array-merge to
# duplicate the binding

local_yml="${XDG_CONFIG_HOME:-$HOME/.config}/gh-dash/local.yml"

if [[ ! -f "$local_yml" ]]; then
    echo "    No gh-dash local.yml found, skipping"
    exit 0
fi

if ! grep -q 'squash.*delete-branch' "$local_yml" 2>/dev/null; then
    echo "    Squash & merge keybinding not in local.yml, skipping"
    exit 0
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "    yq not installed — leaving local.yml alone (duplicate 'm' binding may appear in gh-dash)" >&2
    echo "    Install yq (brew install yq) and re-run: dotfiles update --force" >&2
    exit 0
fi

# remove the entry matching key:m AND command containing --squash. anything
# else the user added under keybindings.prs is left alone
yq -i 'del(.keybindings.prs[] | select(.key == "m" and ((.command // "") | contains("--squash"))))' "$local_yml"

# clean up empty containers left behind so the file matches the shape new
# users get from local.yml.template
if [[ "$(yq '.keybindings.prs | length' "$local_yml" 2>/dev/null)" == "0" ]]; then
    yq -i 'del(.keybindings.prs)' "$local_yml"
fi
if [[ "$(yq '.keybindings | length' "$local_yml" 2>/dev/null)" == "0" ]]; then
    yq -i 'del(.keybindings)' "$local_yml"
fi

echo "    Removed squash & merge from gh-dash local.yml (now in base config)"
