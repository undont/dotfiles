#!/usr/bin/env bash
set -euo pipefail

# Unit tests for dotfiles CLI
# Tests the dotfiles command wrapper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_CLI="$SCRIPT_DIR/../dotfiles"
DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source shared test helpers (colours, pass/fail/skip/section, assertions)
source "$SCRIPT_DIR/_test-helpers.sh"

# ===========================================================================
# Tests
# ===========================================================================

section "Script Exists and Is Executable"

if [[ -f "$DOTFILES_CLI" ]]; then
    pass "dotfiles CLI exists"
else
    fail "dotfiles CLI not found at $DOTFILES_CLI"
    exit 1
fi

if [[ -x "$DOTFILES_CLI" ]]; then
    pass "dotfiles CLI is executable"
else
    fail "dotfiles CLI is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$DOTFILES_CLI" 2>/dev/null; then
        pass "dotfiles CLI passes shellcheck"
    else
        fail "dotfiles CLI has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Help Command"

help_output=$("$DOTFILES_CLI" help 2>&1) || true

if [[ "$help_output" == *"Usage:"* ]]; then
    pass "help shows usage"
else
    fail "help should show usage"
fi

if [[ "$help_output" == *"update"* ]]; then
    pass "help mentions update command"
else
    fail "help should mention update command"
fi

if [[ "$help_output" == *"status"* ]]; then
    pass "help mentions status command"
else
    fail "help should mention status command"
fi

if [[ "$help_output" == *"health"* ]]; then
    pass "help mentions health command"
else
    fail "help should mention health command"
fi

if [[ "$help_output" == *"edit"* ]]; then
    pass "help mentions edit command"
else
    fail "help should mention edit command"
fi

if [[ "$help_output" == *"cd"* ]]; then
    pass "help mentions cd command"
else
    fail "help should mention cd command"
fi

if [[ "$help_output" == *"theme"* ]]; then
    pass "help mentions theme command"
else
    fail "help should mention theme command"
fi

if [[ "$help_output" == *"notes"* ]]; then
    pass "help mentions notes command"
else
    fail "help should mention notes command"
fi

if [[ "$help_output" == *"links"* ]]; then
    pass "help mentions links command"
else
    fail "help should mention links command"
fi

# Test --help flag
help_flag_output=$("$DOTFILES_CLI" --help 2>&1) || true
if [[ "$help_flag_output" == *"Usage:"* ]]; then
    pass "--help flag works"
else
    fail "--help flag should show usage"
fi

section "CD Command"

cd_output=$("$DOTFILES_CLI" cd 2>&1) || true

if [[ "$cd_output" == *"dotfiles"* ]]; then
    pass "cd command returns dotfiles path"
else
    fail "cd command should return dotfiles path"
fi

if [[ -d "$cd_output" ]]; then
    pass "cd command returns valid directory"
else
    fail "cd command should return valid directory"
fi

section "Unknown Command Handling"

unknown_output=$("$DOTFILES_CLI" nonexistent_command_12345 2>&1) || true

if echo "$unknown_output" | grep -q "Unknown command"; then
    pass "Shows error for unknown command"
else
    fail "Should show error for unknown command"
fi

if echo "$unknown_output" | grep -q "Usage:"; then
    pass "Shows usage after unknown command error"
else
    fail "Should show usage after unknown command error"
fi

section "Script Structure"

script_content=$(cat "$DOTFILES_CLI")

# Check for required functions
if [[ "$script_content" == *"cmd_update()"* ]]; then
    pass "cmd_update function defined"
else
    fail "cmd_update function not found"
fi

if [[ "$script_content" == *"cmd_status()"* ]]; then
    pass "cmd_status function defined"
else
    fail "cmd_status function not found"
fi

if [[ "$script_content" == *"cmd_health()"* ]]; then
    pass "cmd_health function defined"
else
    fail "cmd_health function not found"
fi

if [[ "$script_content" == *"cmd_notes()"* ]]; then
    pass "cmd_notes function defined"
else
    fail "cmd_notes function not found"
fi

if [[ "$script_content" == *"cmd_links()"* ]]; then
    pass "cmd_links function defined"
else
    fail "cmd_links function not found"
fi

if [[ "$script_content" == *"_changelog_local_version()"* ]]; then
    pass "_changelog_local_version helper defined"
else
    fail "_changelog_local_version helper not found"
fi

if [[ "$script_content" == *"_changelog_incoming()"* ]]; then
    pass "_changelog_incoming helper defined"
else
    fail "_changelog_incoming helper not found"
fi

if [[ "$script_content" == *"_changelog_colorise()"* ]]; then
    pass "_changelog_colorise helper defined"
else
    fail "_changelog_colorise helper not found"
fi

