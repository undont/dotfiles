#!/usr/bin/env bash
set -euo pipefail

# Smoke tests for scripts/install/create-symlinks.sh
# Validates script structure and symlink definitions without actually running it
# (Running it would modify real $HOME, so we test structurally)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_SYMLINKS="$DOTFILES_DIR/scripts/install/create-symlinks.sh"

# Source shared test helpers
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

section "Library Dependencies"

script_content=$(cat "$CREATE_SYMLINKS")

if [[ "$script_content" == *'source "$SCRIPT_DIR/../_lib/common.sh"'* ]]; then
    pass "Sources common.sh"
else
    fail "Should source common.sh"
fi

if [[ "$script_content" == *'source "$SCRIPT_DIR/../_lib/rollback.sh"'* ]]; then
    pass "Sources rollback.sh"
else
    fail "Should source rollback.sh"
fi

# ═══════════════════════════════════════════════════════════════
# Minimal Preset Symlinks
# ═══════════════════════════════════════════════════════════════

section "Minimal Preset Symlinks"

# These should be created for all presets (minimal, core, full)
if [[ "$script_content" == *'.zprofile'* ]]; then
    pass "Links .zprofile"
else
    fail "Should link .zprofile"
fi

if [[ "$script_content" == *'.p10k.zsh'* ]]; then
    pass "Links .p10k.zsh"
else
    fail "Should link .p10k.zsh"
fi

if [[ "$script_content" == *'$HOME/.tmux'* ]]; then
    pass "Links tmux directory"
else
    fail "Should link tmux directory"
fi

if [[ "$script_content" == *'.local/bin/dotfiles'* ]]; then
    pass "Links dotfiles CLI"
else
    fail "Should link dotfiles CLI"
fi

# ═══════════════════════════════════════════════════════════════
# Core Preset Symlinks
# ═══════════════════════════════════════════════════════════════

section "Core Preset Symlinks"

if [[ "$script_content" == *'should_install "core"'* ]]; then
    pass "Uses should_install for core gating"
else
    fail "Should use should_install for core"
fi

if [[ "$script_content" == *'.config/nvim'* ]]; then
    pass "Links nvim config (core)"
else
    fail "Should link nvim config for core preset"
fi

if [[ "$script_content" == *'ghostty'* ]]; then
    pass "Handles ghostty config (core)"
else
    fail "Should handle ghostty for core preset"
fi

if [[ "$script_content" == *'.local/launchers'* ]]; then
    pass "Links launchers directory (core)"
else
    fail "Should link launchers for core preset"
fi

if [[ "$script_content" == *'gh-dash'* ]]; then
    pass "Handles gh-dash config directory (core)"
else
    fail "Should handle gh-dash for core preset"
fi

# ═══════════════════════════════════════════════════════════════
# Full Preset Symlinks
# ═══════════════════════════════════════════════════════════════

section "Full Preset Symlinks"

if [[ "$script_content" == *'should_install "full"'* ]]; then
    pass "Uses should_install for full gating"
else
    fail "Should use should_install for full"
fi

if [[ "$script_content" == *'.hammerspoon'* ]]; then
    pass "Links hammerspoon config (full)"
else
    fail "Should link hammerspoon for full preset"
fi

if [[ "$script_content" == *'karabiner.json'* ]]; then
    pass "Links karabiner config (full)"
else
    fail "Should link karabiner for full preset"
fi

# ═══════════════════════════════════════════════════════════════
# create_link Function
# ═══════════════════════════════════════════════════════════════

section "create_link Function"

if [[ "$script_content" == *'create_link()'* ]]; then
    pass "Defines create_link function"
else
    fail "Should define create_link function"
fi

if [[ "$script_content" == *'record_symlink'* ]]; then
    pass "Records symlinks for rollback"
else
    fail "Should record symlinks for rollback"
fi

if [[ "$script_content" == *'ln -sf'* ]]; then
    pass "Uses ln -sf for symlink creation"
else
    fail "Should use ln -sf"
fi

if [[ "$script_content" == *'mkdir -p'* ]]; then
    pass "Creates parent directories"
else
    fail "Should create parent directories"
fi

