#!/usr/bin/env bash
set -euo pipefail

# static analysis: verify all fzf pickers with search mode use --exact
# for better filtering (exact substring matches rank first)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TMUX_SCRIPTS="$REPO_ROOT/tmux/scripts"
TMUX_CONF="$REPO_ROOT/tmux/tmux.conf.template"

source "$SCRIPT_DIR/_test-helpers.sh"

# ===========================================================================
# scripts with enable-search must use --exact
# ===========================================================================

section "fzf --exact: Scripts with search mode"

# all scripts that toggle search mode via enable-search must use --exact
# so that exact substring matches rank above fuzzy matches
scripts_with_search=(
    "$TMUX_SCRIPTS/launchers/picker.sh"
    "$TMUX_SCRIPTS/launchers/run.sh"
    "$TMUX_SCRIPTS/windows/move.sh"
    "$TMUX_SCRIPTS/instances/connect-nvim.sh"
    "$TMUX_SCRIPTS/utils/pick-url.sh"
)

for script in "${scripts_with_search[@]}"; do
    name=$(basename "$(dirname "$script")")/$(basename "$script")
    if grep -q 'enable-search' "$script" 2>/dev/null; then
        if grep -q '\-\-exact' "$script" 2>/dev/null; then
            pass "$name has --exact with enable-search"
        else
            fail "$name has enable-search but missing --exact"
        fi
    else
        skip "$name has no enable-search (not applicable)"
    fi
done

section "fzf --exact: Active filter scripts (no --disabled)"

# scripts with fzf filtering active from the start (no --disabled)
active_filter_scripts=(
    "$TMUX_SCRIPTS/launchers/new.sh"
)

for script in "${active_filter_scripts[@]}"; do
    name=$(basename "$(dirname "$script")")/$(basename "$script")
    if grep -q '\-\-exact' "$script" 2>/dev/null; then
        pass "$name has --exact for active filtering"
    else
        fail "$name should use --exact for active filtering"
    fi
done

section "fzf --exact: tmux.conf.template"

# count fzf invocations with enable-search in tmux.conf.template
search_count=$(grep -c 'enable-search' "$TMUX_CONF" 2>/dev/null || true)
exact_count=$(grep -c '\-\-exact' "$TMUX_CONF" 2>/dev/null || true)

if [[ "$search_count" -gt 0 ]]; then
    # every fzf call with enable-search should have --exact
    # the exact count should be >= search count (some --exact calls may not have enable-search)
    if [[ "$exact_count" -ge "$search_count" ]]; then
        pass "tmux.conf.template: $exact_count --exact flags cover $search_count enable-search binds"
    else
        fail "tmux.conf.template: only $exact_count --exact flags for $search_count enable-search binds"
    fi
else
    skip "tmux.conf.template has no enable-search binds"
fi

# ===========================================================================
# summary
# ===========================================================================

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