if [[ "$script_content" == *"get_preset()"* ]]; then
    pass "get_preset function defined"
else
    fail "get_preset function not found"
fi

if [[ "$script_content" == *"get_remote_branch()"* ]]; then
    pass "get_remote_branch function defined"
else
    fail "get_remote_branch function not found"
fi

section "Preset Configuration"

# Check that preset file path uses XDG
if [[ "$script_content" == *'XDG_CONFIG_HOME'* ]]; then
    pass "Uses XDG_CONFIG_HOME for config directory"
else
    fail "Should use XDG_CONFIG_HOME"
fi

# Check fallback to 'full' preset
if [[ "$script_content" == *'"full"'* ]]; then
    pass "Falls back to 'full' preset"
else
    fail "Should fall back to 'full' preset"
fi

section "Sources Common Library"

if [[ "$script_content" == *'source "$DOTFILES_DIR/scripts/_lib/common.sh"'* ]]; then
    pass "Sources common.sh library"
else
    fail "Should source common.sh library"
fi

section "Install.sh Preset Saving"

install_script="$DOTFILES_DIR/install.sh"
if [[ -f "$install_script" ]]; then
    install_content=$(cat "$install_script")

    if [[ "$install_content" == *'echo "$PRESET" >'* ]] || [[ "$install_content" == *'$PRESET_CONFIG_DIR/preset'* ]]; then
        pass "install.sh saves preset to config file"
    else
        fail "install.sh should save preset to config file"
    fi

    if [[ "$install_content" == *"Step 9"* ]]; then
        pass "install.sh has Step 9 for saving preset"
    else
        fail "install.sh should have Step 9 for saving preset"
    fi
else
    skip "install.sh not found"
fi

section "Create Symlinks Integration"

symlinks_script="$DOTFILES_DIR/scripts/install/create-symlinks.sh"
if [[ -f "$symlinks_script" ]]; then
    symlinks_content=$(cat "$symlinks_script")

    if [[ "$symlinks_content" == *'scripts/dotfiles'* ]]; then
        pass "create-symlinks.sh links dotfiles CLI"
    else
        fail "create-symlinks.sh should link dotfiles CLI"
    fi

    if [[ "$symlinks_content" == *'$HOME/.local/bin/dotfiles'* ]]; then
        pass "dotfiles CLI linked to ~/.local/bin/dotfiles"
    else
        fail "dotfiles CLI should be linked to ~/.local/bin/dotfiles"
    fi
else
    skip "create-symlinks.sh not found"
fi

section "Create Symlinks - ShellCheck"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$symlinks_script" 2>/dev/null; then
        pass "create-symlinks.sh passes shellcheck"
    else
        fail "create-symlinks.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Create Symlinks - Structure"

if [[ "$symlinks_content" == *'source "$SCRIPT_DIR/../_lib/common.sh"'* ]]; then
    pass "create-symlinks sources common.sh"
else
    fail "create-symlinks should source common.sh"
fi

if [[ "$symlinks_content" == *'source "$SCRIPT_DIR/../_lib/rollback.sh"'* ]]; then
    pass "create-symlinks sources rollback library"
else
    fail "create-symlinks should source rollback library"
fi

if [[ "$symlinks_content" == *'create_link()'* ]]; then
    pass "create-symlinks defines create_link function"
else
    fail "create-symlinks should define create_link function"
fi

if [[ "$symlinks_content" == *'record_symlink'* ]]; then
    pass "create-symlinks records symlinks for rollback"
else
    fail "create-symlinks should record symlinks for rollback"
fi

section "Create Symlinks - Core Configs"

if [[ "$symlinks_content" == *'.zshrc'* ]]; then
    pass "create-symlinks links .zshrc"
else
    fail "create-symlinks should link .zshrc"
fi

if [[ "$symlinks_content" == *'.zprofile'* ]]; then
    pass "create-symlinks links .zprofile"
else
    fail "create-symlinks should link .zprofile"
fi

if [[ "$symlinks_content" == *'.p10k.zsh'* ]]; then
    pass "create-symlinks links .p10k.zsh"
else
    fail "create-symlinks should link .p10k.zsh"
fi

if [[ "$symlinks_content" == *'.tmux.conf'* ]]; then
    pass "create-symlinks links .tmux.conf"
else
    fail "create-symlinks should link .tmux.conf"
fi

section "Create Symlinks - Ghostty and Karabiner"

if [[ "$symlinks_content" == *'ghostty/config'* ]]; then
    pass "create-symlinks links ghostty/config"
else
    fail "create-symlinks should link ghostty/config"
fi

if [[ "$symlinks_content" == *'karabiner/karabiner.json'* ]]; then
    pass "create-symlinks links karabiner.json"
else
    fail "create-symlinks should link karabiner.json"
fi

