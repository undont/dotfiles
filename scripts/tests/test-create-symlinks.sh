#!/usr/bin/env bash
set -euo pipefail

# checks on scripts/manifest.conf and create-symlinks.sh. the installer runs
# against a sandbox $HOME with a sandbox tmux socket

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_SYMLINKS="$DOTFILES_DIR/scripts/install/create-symlinks.sh"
SYMLINK_LIB="$DOTFILES_DIR/scripts/_lib/symlink.sh"
MANIFEST="$DOTFILES_DIR/scripts/manifest.conf"

source "$SCRIPT_DIR/_test-helpers.sh"

# ═══════════════════════════════════════════════════════════════
# Script Validation
# ═══════════════════════════════════════════════════════════════

section "Script Exists and Is Valid"

if [[ -f "$CREATE_SYMLINKS" ]]; then
    pass "create-symlinks.sh exists"
else
    fail "create-symlinks.sh not found"
    exit 1
fi

if [[ -x "$CREATE_SYMLINKS" ]]; then
    pass "create-symlinks.sh is executable"
else
    fail "create-symlinks.sh should be executable"
fi

if bash -n "$CREATE_SYMLINKS" 2>/dev/null; then
    pass "create-symlinks.sh passes syntax check"
else
    fail "create-symlinks.sh has syntax errors"
fi

section "Manifest Format"

# shellcheck source=/dev/null
source "$DOTFILES_DIR/scripts/_lib/common.sh"
# shellcheck source=/dev/null
source "$DOTFILES_DIR/scripts/_lib/manifest.sh"

bad_lines=$(grep -vE '^(#|$|\[.+\]$)' "$MANIFEST" | awk 'NF < 5 || NF > 6 { print NR": "$0 }')
assert_equals "every entry has 5 or 6 fields" "" "$bad_lines"

rows=$(manifest_entries)
row_count=$(printf '%s\n' "$rows" | wc -l | tr -d ' ')

ungrouped=$(printf '%s\n' "$rows" | awk -F'\t' '$4 == "" { print $0 }')
assert_equals "every entry is under a [group] header" "" "$ungrouped"

bad_values=$(printf '%s\n' "$rows" | awk -F'\t' '
    $1 !~ /^(link|copy|local|link-generated|sync)$/ { print "kind: "$0; next }
    $2 !~ /^(minimal|core|full)$/ { print "preset: "$0; next }
    $3 !~ /^(any|macos|linux)$/ { print "os: "$0 }')
assert_equals "kind, preset and os take known values" "" "$bad_values"

bad_dests=$(printf '%s\n' "$rows" | awk -F'\t' '$6 !~ /^(~|\$cfg|\$appsupport)\// { print $0 }')
assert_equals "every dest starts with ~/, \$cfg/ or \$appsupport/" "" "$bad_dests"

linux_appsupport=$(printf '%s\n' "$rows" | awk -F'\t' '$3 != "macos" && ($5 ~ /^\$appsupport/ || $6 ~ /^\$appsupport/) { print $0 }')
assert_equals "\$appsupport is only used on macos rows" "" "$linux_appsupport"

if [[ "$row_count" -gt 0 ]]; then
    pass "manifest has $row_count rows"
else
    fail "manifest has no rows"
fi

section "Manifest Sources"

missing_sources=""
while IFS=$'\t' read -r kind _ _ _ source _ _; do
    case "$kind" in
        link | copy | local)
            [[ -e "$DOTFILES_DIR/$source" ]] || missing_sources+="$source "
            ;;
    esac
done <<<"$rows"
assert_equals "every link, copy and local source exists in the repo" "" "$missing_sources"

section "Manifest Destinations"

for os in macos linux; do
    dupes=$(printf '%s\n' "$rows" | awk -F'\t' -v os="$os" '$3 == "any" || $3 == os { print $6 }' | sort | uniq -d)
    assert_equals "no dest is listed twice on $os" "" "$dupes"
done

dupe_keys=$(printf '%s\n' "$rows" | awk -F'\t' '$7 != "-" { print $3"\t"$7 }' | sort | uniq -d)
assert_equals "no local key is listed twice for one os" "" "$dupe_keys"

if ! grep -q '\.p10k\.zsh' "$MANIFEST"; then
    pass ".p10k.zsh is not managed (user-owned via p10k configure)"
else
    fail ".p10k.zsh should not be in the manifest"
fi

section "Sandbox Install"

