#!/usr/bin/env bash
set -euo pipefail

# source checks on scripts/install/create-symlinks.sh and symlink.sh. the
# script is not run: it would modify the real $HOME

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_SYMLINKS="$DOTFILES_DIR/scripts/install/create-symlinks.sh"
SYMLINK_LIB="$DOTFILES_DIR/scripts/_lib/symlink.sh"

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
symlink_content=$(cat "$SYMLINK_LIB")

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

if [[ "$script_content" == *'_lib/symlink.sh'* ]]; then
    pass "Sources symlink.sh (shared link helpers)"
else
    fail "Should source symlink.sh"
fi

# ═══════════════════════════════════════════════════════════════
# Minimal Preset Symlinks
# ═══════════════════════════════════════════════════════════════

section "Minimal Preset Symlinks"

if [[ "$script_content" == *'.zprofile'* ]]; then
    pass "Links .zprofile"
else
    fail "Should link .zprofile"
fi

if [[ "$script_content" != *'copy_config'*'.p10k.zsh'* ]]; then
    pass "Does not manage .p10k.zsh (user-owned via p10k configure)"
else
    fail "Should not manage .p10k.zsh"
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

if [[ "$script_content" == *'.config/lazygit'* ]]; then
    pass "Links lazygit config (core)"
else
    fail "Should link lazygit config for core preset"
fi

if [[ "$script_content" == *'.config/lazydocker'* ]]; then
    pass "Installs lazydocker config (core)"
else
    fail "Should install lazydocker config for core preset"
fi

if [[ "$script_content" == *'ghostty'* ]]; then
    pass "Handles ghostty config (core)"
else
    fail "Should handle ghostty for core preset"
fi

if [[ "$script_content" == *'.local/launchers'* ]]; then
    pass "Links into ~/.local/launchers (core)"
else
    fail "Should link into ~/.local/launchers for core preset"
fi

if [[ "$script_content" == *'gh-dash'* ]]; then
    pass "Handles gh-dash config directory (core)"
else
    fail "Should handle gh-dash for core preset"
fi

if echo "$script_content" | grep -q 'create_link.*zed/keymap\.json'; then
    pass "Links zed keymap.json (core)"
else
    fail "Should link zed keymap.json for core preset"
fi

if echo "$script_content" | grep -q 'create_link.*zed/tasks\.json'; then
    pass "Links zed tasks.json (core)"
else
    fail "Should link zed tasks.json for core preset"
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
    pass "Installs karabiner config (full)"
else
    fail "Should install karabiner config for full preset"
fi

# ═══════════════════════════════════════════════════════════════
# create_link Function
# ═══════════════════════════════════════════════════════════════

section "create_link Function"

if [[ "$symlink_content" == *'create_link()'* ]]; then
    pass "Defines create_link function (in symlink.sh)"
else
    fail "Should define create_link function in symlink.sh"
fi

if [[ "$symlink_content" == *'record_symlink'* ]]; then
    pass "Records symlinks for rollback"
else
    fail "Should record symlinks for rollback"
fi

if [[ "$symlink_content" == *'ln -sf'* ]]; then
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

if [[ "$symlink_content" == *'.dotfiles-backup'* ]]; then
    pass "Backs up to .dotfiles-backup directory"
else
    fail "Should back up to .dotfiles-backup"
fi

if [[ "$symlink_content" == *'mv "$dest"'* ]]; then
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
# Zsh Configuration
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

if [[ "$symlink_content" == *'copy_config()'* ]]; then
    pass "Defines copy_config function (in symlink.sh)"
else
    fail "Should define copy_config function in symlink.sh"
fi

# this -L test is in create_link; copy_config has none
if [[ "$symlink_content" == *'-L "$dest"'* ]]; then
    pass "symlink.sh tests the destination for a symlink"
else
    fail "symlink.sh should test the destination for a symlink"
fi

if [[ "$symlink_content" == *'cp "$source" "$dest"'* ]]; then
    pass "copy_config copies files (not symlinks)"
