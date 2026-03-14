#!/usr/bin/env bash
# Shared helpers for gh-dash configuration management.
# Sourced by theme-switch and dash-repo-sync.

# Guard against multiple sourcing
[[ -n "${_DOTFILES_GHDASH_SH_LOADED:-}" ]] && return 0
_DOTFILES_GHDASH_SH_LOADED=1

GHDASH_BASE="${XDG_CONFIG_HOME:-$HOME/.config}/gh-dash/config.base.yml"
GHDASH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/gh-dash/config.yml"
GHDASH_LOCAL="${XDG_CONFIG_HOME:-$HOME/.config}/gh-dash/local.yml"

# Merge local.yml overrides on top of the clean base config.
# Always starts from config.base.yml (template output) to avoid array
# duplication from repeated *+ merges into an already-merged config.yml.
# Returns 0 on success or skip, 1 on merge failure.
# Usage: ghdash_merge_local [--quiet]
ghdash_merge_local() {
    local quiet=false
    [[ "${1:-}" == "--quiet" ]] && quiet=true

    if [[ ! -f "$GHDASH_BASE" ]]; then
        return 0
    fi

    # No local overrides — just promote base to active config
    if [[ ! -f "$GHDASH_LOCAL" ]]; then
        cp "$GHDASH_BASE" "$GHDASH_CONFIG"
        return 0
    fi

    if ! command -v yq >/dev/null 2>&1; then
        [[ "$quiet" != "true" ]] && echo "yq not found — gh-dash local.yml not merged (run: brew install yq)" >&2
        cp "$GHDASH_BASE" "$GHDASH_CONFIG"
        return 0
    fi

    local merge_tmp="${GHDASH_CONFIG}.merge.$$"
    if yq eval-all '. as $item ireduce ({}; . *+ $item)' \
        "$GHDASH_BASE" "$GHDASH_LOCAL" > "$merge_tmp" 2>/dev/null; then
        mv "$merge_tmp" "$GHDASH_CONFIG"
        [[ "$quiet" != "true" ]] && echo "Merged gh-dash local overrides"
        return 0
    else
        rm -f "$merge_tmp"
        [[ "$quiet" != "true" ]] && echo "gh-dash local merge failed, using base config" >&2
        cp "$GHDASH_BASE" "$GHDASH_CONFIG"
        return 1
    fi
}