SANDBOX=$(mktemp -d)
cleanup_sandbox() { rm -rf "$SANDBOX"; }
trap cleanup_sandbox EXIT

run_install() {
    env -u TMUX -u XDG_CONFIG_HOME -u XDG_DATA_HOME \
        HOME="$SANDBOX/home" TMUX_TMPDIR="$SANDBOX" \
        DOTFILES_DIR="$DOTFILES_DIR" DOTFILES_PRESET="$1" \
        bash "$CREATE_SYMLINKS" >"$SANDBOX/install.log" 2>&1
    mkdir -p "$SANDBOX/home/.config/dotfiles"
    echo "$1" >"$SANDBOX/home/.config/dotfiles/preset"
}

# manifest rows for a preset, resolved against the sandbox home
sandbox_rows() {
    HOME="$SANDBOX/home" XDG_CONFIG_HOME="" PRESET="$1" manifest_rows "${@:2}"
}

mkdir -p "$SANDBOX/home"
if run_install full; then
    pass "full install exits 0"
else
    fail "full install failed: $(tail -5 "$SANDBOX/install.log")"
fi

wrong_links=""
while IFS=$'\t' read -r _ _ source dest _; do
    [[ "$(readlink "$dest" 2>/dev/null)" == "$source" ]] || wrong_links+="$dest "
done < <(sandbox_rows full link link-generated)
assert_equals "every full-preset link points at its source" "" "$wrong_links"

missing_files=""
while IFS=$'\t' read -r _ _ _ dest _; do
    [[ -f "$dest" && ! -L "$dest" ]] || missing_files+="$dest "
done < <(sandbox_rows full copy local)
assert_equals "every full-preset copy and local file is a regular file" "" "$missing_files"

# a core link re-pointed by hand survives the preset change
repointed="$SANDBOX/home/.config/lazygit/config.yml"
ln -sf /dev/null "$repointed"

run_install minimal

stale_links=""
while IFS=$'\t' read -r _ _ source dest _; do
    [[ "$dest" == "$repointed" ]] && continue
    [[ -L "$dest" ]] && stale_links+="$dest "
done < <(comm -23 <(sandbox_rows full link link-generated | sort) <(sandbox_rows minimal link link-generated | sort))
assert_equals "switching to minimal removes the full preset's other links" "" "$stale_links"

kept_links=""
while IFS=$'\t' read -r _ _ source dest _; do
    [[ "$(readlink "$dest" 2>/dev/null)" == "$source" ]] || kept_links+="$dest "
done < <(sandbox_rows minimal link link-generated)
assert_equals "switching to minimal keeps the minimal links" "" "$kept_links"

assert_equals "a link re-pointed by hand is kept" "/dev/null" "$(readlink "$repointed")"

if [[ -f "$SANDBOX/home/.config/btop/btop.conf" ]]; then
    pass "switching to minimal keeps copied files"
else
    fail "switching to minimal should keep copied files"
fi

section "copy_config Function Behaviour"

TEST_DIR="$SANDBOX/copy-config"
mkdir -p "$TEST_DIR"

source "$DOTFILES_DIR/scripts/_lib/colours.sh"

success() { :; }
info() { :; }

# only the copy_config definition is evaluated, with its helpers stubbed
eval "$(sed -n '/^copy_config()/,/^}/p' "$SYMLINK_LIB")"

echo "test content" >"$TEST_DIR/source.conf"
copy_config "$TEST_DIR/source.conf" "$TEST_DIR/dest/config.conf"
if [[ -f "$TEST_DIR/dest/config.conf" ]] && [[ ! -L "$TEST_DIR/dest/config.conf" ]]; then
    pass "copy_config creates regular file at new destination"
else
    fail "copy_config should create regular file at new destination"
fi
assert_equals "copy_config copies content correctly" "test content" "$(cat "$TEST_DIR/dest/config.conf")"

ln -sf "$TEST_DIR/source.conf" "$TEST_DIR/symlinked.conf"
copy_config "$TEST_DIR/source.conf" "$TEST_DIR/symlinked.conf"
if [[ -L "$TEST_DIR/symlinked.conf" ]]; then
    pass "copy_config leaves existing symlink untouched"
else
    fail "copy_config should leave existing symlink untouched"
fi

echo "user customised" >"$TEST_DIR/existing.conf"
copy_config "$TEST_DIR/source.conf" "$TEST_DIR/existing.conf"
assert_equals "copy_config preserves existing file content" "user customised" "$(cat "$TEST_DIR/existing.conf")"

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
