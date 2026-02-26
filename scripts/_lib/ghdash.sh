#!/usr/bin/env bash
# Shared helpers for gh-dash configuration management.
# Sourced by theme-switch and dash-repo-sync.

GHDASH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/gh-dash/config.yml"
GHDASH_LOCAL="${XDG_CONFIG_HOME:-$HOME/.config}/gh-dash/local.yml"

# Deep-merge local.yml overrides into the active gh-dash config.
# Returns 0 on success or skip, 1 on merge failure.
# Usage: ghdash_merge_local [--quiet]
ghdash_merge_local() {
    local quiet=false
    [[ "${1:-}" == "--quiet" ]] && quiet=true

    if [[ ! -f "$GHDASH_CONFIG" ]]; then
        return 0
    fi

    if [[ ! -f "$GHDASH_LOCAL" ]]; then
        return 0
    fi

    if ! command -v yq >/dev/null 2>&1; then
        [[ "$quiet" != "true" ]] && echo "yq not found — gh-dash local.yml not merged (run: brew install yq)" >&2
        return 0
    fi

    local merge_tmp="${GHDASH_CONFIG}.merge.$$"
    if yq eval-all '. as $item ireduce ({}; . *+ $item)' \
        "$GHDASH_CONFIG" "$GHDASH_LOCAL" > "$merge_tmp" 2>/dev/null; then
        mv "$merge_tmp" "$GHDASH_CONFIG"
        [[ "$quiet" != "true" ]] && echo "Merged gh-dash local overrides"
        return 0
    else
        rm -f "$merge_tmp"
        [[ "$quiet" != "true" ]] && echo "gh-dash local merge failed, using base config" >&2
        return 1
    fi
}