section "Create Symlinks - Launchers"

if [[ "$symlinks_content" == *'.local/launchers'* ]]; then
    pass "create-symlinks creates launchers directory"
else
    fail "create-symlinks should create launchers directory"
fi

if [[ "$symlinks_content" == *'launchers/dev'* ]]; then
    pass "create-symlinks links dev launcher"
else
    fail "create-symlinks should link dev launcher"
fi


section "Create Symlinks - Preset Hierarchy"

if [[ "$symlinks_content" == *'should_install "core"'* ]]; then
    pass "create-symlinks uses should_install for core"
else
    fail "create-symlinks should use should_install for core"
fi

if [[ "$symlinks_content" == *'should_install "full"'* ]]; then
    pass "create-symlinks uses should_install for full"
else
    fail "create-symlinks should use should_install for full"
fi

# ===========================================================================
# Theme Command Tests
# ===========================================================================

section "Theme Command - Basic Functionality"

# Test theme list
theme_list_output=$("$DOTFILES_CLI" theme list 2>&1) || true
if [[ "$theme_list_output" == *"Available themes"* ]]; then
    pass "theme list shows available themes header"
else
    fail "theme list should show available themes header"
fi

if [[ "$theme_list_output" == *"dracula"* ]]; then
    pass "theme list includes dracula theme"
else
    fail "theme list should include dracula theme"
fi

# Test theme current
theme_current_output=$("$DOTFILES_CLI" theme current 2>&1) || true
if [[ "$theme_current_output" == *"Current theme"* ]]; then
    pass "theme current shows current theme"
else
    fail "theme current should show current theme"
fi

# Test theme command in help output
if [[ "$help_output" == *"dotfiles theme"* ]]; then
    pass "help documents theme command usage"
else
    fail "help should document theme command usage"
fi

section "Theme Command - Script Structure"

# Check that cmd_theme function is defined
if [[ "$script_content" == *"cmd_theme()"* ]]; then
    pass "cmd_theme function defined"
else
    fail "cmd_theme function not found"
fi

# Check that theme command calls theme-switch script
if [[ "$script_content" == *'theme-switch'* ]]; then
    pass "theme command uses theme-switch script"
else
    fail "theme command should use theme-switch script"
fi

# Check that theme command is routed in main case statement
if [[ "$script_content" == *'theme|'* ]]; then
    pass "theme command is handled in main case statement"
else
    fail "theme command should be in main case statement"
fi

section "Theme Command - Integration"

# Verify theme-switch script exists
theme_switch_script="$DOTFILES_DIR/scripts/theme-switch"
if [[ -f "$theme_switch_script" ]]; then
    pass "theme-switch script exists"
else
    fail "theme-switch script should exist"
fi

if [[ -x "$theme_switch_script" ]]; then
    pass "theme-switch script is executable"
else
    fail "theme-switch script should be executable"
fi

# Verify themes directory exists
themes_dir="$DOTFILES_DIR/themes"
if [[ -d "$themes_dir" ]]; then
    pass "themes directory exists"
else
    fail "themes directory should exist"
fi