else
    fail "copy_config should copy files"
fi

section "Copy-on-Install Configs"

for config in "btop.conf" "karabiner.json" "settings.json"; do
    config_name=$(basename "$config")
    if echo "$script_content" | grep -q "copy_config.*$config_name"; then
        pass "$config_name uses copy_config"
    else
        fail "$config_name should use copy_config (not create_link)"
    fi
done

if echo "$script_content" | grep -q "copy_config.*config.yml"; then
    pass "lazydocker config.yml uses copy_config"
else
    fail "lazydocker config.yml should use copy_config"
fi

if echo "$script_content" | grep -q 'create_link.*hammerspoon.*init\.lua'; then
    pass "Hammerspoon uses create_link for init.lua (layered config)"
else
    fail "Hammerspoon should use create_link for init.lua"
fi

if echo "$script_content" | grep -q 'install_local.*hammerspoon'; then
    pass "Hammerspoon installs local override from template"
else
    fail "Hammerspoon should install local override from template"
fi

section "copy_config Function Behaviour"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

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
# Source File Existence
# ═══════════════════════════════════════════════════════════════

section "Source Files Exist"

declare -a SOURCE_FILES=(
    "zsh/zprofile"
    "zsh/zshrc.template"
    "tmux/local.conf.template"
    "gh-dash/config.yml.template"
    "scripts/dotfiles"
    "zed/keymap.json"
    "zed/tasks.json"
)

for src_file in "${SOURCE_FILES[@]}"; do
    if [[ -e "$DOTFILES_DIR/$src_file" ]]; then
        pass "Source exists: $src_file"
    else
        fail "Source missing: $src_file"
    fi
done

section "Config Source Files Exist"

# copy-on-install sources plus the symlinked hammerspoon and lazygit configs
declare -a COPY_SOURCES=(
    "btop/btop.conf"
    "karabiner/karabiner.json"
    "hammerspoon/init.lua"
    "lazygit/config.yml"
    "lazydocker/config.yml"
    "zed/settings.json"
)

for src_file in "${COPY_SOURCES[@]}"; do
    if [[ -e "$DOTFILES_DIR/$src_file" ]]; then
        pass "Config source exists: $src_file"
    else
        fail "Config source missing: $src_file"
    fi
done

# ═══════════════════════════════════════════════════════════════
# Uninstall Script Consistency
# ═══════════════════════════════════════════════════════════════

section "Uninstall Script - Copy-on-Install Handling"

UNINSTALL="$DOTFILES_DIR/scripts/install/uninstall.sh"
uninstall_content=$(cat "$UNINSTALL")

if echo "$uninstall_content" | grep -A 20 '^SYMLINKS=(' | grep -q 'karabiner'; then
    fail "Uninstall SYMLINKS should not contain karabiner (copy-on-install)"
else
    pass "Uninstall SYMLINKS does not contain karabiner"
fi

if echo "$uninstall_content" | grep -A 20 '^SYMLINKS=(' | grep -q 'hammerspoon'; then
    pass "Uninstall SYMLINKS contains hammerspoon init.lua (layered pattern)"
else
    fail "Uninstall SYMLINKS should contain hammerspoon init.lua symlink"
fi

if echo "$uninstall_content" | grep -A 30 '^SYMLINKS=(' | grep -q 'zed/keymap\.json'; then
    pass "Uninstall SYMLINKS contains zed keymap.json (symlinked)"
else
    fail "Uninstall SYMLINKS should contain zed keymap.json symlink"
fi

if echo "$uninstall_content" | grep -A 30 '^SYMLINKS=(' | grep -q 'zed/settings\.json'; then
    fail "Uninstall SYMLINKS should not contain zed settings.json (copy-on-install)"
else
    pass "Uninstall SYMLINKS does not contain zed settings.json"
fi

for config in "btop" "karabiner" "hammerspoon" "lazygit" "lazydocker" "zed"; do
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
