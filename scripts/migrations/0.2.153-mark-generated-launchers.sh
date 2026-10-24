#!/usr/bin/env bash
set -euo pipefail

# backfill two lines into user launchers the wizard generated before 0.2.153:
#   # @generated                                 below @description/@instance
#   tmux set-option -t "=$SESSION:" @launcher <name>   after tmux new-session
# the marker lets "save session as launcher" offer to update a launcher in
# place (only wizard output can be safely regenerated); the tag lets it tell
# which launcher a running session came from.
# a launcher counts as wizard output only when it carries every line of the
# wizard's skeleton, in either the old inline `${VAR:-default}` or the newer
# `_<NAME>_ROOT_DEFAULT` form. anything else is left untouched and listed

USER_LAUNCHERS="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/launchers"

if [[ ! -d "$USER_LAUNCHERS" ]]; then
    echo "    No user launchers directory — skipping @generated backfill"
    exit 0
fi

# every line the wizard has always emitted, whichever root-dir form it used
is_wizard_output() {
    local f="$1"
    grep -q '^# @description: ' "$f" &&
        grep -qxF '# Help flag handling' "$f" &&
        grep -q ' - Project tmux session launcher$' "$f" &&
        grep -q '^SESSION="\${SESSION_NAME:-' "$f" &&
        grep -q '^tmux new-session -d -s "\$SESSION" -n "' "$f" &&
        grep -qxF '# Select first window' "$f"
}

shopt -s nullglob
launchers=("$USER_LAUNCHERS"/*)
shopt -u nullglob

patched=0
skipped=()
for f in "${launchers[@]}"; do
    [[ -f "$f" ]] || continue
    name="${f##*/}"

    # names go into the generated tag line unquoted; the wizard only ever
    # writes [a-z0-9_.-]
    if [[ ! "$name" =~ ^[a-z0-9_][a-z0-9_.-]*$ ]] || ! is_wizard_output "$f"; then
        skipped+=("$name")
        continue
    fi

    has_marker=0
    has_tag=0
    grep -qxF '# @generated' "$f" && has_marker=1
    grep -q '^tmux set-option -t "=\$SESSION:" @launcher ' "$f" && has_tag=1
    [[ $has_marker -eq 1 && $has_tag -eq 1 ]] && continue

    # the marker goes after @instance when present (as generate_launcher writes
    # it), else after @description; the tag after the first new-session
    tmp="$f.migrating"
    awk -v name="$name" -v add_marker=$((1 - has_marker)) -v add_tag=$((1 - has_tag)) '
        { print }
        add_marker && /^# @description: / {
            if ((getline next_line) > 0) {
                if (next_line ~ /^# @instance: /) { print next_line; print "# @generated" }
                else { print "# @generated"; print next_line }
            } else print "# @generated"
            add_marker = 0
            next
        }
        add_tag && /^tmux new-session -d -s "\$SESSION" -n "/ {
            print "tmux set-option -t \"=$SESSION:\" @launcher " name
            add_tag = 0
        }
    ' "$f" >"$tmp"
    # write back through the original file so its mode and any symlink survive
    cat "$tmp" >"$f"
    rm -f "$tmp"

    echo "    Marked $name"
    patched=$((patched + 1))
done

if [[ $patched -eq 0 ]]; then
    echo "    All wizard launchers already marked — nothing to backfill"
else
    echo "    Marked $patched launcher(s) as wizard-generated (# @generated, @launcher tag)"
fi
if [[ ${#skipped[@]} -gt 0 ]]; then
    echo "    Left ${#skipped[@]} launcher(s) as hand-written: ${skipped[*]}"
    echo "    The wizard won't edit these; \"save session\" can rewrite one after backing it up"
fi

exit 0