# Verify at least one theme file exists
if ls "$themes_dir"/*.theme &>/dev/null; then
    pass "theme files exist in themes directory"
else
    fail "at least one theme file should exist"
fi

# ===========================================================================
# Uninstall Script Tests
# ===========================================================================

UNINSTALL_SCRIPT="$DOTFILES_DIR/scripts/install/uninstall.sh"

section "Uninstall Script - Existence and Executable"

if [[ -f "$UNINSTALL_SCRIPT" ]]; then
    pass "uninstall.sh exists"
else
    fail "uninstall.sh not found at $UNINSTALL_SCRIPT"
fi

if [[ -x "$UNINSTALL_SCRIPT" ]]; then
    pass "uninstall.sh is executable"
else
    fail "uninstall.sh is not executable"
fi

section "Uninstall Script - ShellCheck"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$UNINSTALL_SCRIPT" 2>/dev/null; then
        pass "uninstall.sh passes shellcheck"
    else
        fail "uninstall.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Uninstall Script - Help"

uninstall_help=$("$UNINSTALL_SCRIPT" --help 2>&1) || true

if [[ "$uninstall_help" == *"USAGE:"* ]]; then
    pass "uninstall help shows USAGE section"
else
    fail "uninstall help should show USAGE section"
fi

if [[ "$uninstall_help" == *"--restore-backup"* ]]; then
    pass "uninstall help documents --restore-backup"
else
    fail "uninstall help should document --restore-backup"
fi

if [[ "$uninstall_help" == *"--remove-brew-packages"* ]]; then
    pass "uninstall help documents --remove-brew-packages"
else
    fail "uninstall help should document --remove-brew-packages"
fi

section "Uninstall Script - Structure"

uninstall_content=$(cat "$UNINSTALL_SCRIPT")

if [[ "$uninstall_content" == *'SYMLINKS=('* ]]; then
    pass "uninstall defines SYMLINKS array"
else
    fail "uninstall should define SYMLINKS array"
fi

if [[ "$uninstall_content" == *'$HOME/.zshrc'* ]]; then
    pass "uninstall includes .zshrc in symlinks"
else
    fail "uninstall should include .zshrc"
fi

if [[ "$uninstall_content" == *'$HOME/.config/nvim'* ]]; then
    pass "uninstall includes nvim config"
else
    fail "uninstall should include nvim config"
fi

if [[ "$uninstall_content" == *'.zprofile'* ]]; then
    pass "uninstall includes .zprofile"
else
    fail "uninstall should include .zprofile"
fi

if [[ "$uninstall_content" == *'.p10k.zsh'* ]]; then
    pass "uninstall includes .p10k.zsh"
else
    fail "uninstall should include .p10k.zsh"
fi

if [[ "$uninstall_content" == *'ghostty/config'* ]]; then
    pass "uninstall includes ghostty/config"
else
    fail "uninstall should include ghostty/config"
fi

if [[ "$uninstall_content" == *'karabiner.json'* ]]; then
    pass "uninstall includes karabiner.json"
else
    fail "uninstall should include karabiner.json"
fi

if [[ "$uninstall_content" == *'.local/launchers'* ]]; then
    pass "uninstall includes launchers"
else
    fail "uninstall should include launchers"
fi

if [[ "$uninstall_content" == *'-L "$link"'* ]]; then
    pass "uninstall checks symlink before removal"
else
    fail "uninstall should check symlink before removal"
fi

if [[ "$uninstall_content" == *'confirm'* ]]; then
    pass "uninstall uses confirmation prompt"
else
    fail "uninstall should use confirmation prompt"
fi

if [[ "$uninstall_content" == *'source "$SCRIPT_DIR/../_lib/rollback.sh"'* ]]; then
    pass "uninstall sources rollback.sh for restore_from_backup"
else
    fail "uninstall should source rollback.sh"
fi

if [[ "$uninstall_content" == *'source "$SCRIPT_DIR/../_lib/common.sh"'* ]]; then
    pass "uninstall sources common.sh"
else
    fail "uninstall should source common.sh"
fi

section "Uninstall Script - Brew Package Removal"

if [[ "$uninstall_content" == *'source "$SCRIPT_DIR/../_lib/brewfile.sh"'* ]]; then
    pass "uninstall sources brewfile.sh for filter_brewfile"
else
    fail "uninstall should source brewfile.sh"
fi

if [[ "$uninstall_content" == *'FILTERED_BREWFILE'* ]]; then
    pass "uninstall creates filtered Brewfile"
else
    fail "uninstall should create filtered Brewfile"
fi

# Check that uninstall calls create_filtered_brewfile (from brewfile.sh)
if [[ "$uninstall_content" == *'create_filtered_brewfile'* ]]; then
    pass "uninstall calls create_filtered_brewfile helper"
else
    fail "uninstall should call create_filtered_brewfile"
fi

if [[ "$uninstall_content" == *'brew uninstall'* ]]; then
    pass "uninstall removes brew packages"
else
    fail "uninstall should remove brew packages"
fi

if [[ "$uninstall_content" == *'brew uninstall --cask'* ]]; then
    pass "uninstall removes cask packages"
else
    fail "uninstall should remove cask packages"
fi

section "Uninstall Script - Cleanup"

if [[ "$uninstall_content" == *'XDG_CONFIG_HOME'* ]]; then
    pass "uninstall uses XDG_CONFIG_HOME"
else
    fail "uninstall should use XDG_CONFIG_HOME"
fi

if [[ "$uninstall_content" == *'dotfiles/preset'* ]]; then
    pass "uninstall handles preset config file"
else
    fail "uninstall should handle preset config file"
fi

if [[ "$uninstall_content" == *'secrets.zsh'* ]]; then
    pass "uninstall handles secrets file"
else
    fail "uninstall should handle secrets file"
fi

if [[ "$uninstall_content" == *'-s "$ZSH_CONFIG_DIR/secrets.zsh"'* ]]; then
    pass "uninstall checks if secrets file has content"
else
    fail "uninstall should check secrets file content"
fi

if [[ "$uninstall_content" == *'.tmux/plugins/tpm'* ]]; then
    pass "uninstall handles TPM cleanup"
else
    fail "uninstall should handle TPM cleanup"
fi

if [[ "$uninstall_content" == *'rmdir'* ]]; then
    pass "uninstall cleans up empty directories"
else
    fail "uninstall should clean up empty directories"
fi

section "Uninstall Script - Safety"

if [[ "$uninstall_content" == *'readlink "$link"'* ]]; then
    pass "uninstall shows symlink targets before removal"
else
    fail "uninstall should show symlink targets"
fi

if [[ "$uninstall_content" == *'exists but not a symlink'* ]]; then
    pass "uninstall warns about non-symlink files"
else
    fail "uninstall should warn about non-symlink files"
fi

if [[ "$uninstall_content" == *'--ignore-dependencies'* ]]; then
    pass "uninstall uses --ignore-dependencies for brew"
else
    fail "uninstall should use --ignore-dependencies"
fi

if [[ "$uninstall_content" == *'Backups are preserved'* ]]; then
    pass "uninstall reminds about preserved backups"
else
    fail "uninstall should remind about preserved backups"
fi

# ===========================================================================
# Rollback Script Tests
# ===========================================================================

ROLLBACK_SCRIPT="$DOTFILES_DIR/scripts/install/rollback.sh"

section "Rollback Script - Existence and Executable"

if [[ -f "$ROLLBACK_SCRIPT" ]]; then
    pass "rollback.sh exists"
else
    fail "rollback.sh not found"
fi

if [[ -x "$ROLLBACK_SCRIPT" ]]; then
    pass "rollback.sh is executable"
else
    fail "rollback.sh is not executable"
fi

section "Rollback Script - ShellCheck"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$ROLLBACK_SCRIPT" 2>/dev/null; then
        pass "rollback.sh passes shellcheck"
    else
        fail "rollback.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Rollback Script - Structure"

rollback_content=$(cat "$ROLLBACK_SCRIPT")

if [[ "$rollback_content" == *'source "$SCRIPT_DIR/../_lib/common.sh"'* ]]; then
    pass "rollback sources common.sh"
else
    fail "rollback should source common.sh"
fi

if [[ "$rollback_content" == *'source "$SCRIPT_DIR/../_lib/rollback.sh"'* ]]; then
    pass "rollback sources rollback library"
else
    fail "rollback should source rollback library"
fi

if [[ "$rollback_content" == *'has_rollback_state'* ]]; then
    pass "rollback checks for rollback state"
else
    fail "rollback should check for rollback state"
fi

if [[ "$rollback_content" == *'perform_rollback'* ]]; then
    pass "rollback calls perform_rollback"
else
    fail "rollback should call perform_rollback"
fi

if [[ "$rollback_content" == *'--force'* ]]; then
    pass "rollback supports --force flag"
else
    fail "rollback should support --force flag"
fi

if [[ "$rollback_content" == *'confirm'* ]]; then
    pass "rollback uses confirmation prompt"
else
    fail "rollback should use confirmation prompt"
fi

if [[ "$rollback_content" == *'.dotfiles-backup'* ]]; then
    pass "rollback references backup directory"
else
    fail "rollback should reference backup directory"
fi

if [[ "$rollback_content" == *'restore_from_backup'* ]]; then
    pass "rollback can restore from backup without state"
else
    fail "rollback should restore from backup without state"
fi

# ===========================================================================
# Rollback Library Tests
# ===========================================================================

ROLLBACK_LIB="$DOTFILES_DIR/scripts/_lib/rollback.sh"

section "Rollback Library - Existence"

if [[ -f "$ROLLBACK_LIB" ]]; then
    pass "rollback library exists"
else
    fail "rollback library not found"
fi

section "Rollback Library - ShellCheck"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$ROLLBACK_LIB" 2>/dev/null; then
        pass "rollback library passes shellcheck"
    else
        fail "rollback library has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Rollback Library - Functions"

rollback_lib_content=$(cat "$ROLLBACK_LIB")

if [[ "$rollback_lib_content" == *'init_rollback_state()'* ]]; then
    pass "rollback lib defines init_rollback_state"
else
    fail "rollback lib should define init_rollback_state"
fi

if [[ "$rollback_lib_content" == *'record_step()'* ]]; then
    pass "rollback lib defines record_step"
else
    fail "rollback lib should define record_step"
fi

if [[ "$rollback_lib_content" == *'get_last_step()'* ]]; then
    pass "rollback lib defines get_last_step"
else
    fail "rollback lib should define get_last_step"
fi

if [[ "$rollback_lib_content" == *'record_backup_location()'* ]]; then
    pass "rollback lib defines record_backup_location"
else
    fail "rollback lib should define record_backup_location"
fi

if [[ "$rollback_lib_content" == *'get_backup_location()'* ]]; then
    pass "rollback lib defines get_backup_location"
else
    fail "rollback lib should define get_backup_location"
fi

if [[ "$rollback_lib_content" == *'record_symlink()'* ]]; then
    pass "rollback lib defines record_symlink"
else
    fail "rollback lib should define record_symlink"
fi

if [[ "$rollback_lib_content" == *'get_created_symlinks()'* ]]; then
    pass "rollback lib defines get_created_symlinks"
else
    fail "rollback lib should define get_created_symlinks"
fi

if [[ "$rollback_lib_content" == *'has_rollback_state()'* ]]; then
    pass "rollback lib defines has_rollback_state"
else
    fail "rollback lib should define has_rollback_state"
fi

if [[ "$rollback_lib_content" == *'cleanup_rollback_state()'* ]]; then
    pass "rollback lib defines cleanup_rollback_state"
else
    fail "rollback lib should define cleanup_rollback_state"
fi

if [[ "$rollback_lib_content" == *'restore_from_backup()'* ]]; then
    pass "rollback lib defines restore_from_backup"
else
    fail "rollback lib should define restore_from_backup"
fi

if [[ "$rollback_lib_content" == *'perform_rollback()'* ]]; then
    pass "rollback lib defines perform_rollback"
else
    fail "rollback lib should define perform_rollback"
fi

section "Rollback Library - State Files"

if [[ "$rollback_lib_content" == *'ROLLBACK_STATE_DIR'* ]]; then
    pass "rollback lib defines state directory"
else
    fail "rollback lib should define state directory"
fi

if [[ "$rollback_lib_content" == *'.install-state'* ]]; then
    pass "rollback lib uses .install-state directory"
else
    fail "rollback lib should use .install-state directory"
fi

if [[ "$rollback_lib_content" == *'state.txt'* ]]; then
    pass "rollback lib uses state.txt"
else
    fail "rollback lib should use state.txt"
fi

if [[ "$rollback_lib_content" == *'symlinks.txt'* ]]; then
    pass "rollback lib uses symlinks.txt"
else
    fail "rollback lib should use symlinks.txt"
fi

if [[ "$rollback_lib_content" == *'backup-location.txt'* ]]; then
    pass "rollback lib uses backup-location.txt"
else
    fail "rollback lib should use backup-location.txt"
fi

section "Rollback Library - Security"

if [[ "$rollback_lib_content" == *'chmod 700'* ]]; then
    pass "rollback lib sets secure permissions on state dir"
else
    fail "rollback lib should set secure permissions"
fi

if [[ "$rollback_lib_content" == *'../*'* ]] && [[ "$rollback_lib_content" == *'/../'* ]]; then
    pass "rollback lib has path traversal protection"
else
    fail "rollback lib should have path traversal protection"
fi

if [[ "$rollback_lib_content" == *'resolved_dir'* ]] || [[ "$rollback_lib_content" == *'$HOME'* ]]; then
    pass "rollback lib validates paths are under HOME"
else
    fail "rollback lib should validate paths"
fi

# ===========================================================================
# Check Prerequisites Script Tests
# ===========================================================================

PREREQ_SCRIPT="$DOTFILES_DIR/scripts/install/check-prerequisites.sh"

section "Check Prerequisites - Existence and Executable"

if [[ -f "$PREREQ_SCRIPT" ]]; then
    pass "check-prerequisites.sh exists"
else
    fail "check-prerequisites.sh not found"
fi

if [[ -x "$PREREQ_SCRIPT" ]]; then
    pass "check-prerequisites.sh is executable"
else
    fail "check-prerequisites.sh is not executable"
fi

section "Check Prerequisites - ShellCheck"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$PREREQ_SCRIPT" 2>/dev/null; then
        pass "check-prerequisites.sh passes shellcheck"
    else
        fail "check-prerequisites.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Check Prerequisites - Help"

prereq_help=$("$PREREQ_SCRIPT" --help 2>&1) || true

if [[ "$prereq_help" == *"USAGE:"* ]]; then
    pass "prerequisites help shows USAGE"
else
    fail "prerequisites help should show USAGE"
fi

if [[ "$prereq_help" == *"DESCRIPTION:"* ]]; then
    pass "prerequisites help shows DESCRIPTION"
else
    fail "prerequisites help should show DESCRIPTION"
fi

prereq_help_short=$("$PREREQ_SCRIPT" -h 2>&1) || true
if [[ "$prereq_help_short" == *"USAGE:"* ]]; then
    pass "prerequisites -h flag works"
else
    fail "prerequisites -h should work"
fi

section "Check Prerequisites - Structure"

prereq_content=$(cat "$PREREQ_SCRIPT")

if [[ "$prereq_content" == *'source "$SCRIPT_DIR/../_lib/common.sh"'* ]]; then
    pass "prerequisites sources common.sh"
else
    fail "prerequisites should source common.sh"
fi

if [[ "$prereq_content" == *'set -euo pipefail'* ]]; then
    pass "prerequisites uses strict mode"
else
    fail "prerequisites should use strict mode"
fi

if [[ "$prereq_content" == *'PRESET='* ]] || [[ "$prereq_content" == *'DOTFILES_PRESET'* ]]; then
    pass "prerequisites supports preset configuration"
else
    fail "prerequisites should support preset configuration"
fi

if [[ "$prereq_content" == *'check()'* ]] || [[ "$prereq_content" == *'check_command'* ]]; then
    pass "prerequisites defines check function"
else
    fail "prerequisites should define check function"
fi

if [[ "$prereq_content" == *'check_optional'* ]]; then
    pass "prerequisites supports optional checks"
else
    fail "prerequisites should support optional checks"
fi

section "Check Prerequisites - Required Tools"

if [[ "$prereq_content" == *'"git"'* ]]; then
    pass "prerequisites checks for git"
else
    fail "prerequisites should check for git"
fi

if [[ "$prereq_content" == *'"zsh"'* ]]; then
    pass "prerequisites checks for zsh"
else
    fail "prerequisites should check for zsh"
fi

if [[ "$prereq_content" == *'"tmux"'* ]]; then
    pass "prerequisites checks for tmux"
else
    fail "prerequisites should check for tmux"
fi

if [[ "$prereq_content" == *'"neovim"'* ]] || [[ "$prereq_content" == *'"nvim"'* ]]; then
    pass "prerequisites checks for neovim"
else
    fail "prerequisites should check for neovim"
fi

if [[ "$prereq_content" == *'"fzf"'* ]]; then
    pass "prerequisites checks for fzf"
else
    fail "prerequisites should check for fzf"
fi

section "Check Prerequisites - Preset Hierarchy"

if [[ "$prereq_content" == *'should_install "core"'* ]]; then
    pass "prerequisites uses should_install for core"
else
    fail "prerequisites should use should_install for core"
fi

if [[ "$prereq_content" == *'should_install "full"'* ]]; then
    pass "prerequisites uses should_install for full"
else
    fail "prerequisites should use should_install for full"
fi

section "Check Prerequisites - macOS Checks"

if [[ "$prereq_content" == *'is_macos'* ]]; then
    pass "prerequisites has macOS-specific checks"
else
    fail "prerequisites should have macOS-specific checks"
fi

if [[ "$prereq_content" == *'Ghostty.app'* ]]; then
    pass "prerequisites checks for Ghostty app"
else
    fail "prerequisites should check for Ghostty app"
fi

if [[ "$prereq_content" == *'Karabiner'* ]]; then
    pass "prerequisites checks for Karabiner"
else
    fail "prerequisites should check for Karabiner"
fi

section "Check Prerequisites - Exit Codes"

if [[ "$prereq_content" == *'FAILED=0'* ]] || [[ "$prereq_content" == *'FAILED='* ]]; then
    pass "prerequisites tracks failure state"
else
    fail "prerequisites should track failure state"
fi

if [[ "$prereq_content" == *'exit 0'* ]] && [[ "$prereq_content" == *'exit 1'* ]]; then
    pass "prerequisites has proper exit codes"
else
    fail "prerequisites should have proper exit codes"
fi

# ===========================================================================
# Release Notes Command Tests
# ===========================================================================

section "Notes Command - Structure"

# Check that notes command is routed in main case statement
if [[ "$script_content" == *'notes|'* ]]; then
    pass "notes command is handled in main case statement"
else
    fail "notes command should be in main case statement"
fi

# Check -n shorthand
if [[ "$script_content" == *'-n)'* ]]; then
    pass "notes command supports -n shorthand"
else
    fail "notes command should support -n shorthand"
fi

# Check that cmd_notes references CHANGELOG.md
if [[ "$script_content" == *'CHANGELOG.md'* ]]; then
    pass "notes references CHANGELOG.md"
else
    fail "notes should reference CHANGELOG.md"
fi

# Check that changelog helpers use awk for parsing
if [[ "$script_content" == *'_changelog_incoming'* ]]; then
    pass "status/update uses _changelog_incoming helper"
else
    fail "status/update should use _changelog_incoming helper"
fi

# ===========================================================================
# Links Command Tests
# ===========================================================================

section "Links Command - Structure"

# Check that links command is routed in main case statement
if [[ "$script_content" == *'links|'* ]]; then
    pass "links command is handled in main case statement"
else
    fail "links command should be in main case statement"
fi

# Check -l shorthand
if [[ "$script_content" == *'-l)'* ]]; then
    pass "links command supports -l shorthand"
else
    fail "links command should support -l shorthand"
fi

# Check that cmd_links uses _check_link helper
if [[ "$script_content" == *'_check_link()'* ]]; then
    pass "cmd_links defines _check_link helper"
else
    fail "cmd_links should define _check_link helper"
fi

# Check that cmd_links uses preset detection
if [[ "$script_content" == *'cmd_links'*'get_preset'* ]] || grep -q 'get_preset' <<< "$(sed -n '/cmd_links()/,/^}/p' "$DOTFILES_CLI")"; then
    pass "cmd_links uses get_preset"
else
    fail "cmd_links should use get_preset"
fi

# Check that cmd_links uses should_install for preset hierarchy
if grep -q 'should_install' <<< "$(sed -n '/cmd_links()/,/^}/p' "$DOTFILES_CLI")"; then
    pass "cmd_links uses should_install for preset filtering"
else
    fail "cmd_links should use should_install for preset filtering"
fi

# Check that help documents links command usage
if [[ "$help_output" == *"symlinks"* ]] || [[ "$help_output" == *"links"* ]]; then
    pass "help documents links command"
else
    fail "help should document links command"
fi

# ===========================================================================
# Launcher Scripts Tests
# ===========================================================================

LAUNCHERS_DIR="$DOTFILES_DIR/launchers"

section "Launcher Scripts - Config"

config_launcher="$LAUNCHERS_DIR/config"
if [[ -f "$config_launcher" ]]; then
    pass "config launcher exists"
else
    fail "config launcher not found at $config_launcher"
fi

if [[ -x "$config_launcher" ]]; then
    pass "config launcher is executable"
else
    fail "config launcher is not executable"
fi

section "Launcher Scripts - Dotfiles"

dotfiles_launcher="$LAUNCHERS_DIR/dotfiles"
if [[ -f "$dotfiles_launcher" ]]; then
    pass "dotfiles launcher exists"
else
    fail "dotfiles launcher not found at $dotfiles_launcher"
fi

if [[ -x "$dotfiles_launcher" ]]; then
    pass "dotfiles launcher is executable"
else
    fail "dotfiles launcher is not executable"
fi

section "Launcher Scripts - ShellCheck"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$config_launcher" 2>/dev/null; then
        pass "config launcher passes shellcheck"
    else
        fail "config launcher has shellcheck warnings"
    fi

    if shellcheck -x -S warning -e SC1091 "$dotfiles_launcher" 2>/dev/null; then
        pass "dotfiles launcher passes shellcheck"
    else
        fail "dotfiles launcher has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Launcher Scripts - Structure"

config_content=$(cat "$config_launcher")
dotfiles_content=$(cat "$dotfiles_launcher")

if [[ "$config_content" == *'set -euo pipefail'* ]]; then
    pass "config launcher uses strict mode"
else
    fail "config launcher should use strict mode"
fi

if [[ "$dotfiles_content" == *'set -euo pipefail'* ]]; then
    pass "dotfiles launcher uses strict mode"
else
    fail "dotfiles launcher should use strict mode"
fi

if [[ "$config_content" == *'@description:'* ]]; then
    pass "config launcher has @description metadata"
else
    fail "config launcher should have @description metadata"
fi

if [[ "$dotfiles_content" == *'@description:'* ]]; then
    pass "dotfiles launcher has @description metadata"
else
    fail "dotfiles launcher should have @description metadata"
fi

if [[ "$config_content" == *'--help'* ]]; then
    pass "config launcher supports --help flag"
else
    fail "config launcher should support --help flag"
fi

if [[ "$dotfiles_content" == *'--help'* ]]; then
    pass "dotfiles launcher supports --help flag"
else
    fail "dotfiles launcher should support --help flag"
fi

# Check help output
config_help=$("$config_launcher" --help 2>&1) || true
if [[ "$config_help" == *"USAGE:"* ]]; then
    pass "config launcher --help shows USAGE"
else
    fail "config launcher --help should show USAGE"
fi

dotfiles_help=$("$dotfiles_launcher" --help 2>&1) || true
if [[ "$dotfiles_help" == *"USAGE:"* ]]; then
    pass "dotfiles launcher --help shows USAGE"
else
    fail "dotfiles launcher --help should show USAGE"
fi

# Check tmux session handling
if [[ "$config_content" == *'tmux has-session'* ]]; then
    pass "config launcher checks for existing session"
else
    fail "config launcher should check for existing session"
fi

if [[ "$dotfiles_content" == *'tmux has-session'* ]]; then
    pass "dotfiles launcher checks for existing session"
else
    fail "dotfiles launcher should check for existing session"
fi

if [[ "$config_content" == *'tmux new-session'* ]]; then
    pass "config launcher creates tmux session"
else
    fail "config launcher should create tmux session"
fi

if [[ "$dotfiles_content" == *'tmux new-session'* ]]; then
    pass "dotfiles launcher creates tmux session"
else
    fail "dotfiles launcher should create tmux session"
fi

# ===========================================================================
# Summary
# ===========================================================================

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