# ═══════════════════════════════════════════════════════════════
# Backup Behaviour
# ═══════════════════════════════════════════════════════════════

section "Backup on Conflict"

if [[ "$script_content" == *'.dotfiles-backup'* ]]; then
    pass "Backs up to .dotfiles-backup directory"
else
    fail "Should back up to .dotfiles-backup"
fi

if [[ "$script_content" == *'mv "$dest"'* ]]; then
    pass "Moves existing files before symlinking"
else
    fail "Should move existing files before symlinking"
fi

# ═══════════════════════════════════════════════════════════════
# Theme Generation
# ═══════════════════════════════════════════════════════════════

section "Theme Generation Integration"

if [[ "$script_content" == *'theme-switch'* ]]; then
    pass "Invokes theme-switch for config generation"
else
    fail "Should invoke theme-switch"
fi

if [[ "$script_content" == *'.tmux.conf'* ]]; then
    pass "Creates tmux.conf compatibility symlink"
else
    fail "Should create tmux.conf compatibility symlink"
fi

# ═══════════════════════════════════════════════════════════════
# Local Override Files
# ═══════════════════════════════════════════════════════════════

section "Local Override Files"

if [[ "$script_content" == *'local.conf.template'* ]]; then
    pass "Creates tmux local override from template"
else
    fail "Should create tmux local override"
fi

if [[ "$script_content" == *'local.lua.template'* ]]; then
    pass "Creates nvim local override from template"
else
    fail "Should create nvim local override"
fi

if [[ "$script_content" == *'local.template'* ]]; then
    pass "Creates ghostty local override from template"
else
    fail "Should create ghostty local override"
fi

# ═══════════════════════════════════════════════════════════════
# Zsh Migration
# ═══════════════════════════════════════════════════════════════

section "Zsh Configuration Handling"

if [[ "$script_content" == *'zshrc.template'* ]]; then
    pass "Has zshrc template for new installs"
else
    fail "Should have zshrc template path"
fi

if [[ "$script_content" == *'dotfiles.zsh'* ]]; then
    pass "Checks for dotfiles framework sourcing"
else
    fail "Should check for dotfiles.zsh sourcing"
fi

# ═══════════════════════════════════════════════════════════════
# Copy-on-Install Pattern
# ═══════════════════════════════════════════════════════════════

section "copy_config Function"

if [[ "$script_content" == *'copy_config()'* ]]; then
    pass "Defines copy_config function"
else
    fail "Should define copy_config function"
fi

# copy_config should handle three states: symlink, missing, existing
if [[ "$script_content" == *'-L "$dest"'* ]]; then
    pass "copy_config detects existing symlinks"
else
    fail "copy_config should detect existing symlinks"
fi

if [[ "$script_content" == *'cp "$source" "$dest"'* ]]; then
    pass "copy_config copies files (not symlinks)"
else
    fail "copy_config should copy files"
fi

section "Copy-on-Install Configs"

# These configs should use copy_config, NOT create_link
for config in "btop.conf" "karabiner.json" "lazygit/config.yml" "lazydocker/config.yml"; do
    config_name=$(basename "$config")
    # Check the config appears in a copy_config call, not create_link
    if echo "$script_content" | grep -q "copy_config.*$config_name"; then
        pass "$config_name uses copy_config"
    else
        fail "$config_name should use copy_config (not create_link)"
    fi
done

# Hammerspoon uses layered pattern (symlink + local override via migrate_to_symlink)
if echo "$script_content" | grep -q 'migrate_to_symlink.*hammerspoon'; then
    pass "Hammerspoon uses migrate_to_symlink (layered config)"
else
    fail "Hammerspoon should use migrate_to_symlink"
fi

# Hammerspoon should have a local override template
if echo "$script_content" | grep -q 'install_local.*hammerspoon'; then
    pass "Hammerspoon installs local override from template"
else
    fail "Hammerspoon should install local override from template"
fi

section "copy_config Function Behaviour"

# Test copy_config in isolation using a temp directory
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Source only the function (extract it) and needed colour vars
source "$DOTFILES_DIR/scripts/_lib/colours.sh"

# Define minimal stubs for functions used by copy_config
success() { :; }
info() { :; }

