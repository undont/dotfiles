#!/usr/bin/env bash
# Test suite for OpenCode alert system
# Ensures alerts work 1:1 like Claude Code

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/../../../tmux/.tmux/scripts/tests/_test-helpers.sh"

ALERTS_FILE="$HOME/.claude/alerts"
TEST_TMP_DIR="/tmp/opencode-alert-tests"

# Test counters
PASS=0
FAIL=0

# Override the pass/fail functions to update counters
pass() {
    PASS=$((PASS + 1))
    echo "${GREEN}✓${NC} $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "${RED}✗${NC} $1"
}

# Assert that a command succeeds
assert_success() {
    local desc="$1"
    shift
    if "$@" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

# Assert that a command fails
assert_failure() {
    local desc="$1"
    shift
    if ! "$@" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

# Assert output equals expected value
assert_equals() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc (expected: '$expected', got: '$actual')"
    fi
}

setup_test_env() {
    # Create temp directory
    mkdir -p "$TEST_TMP_DIR"

    # Backup original alerts file
    if [[ -f "$ALERTS_FILE" ]]; then
        cp "$ALERTS_FILE" "${ALERTS_FILE}.backup"
    fi

    # Clear alerts for clean testing
    > "$ALERTS_FILE"
}

cleanup_test_env() {
    # Restore original alerts file
    if [[ -f "${ALERTS_FILE}.backup" ]]; then
        mv "${ALERTS_FILE}.backup" "$ALERTS_FILE"
    else
        rm -f "$ALERTS_FILE"
    fi

    # Remove temp directory
    rm -rf "$TEST_TMP_DIR"
}

# Test functions
test_alert_scripts_exist() {
    [[ -x "$SCRIPT_DIR/../agent-alert.sh" ]] && [[ -x "$SCRIPT_DIR/../agent-alert-clear.sh" ]] && [[ -x "$SCRIPT_DIR/../wrappers/opencode-alert.sh" ]]
}

test_opencode_alert_script() {
    # Run the opencode alert script
    "$SCRIPT_DIR/../wrappers/opencode-alert.sh" >/dev/null 2>&1

    # Check if alert was added
    grep -q "opencode" "$ALERTS_FILE"
}

test_alert_clear_script() {
    # First add an alert
    "$SCRIPT_DIR/../wrappers/opencode-alert.sh" >/dev/null 2>&1

    # Verify it was added
    grep -q "opencode" "$ALERTS_FILE" >/dev/null 2>&1

    # Clear alerts
    "$SCRIPT_DIR/../agent-alert-clear.sh" >/dev/null 2>&1

    # Check if alerts file is empty or doesn't contain opencode
    ! grep -q "opencode" "$ALERTS_FILE" >/dev/null 2>&1
}

test_plugin_file_exists() {
    [[ -f "$HOME/.ai/opencode/plugin/opencode-alert.js" ]] && [[ -f "$HOME/.ai/opencode/plugin/opencode-alert.ts" ]]
}

test_plugin_configured() {
    local config_file="$HOME/.ai/opencode/opencode.json"
    [[ -f "$config_file" ]] && jq -e '.plugin[] | select(. == "./plugin/opencode-alert.js")' "$config_file" >/dev/null 2>&1
}

test_plugin_configured_main() {
    local config_file="$HOME/.config/opencode/opencode.json"
    [[ -f "$config_file" ]] && jq -e '.plugin[] | select(. == "./plugin/opencode-alert.js")' "$config_file" >/dev/null 2>&1
}

test_alerts_file_permissions() {
    [[ -f "$ALERTS_FILE" ]] && [[ $(stat -c %a "$ALERTS_FILE" 2>/dev/null || stat -f %A "$ALERTS_FILE" | cut -c 1-3) =~ ^[64][04][04]$ ]]
}

test_tmux_integration() {
    # Check if tmux is available
    command -v tmux > /dev/null 2>&1
}

test_agent_alert_script_with_custom_agent() {
    # Test agent-alert.sh with different agents
    "$SCRIPT_DIR/../agent-alert.sh" "test_agent" >/dev/null 2>&1

    grep -q "test_agent" "$ALERTS_FILE" >/dev/null 2>&1
}

test_alert_deduplication() {
    # Add same alert multiple times
    "$SCRIPT_DIR/../agent-alert.sh" "test_agent" >/dev/null 2>&1
    "$SCRIPT_DIR/../agent-alert.sh" "test_agent" >/dev/null 2>&1
    "$SCRIPT_DIR/../agent-alert.sh" "test_agent" >/dev/null 2>&1

    # Should only appear once
    local count=$(grep -c "test_agent" "$ALERTS_FILE")
    [[ $count -eq 1 ]]
}

test_multiple_agents() {
    # Add different agents
    "$SCRIPT_DIR/../agent-alert.sh" "claude" >/dev/null 2>&1
    "$SCRIPT_DIR/../agent-alert.sh" "opencode" >/dev/null 2>&1
    "$SCRIPT_DIR/../agent-alert.sh" "unknown" >/dev/null 2>&1

    # Check all are present
    grep -q "claude" "$ALERTS_FILE" >/dev/null 2>&1 && grep -q "opencode" "$ALERTS_FILE" >/dev/null 2>&1 && grep -q "unknown" "$ALERTS_FILE" >/dev/null 2>&1
}

test_alert_script_error_handling() {
    # Test with invalid agent name (should still work)
    "$SCRIPT_DIR/../agent-alert.sh" "" 2>/dev/null || true

    # File should still exist and be readable
    [[ -f "$ALERTS_FILE" ]] && [[ -r "$ALERTS_FILE" ]]
}

test_bell_functionality() {
    # Test that bell is attempted (can't verify it actually rings)
    "$SCRIPT_DIR/../agent-alert.sh" "bell_test" >/dev/null 2>&1

    grep -q "bell_test" "$ALERTS_FILE" >/dev/null 2>&1
}

# Main test runner
main() {
    echo "OpenCode Alert System Test Suite"
    echo "Testing OpenCode alerts compatibility with Claude Code"
    echo

    setup_test_env

    # Setup tmux test server for tmux-dependent tests
    setup_test_server

    # Core functionality tests
    section "Core Functionality"

    assert_success "Alert scripts exist and are executable" test_alert_scripts_exist
    assert_success "OpenCode alert script triggers alert" test_opencode_alert_script
    assert_success "Alert clear script removes alerts" test_alert_clear_script
    assert_success "Plugin files exist" test_plugin_file_exists
    assert_success "Plugin configured in project config" test_plugin_configured
    assert_success "Plugin configured in main config" test_plugin_configured_main
    assert_success "Alerts file has correct permissions" test_alerts_file_permissions
    assert_success "Tmux is available" test_tmux_integration

    # Edge case tests
    section "Edge Cases & Error Handling"

    assert_success "Agent alert script with custom agent" test_agent_alert_script_with_custom_agent
    assert_success "Alert deduplication works" test_alert_deduplication
    assert_success "Multiple agents can be tracked" test_multiple_agents
    assert_success "Error handling doesn't break system" test_alert_script_error_handling
    assert_success "Bell functionality is attempted" test_bell_functionality

    # Summary
    section "Test Results"
    echo "Passed: $PASS"
    echo "Failed: $FAIL"
    echo "Total: $((PASS + FAIL))"

    if [[ $FAIL -eq 0 ]]; then
        pass "All tests passed! 🎉"
        echo
        echo "OpenCode alerts are working correctly and compatible with Claude Code."
    else
        fail "Some tests failed - please check the output above and fix any issues."
        exit 1
    fi

    cleanup_test_server
    cleanup_test_env
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi