#!/usr/bin/env bash
set -euo pipefail

# Patch user-owned launchers so tmux session lookups use exact-match
# targets ("=$SESSION") instead of bare names. The wizard template
# generated `tmux has-session -t "$SESSION"`, which silently prefix-
# matched — e.g. launching "foo-15" when "foo-1533" was already
# running would re-attach to foo-1533 instead of creating foo-15.
# Only patches the three lines the wizard template emits; hand-written
# launchers using different variable names are left alone.

USER_LAUNCHERS="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/launchers"

if [[ ! -d "$USER_LAUNCHERS" ]]; then
    echo "    No user launchers directory — skipping launcher prefix-match fix"
    exit 0
fi

shopt -s nullglob
launchers=("$USER_LAUNCHERS"/*)
shopt -u nullglob

if [[ ${#launchers[@]} -eq 0 ]]; then
    echo "    No user launchers found — skipping launcher prefix-match fix"
    exit 0
fi

patched=0
for f in "${launchers[@]}"; do
    [[ -f "$f" ]] || continue
    # Skip if already exact-match (idempotent)
    if ! grep -qE 'tmux (has-session|switch-client|attach-session) -t "\$SESSION"' "$f"; then
        continue
    fi
    sed -i.bak \
        -e 's|tmux has-session -t "\$SESSION"|tmux has-session -t "=$SESSION"|g' \
        -e 's|tmux switch-client -t "\$SESSION"|tmux switch-client -t "=$SESSION"|g' \
        -e 's|tmux attach-session -t "\$SESSION"|tmux attach-session -t "=$SESSION"|g' \
        "$f"
    rm -f "$f.bak"
    echo "    Patched $(basename "$f")"
    patched=$((patched + 1))
done

if [[ $patched -eq 0 ]]; then
    echo "    All launchers already use exact-match — nothing to patch"
else
    echo "    Patched $patched launcher(s) to use tmux exact-match (=\$SESSION)"
fi