# Re-source the function
eval "$(sed -n '/^copy_config()/,/^}/p' "$CREATE_SYMLINKS")"

# Test 1: Copies to new destination
echo "test content" > "$TEST_DIR/source.conf"
copy_config "$TEST_DIR/source.conf" "$TEST_DIR/dest/config.conf"
if [[ -f "$TEST_DIR/dest/config.conf" ]] && [[ ! -L "$TEST_DIR/dest/config.conf" ]]; then
    pass "copy_config creates regular file at new destination"
else
    fail "copy_config should create regular file at new destination"
fi
assert_equals "copy_config copies content correctly" "test content" "$(cat "$TEST_DIR/dest/config.conf")"

# Test 2: Migrates from symlink
ln -sf "$TEST_DIR/source.conf" "$TEST_DIR/symlinked.conf"
copy_config "$TEST_DIR/source.conf" "$TEST_DIR/symlinked.conf"
if [[ -f "$TEST_DIR/symlinked.conf" ]] && [[ ! -L "$TEST_DIR/symlinked.conf" ]]; then
    pass "copy_config migrates symlink to regular file"
else
    fail "copy_config should replace symlink with regular file"
fi

# Test 3: Preserves existing regular file
echo "user customised" > "$TEST_DIR/existing.conf"
copy_config "$TEST_DIR/source.conf" "$TEST_DIR/existing.conf"
assert_equals "copy_config preserves existing file content" "user customised" "$(cat "$TEST_DIR/existing.conf")"

# ═══════════════════════════════════════════════════════════════
# Source File Existence
# ═══════════════════════════════════════════════════════════════

section "Source Files Exist"

# Verify key source files that create-symlinks references exist in the repo
declare -a SOURCE_FILES=(
    "zsh/zprofile"
    "zsh/p10k.zsh"
    "zsh/zshrc.template"
    "tmux/local.conf.template"
    "gh-dash/config.yml.template"
    "scripts/dotfiles"
)

for src_file in "${SOURCE_FILES[@]}"; do
    if [[ -e "$DOTFILES_DIR/$src_file" ]]; then
        pass "Source exists: $src_file"
    else
        fail "Source missing: $src_file"
    fi
done

section "Copy-on-Install Source Files Exist"

# Verify source configs for copy-on-install pattern exist in the repo
declare -a COPY_SOURCES=(
    "btop/btop.conf"
    "karabiner/karabiner.json"
    "hammerspoon/init.lua"
    "lazygit/config.yml"
    "lazydocker/config.yml"
)

for src_file in "${COPY_SOURCES[@]}"; do
    if [[ -e "$DOTFILES_DIR/$src_file" ]]; then
        pass "Copy source exists: $src_file"
    else
        fail "Copy source missing: $src_file"
    fi
done

# ═══════════════════════════════════════════════════════════════
# Uninstall Script Consistency
# ═══════════════════════════════════════════════════════════════

section "Uninstall Script - Copy-on-Install Handling"

UNINSTALL="$DOTFILES_DIR/scripts/install/uninstall.sh"
uninstall_content=$(cat "$UNINSTALL")

# Copy-on-install configs should NOT be in the SYMLINKS array
if echo "$uninstall_content" | grep -A 20 '^SYMLINKS=(' | grep -q 'karabiner'; then
    fail "Uninstall SYMLINKS should not contain karabiner (now copy-on-install)"
else
    pass "Uninstall SYMLINKS does not contain karabiner"
fi

if echo "$uninstall_content" | grep -A 20 '^SYMLINKS=(' | grep -q 'hammerspoon'; then
    fail "Uninstall SYMLINKS should not contain hammerspoon (now copy-on-install)"
else
    pass "Uninstall SYMLINKS does not contain hammerspoon"
fi

# Should have preservation warnings for user-owned configs
for config in "btop" "karabiner" "hammerspoon" "lazygit" "lazydocker"; do
    if [[ "$uninstall_content" == *"personal config"*"$config"* ]] || [[ "$uninstall_content" == *"$config"*"personal config"* ]]; then
        pass "Uninstall preserves $config with warning"
    else
        fail "Uninstall should preserve $config with personal config warning"
    fi
done

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
