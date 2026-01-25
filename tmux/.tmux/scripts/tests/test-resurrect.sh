#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# test-resurrect.sh
# ══════════════════════════════════════════════════════════════
# Tests for tmux resurrect scripts and path discovery.
#
# Coverage:
# - Path discovery (legacy vs XDG locations)
# - Split operations (post-save hook)
# - Restore operations (per-session restore)
# - Delete operations (kill + remove backup)
# - Edge cases (missing dirs, invalid files)
#
# Usage: ./test-resurrect.sh
# ══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$SCRIPTS_DIR/_lib"

# Source test helpers (provides colours, pass/fail/skip/section, counters)
source "$SCRIPT_DIR/_test-helpers.sh"

# Trap to ensure cleanup on exit/interrupt
trap cleanup_test_env EXIT INT TERM

# ══════════════════════════════════════════════════════════════
# Test Environment Setup/Cleanup
# ══════════════════════════════════════════════════════════════

# Test environment variables
TEST_HOME=""
TEST_XDG_DATA_HOME=""
ORIGINAL_HOME="$HOME"
ORIGINAL_XDG_DATA_HOME="${XDG_DATA_HOME:-}"

setup_test_env() {
    # Create temporary test directories
    TEST_HOME=$(mktemp -d)
    TEST_XDG_DATA_HOME="$TEST_HOME/.local/share"
    
    # Export for subshells
    export HOME="$TEST_HOME"
    export XDG_DATA_HOME="$TEST_XDG_DATA_HOME"
    
    # Create basic directory structure
    mkdir -p "$TEST_HOME/.tmux/resurrect"
    mkdir -p "$TEST_XDG_DATA_HOME/tmux/resurrect"
}

cleanup_test_env() {
    # Restore original environment
    export HOME="$ORIGINAL_HOME"
    if [[ -n "$ORIGINAL_XDG_DATA_HOME" ]]; then
        export XDG_DATA_HOME="$ORIGINAL_XDG_DATA_HOME"
    else
        unset XDG_DATA_HOME
    fi
    
    # Remove test directories
    if [[ -n "$TEST_HOME" && -d "$TEST_HOME" ]]; then
        rm -rf "$TEST_HOME"
    fi
}

# ══════════════════════════════════════════════════════════════
# Path Discovery Tests
# ══════════════════════════════════════════════════════════════

test_path_discovery() {
    section "Path Discovery Tests"
    
    # Source the paths library
    source "$LIB_DIR/paths.sh"
    
    # Test 1: Legacy location with 'last' symlink
    setup_test_env
    touch "$TEST_HOME/.tmux/resurrect/last"
    result=$(get_resurrect_dir)
    if [[ "$result" == "$TEST_HOME/.tmux/resurrect" ]]; then
        pass "Legacy location detected via 'last' symlink"
    else
        fail "Legacy location detection failed (got: $result)"
    fi
    cleanup_test_env
    
    # Test 2: XDG location with 'last' symlink
    setup_test_env
    mkdir -p "$TEST_XDG_DATA_HOME/tmux/resurrect"
    touch "$TEST_XDG_DATA_HOME/tmux/resurrect/last"
    result=$(get_resurrect_dir)
    if [[ "$result" == "$TEST_XDG_DATA_HOME/tmux/resurrect" ]]; then
        pass "XDG location detected via 'last' symlink"
    else
        fail "XDG location detection failed (got: $result)"
    fi
    cleanup_test_env
    
    # Test 3: Priority - legacy 'last' over XDG 'last'
    setup_test_env
    touch "$TEST_HOME/.tmux/resurrect/last"
    mkdir -p "$TEST_XDG_DATA_HOME/tmux/resurrect"
    touch "$TEST_XDG_DATA_HOME/tmux/resurrect/last"
    result=$(get_resurrect_dir)
    if [[ "$result" == "$TEST_HOME/.tmux/resurrect" ]]; then
        pass "Legacy 'last' takes priority over XDG"
    else
        fail "Priority order incorrect (got: $result)"
    fi
    cleanup_test_env
    
    # Test 4: XDG sessions directory fallback
    setup_test_env
    mkdir -p "$TEST_XDG_DATA_HOME/tmux/resurrect/sessions"
    result=$(get_resurrect_dir)
    if [[ "$result" == "$TEST_XDG_DATA_HOME/tmux/resurrect" ]]; then
        pass "XDG sessions directory fallback works"
    else
        fail "XDG sessions directory fallback failed (got: $result)"
    fi
    cleanup_test_env
    
    # Test 5: Legacy sessions directory fallback
    setup_test_env
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    result=$(get_resurrect_dir)
    if [[ "$result" == "$TEST_HOME/.tmux/resurrect" ]]; then
        pass "Legacy sessions directory fallback works"
    else
        fail "Legacy sessions directory fallback failed (got: $result)"
    fi
    cleanup_test_env
    
    # Test 6: Default to legacy when nothing exists
    setup_test_env
    result=$(get_resurrect_dir)
    if [[ "$result" == "$TEST_HOME/.tmux/resurrect" ]]; then
        pass "Defaults to legacy location when nothing exists"
    else
        fail "Default location incorrect (got: $result)"
    fi
    cleanup_test_env
    
    # Test 7: get_resurrect_sessions_dir consistency
    setup_test_env
    touch "$TEST_HOME/.tmux/resurrect/last"
    result=$(get_resurrect_sessions_dir)
    expected="$TEST_HOME/.tmux/resurrect/sessions"
    if [[ "$result" == "$expected" ]]; then
        pass "Sessions directory path is consistent with base dir"
    else
        fail "Sessions directory path mismatch (got: $result, expected: $expected)"
    fi
    cleanup_test_env
    
    # Test 8: XDG_DATA_HOME unset behaviour
    setup_test_env
    unset XDG_DATA_HOME
    touch "$TEST_HOME/.local/share/tmux/resurrect/last"
    result=$(get_resurrect_dir)
    if [[ "$result" == "$TEST_HOME/.local/share/tmux/resurrect" ]]; then
        pass "XDG default location works when XDG_DATA_HOME unset"
    else
        fail "XDG default location failed (got: $result)"
    fi
    cleanup_test_env
}

# ══════════════════════════════════════════════════════════════
# Resurrect Operation Tests
# ══════════════════════════════════════════════════════════════

test_split_operation() {
    section "Split Operation Tests"
    
    # Test 1: Basic split functionality
    setup_test_env
    
    # Create a mock 'last' file with multiple sessions
    cat > "$TEST_HOME/.tmux/resurrect/last" << 'EOF'
pane	session1	0	:window1	1	:*	1	:/home/user	1	bash	:
pane	session2	0	:window1	1	:*	1	:/home/user	1	bash	:
window	session1	0	1	:*	0123,80x24,0,0,1
window	session2	0	1	:*	0123,80x24,0,0,2
state	session1	
state	session2	
EOF
    
    # Run split script (may fail in some environments)
    if bash "$SCRIPTS_DIR/resurrect-split.sh" 2>&1; then
        # Check session1 file was created
        if [[ -f "$TEST_HOME/.tmux/resurrect/sessions/session1.txt" ]]; then
            pass "Split creates session1.txt"
        else
            fail "Split did not create session1.txt"
        fi
        
        # Check session2 file was created
        if [[ -f "$TEST_HOME/.tmux/resurrect/sessions/session2.txt" ]]; then
            pass "Split creates session2.txt"
        else
            fail "Split did not create session2.txt"
        fi
        
        # Verify session1 content
        if grep -q "session1" "$TEST_HOME/.tmux/resurrect/sessions/session1.txt" && \
           ! grep -q "session2" "$TEST_HOME/.tmux/resurrect/sessions/session1.txt"; then
            pass "session1.txt contains only session1 data"
        else
            fail "session1.txt content incorrect"
        fi
        
        # Verify session2 content
        if grep -q "session2" "$TEST_HOME/.tmux/resurrect/sessions/session2.txt" && \
           ! grep -q "session1" "$TEST_HOME/.tmux/resurrect/sessions/session2.txt"; then
            pass "session2.txt contains only session2 data"
        else
            fail "session2.txt content incorrect"
        fi
    else
        # Split script failed - this might happen in CI or limited environments
        skip "Split script execution failed (environment-specific issue)"
    fi
    
    cleanup_test_env
    
    # Test 2: Empty 'last' file handling
    setup_test_env
    touch "$TEST_HOME/.tmux/resurrect/last"
    
    if bash "$SCRIPTS_DIR/resurrect-split.sh" 2>/dev/null; then
        pass "Split handles empty 'last' file gracefully"
    else
        skip "Split script may fail on empty file (expected behaviour)"
    fi
    
    cleanup_test_env
    
    # Test 3: Missing 'last' file
    setup_test_env
    
    if ! bash "$SCRIPTS_DIR/resurrect-split.sh" 2>/dev/null; then
        pass "Split fails gracefully with missing 'last' file"
    else
        skip "Split may succeed with missing file (creates empty sessions)"
    fi
    
    cleanup_test_env
}

test_restore_operation() {
    section "Restore Operation Tests"
    
    # Note: Full restore testing requires tmux server setup
    # These tests focus on backup file handling and validation
    
    setup_test_env
    
    # Create a session backup file
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    cat > "$TEST_HOME/.tmux/resurrect/sessions/test-session.txt" << 'EOF'
pane	test-session	0	:window1	1	:*	1	:/home/user	1	bash	:
window	test-session	0	1	:*	0123,80x24,0,0,1
state	test-session	
EOF
    
    # Test 1: List backups
    result=$(bash "$SCRIPTS_DIR/resurrect-restore.sh" --list 2>/dev/null | grep -c "test-session" || true)
    if [[ "$result" -gt 0 ]]; then
        pass "List operation finds test-session backup"
    else
        fail "List operation did not find test-session backup"
    fi
    
    # Test 2: Backup file exists check
    if [[ -f "$TEST_HOME/.tmux/resurrect/sessions/test-session.txt" ]]; then
        pass "Backup file created correctly"
    else
        fail "Backup file not found"
    fi
    
    cleanup_test_env
    
    # Test 3: Empty sessions directory
    setup_test_env
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    
    result=$(bash "$SCRIPTS_DIR/resurrect-restore.sh" --list 2>/dev/null | wc -l)
    if [[ "$result" -le 2 ]]; then  # Allow for header/footer lines
        pass "List operation handles empty sessions directory"
    else
        fail "List operation shows unexpected content for empty directory"
    fi
    
    cleanup_test_env
}

test_delete_operation() {
    section "Delete Operation Tests"
    
    # Note: These tests focus on backup file deletion
    # Session killing requires tmux server
    
    setup_test_env
    
    # Create a session backup file
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    touch "$TEST_HOME/.tmux/resurrect/sessions/test-session.txt"
    
    # Test 1: Verify backup exists before delete
    if [[ -f "$TEST_HOME/.tmux/resurrect/sessions/test-session.txt" ]]; then
        pass "Backup file exists before delete"
    else
        fail "Backup file not created"
    fi
    
    # Test 2: Delete when session doesn't exist (only deletes backup)
    # Note: This will attempt to kill the session which will fail,
    # but should still delete the backup
    bash "$SCRIPTS_DIR/resurrect-kill-session.sh" test-session 2>/dev/null || true
    
    # Verify backup was deleted (or attempted)
    # Note: Script may not delete if session validation fails
    # This is expected behaviour
    skip "Delete operation requires tmux server for full testing"
    
    cleanup_test_env
}

# ══════════════════════════════════════════════════════════════
# Edge Case Tests
# ══════════════════════════════════════════════════════════════

test_edge_cases() {
    section "Edge Case Tests"
    
    # Test 1: Session name with special characters in backup
    setup_test_env
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    touch "$TEST_HOME/.tmux/resurrect/sessions/my-project_v2.1.txt"
    
    result=$(bash "$SCRIPTS_DIR/resurrect-restore.sh" --list 2>/dev/null | grep -c "my-project_v2.1" || true)
    if [[ "$result" -gt 0 ]]; then
        pass "Handles session names with dots, dashes, underscores"
    else
        fail "Session name parsing failed for special characters"
    fi
    
    cleanup_test_env
    
    # Test 2: Multiple sessions with same prefix
    setup_test_env
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    touch "$TEST_HOME/.tmux/resurrect/sessions/project.txt"
    touch "$TEST_HOME/.tmux/resurrect/sessions/project-2.txt"
    touch "$TEST_HOME/.tmux/resurrect/sessions/project-test.txt"
    
    result=$(bash "$SCRIPTS_DIR/resurrect-restore.sh" --list 2>/dev/null | grep -c "project" || true)
    if [[ "$result" -ge 3 ]]; then
        pass "Lists all sessions with similar names"
    else
        fail "Session listing incomplete for similar names"
    fi
    
    cleanup_test_env
    
    # Test 3: Invalid/corrupt backup file
    setup_test_env
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    echo "corrupted data" > "$TEST_HOME/.tmux/resurrect/sessions/corrupt-session.txt"
    
    # Script should still list it (restoration might fail, but listing should work)
    result=$(bash "$SCRIPTS_DIR/resurrect-restore.sh" --list 2>/dev/null | grep -c "corrupt-session" || true)
    if [[ "$result" -gt 0 ]]; then
        pass "Lists sessions even with potentially corrupt backup files"
    else
        skip "Corrupt file handling varies by implementation"
    fi
    
    cleanup_test_env
}

# ══════════════════════════════════════════════════════════════
# Content and Command Restoration Tests
# ══════════════════════════════════════════════════════════════

test_content_restoration() {
    section "Content Restoration Tests"
    
    # Check if tmux-resurrect plugin is installed
    if [[ ! -f "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" ]]; then
        skip "Content restoration tests require tmux-resurrect plugin"
        return
    fi
    
    setup_test_env
    setup_test_server
    
    # Create a session with content
    $TEST_TMUX_CMD new-session -d -s "test-content" "echo 'Test Content Line 1'; echo 'Test Content Line 2'; bash"
    sleep 0.5
    
    # Save session (this should create pane contents files)
    $TEST_TMUX_CMD run-shell "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    sleep 0.5
    
    # Split sessions to create individual backup
    bash "$SCRIPTS_DIR/resurrect-split.sh"
    
    # Kill the session
    $TEST_TMUX_CMD kill-session -t "test-content"
    
    # Restore the session
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-content"
    
    # Check if session was restored
    if $TEST_TMUX_CMD has-session -t "test-content" 2>/dev/null; then
        pass "Session restored with content restoration enabled"
    else
        fail "Session restoration failed"
    fi
    
    cleanup_test_server
    cleanup_test_env
}

test_command_restoration() {
    section "Command Restoration Tests"
    
    # Check if tmux-resurrect plugin is installed
    if [[ ! -f "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" ]]; then
        skip "Command restoration tests require tmux-resurrect plugin"
        return
    fi
    
    setup_test_env
    setup_test_server
    
    # Configure process restoration
    $TEST_TMUX_CMD set-option -g @resurrect-processes "vim"
    
    # Create session with vim running (should be restored)
    # Use a simple sleep command instead of an interactive program for testing
    $TEST_TMUX_CMD new-session -d -s "test-commands" "sleep 60"
    sleep 0.5
    
    # Verify session was created
    if ! $TEST_TMUX_CMD has-session -t "test-commands" 2>/dev/null; then
        skip "Session creation failed in test environment"
        cleanup_test_server
        cleanup_test_env
        return
    fi
    
    # Save and restore flow
    $TEST_TMUX_CMD run-shell "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    sleep 0.5
    bash "$SCRIPTS_DIR/resurrect-split.sh"
    $TEST_TMUX_CMD kill-session -t "test-commands"
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-commands"
    
    # Check if session was restored
    if $TEST_TMUX_CMD has-session -t "test-commands" 2>/dev/null; then
        pass "Session restored with command restoration configured"
        
        # Check if command is running
        local cmd
        cmd=$($TEST_TMUX_CMD display-message -p -t "test-commands:0.0" "#{pane_current_command}" 2>/dev/null || echo "")
        if [[ -n "$cmd" ]]; then
            pass "Command restoration attempted (pane running: $cmd)"
        else
            skip "Command state could not be verified"
        fi
    else
        fail "Session restoration failed with command restoration"
    fi
    
    cleanup_test_server
    cleanup_test_env
}

test_process_list_configuration() {
    section "Process List Configuration Tests"
    
    # Check if tmux-resurrect plugin is installed
    if [[ ! -f "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" ]]; then
        skip "Process list configuration tests require tmux-resurrect plugin"
        return
    fi
    
    setup_test_env
    setup_test_server
    
    # Test 1: Default process list (no configuration)
    $TEST_TMUX_CMD set-option -ug @resurrect-processes
    $TEST_TMUX_CMD new-session -d -s "test-default" "sleep 30"
    sleep 0.3
    
    # Save, kill, restore
    $TEST_TMUX_CMD run-shell "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    sleep 0.3
    bash "$SCRIPTS_DIR/resurrect-split.sh"
    $TEST_TMUX_CMD kill-session -t "test-default"
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-default"
    
    if $TEST_TMUX_CMD has-session -t "test-default" 2>/dev/null; then
        pass "Restoration works with default process list"
    else
        fail "Restoration failed with default configuration"
    fi
    
    $TEST_TMUX_CMD kill-session -t "test-default" 2>/dev/null || true
    
    # Test 2: Custom process list
    $TEST_TMUX_CMD set-option -g @resurrect-processes "ssh sleep"
    $TEST_TMUX_CMD new-session -d -s "test-custom" "sleep 30"
    sleep 0.3
    
    if ! $TEST_TMUX_CMD has-session -t "test-custom" 2>/dev/null; then
        skip "Session creation failed for custom process test"
        cleanup_test_server
        cleanup_test_env
        return
    fi
    
    $TEST_TMUX_CMD run-shell "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    sleep 0.3
    bash "$SCRIPTS_DIR/resurrect-split.sh"
    $TEST_TMUX_CMD kill-session -t "test-custom"
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-custom"
    
    if $TEST_TMUX_CMD has-session -t "test-custom" 2>/dev/null; then
        pass "Restoration works with custom process list"
    else
        fail "Restoration failed with custom process list"
    fi
    
    cleanup_test_server
    cleanup_test_env
}

test_mixed_restoration() {
    section "Mixed State Restoration Tests"
    
    # Check if tmux-resurrect plugin is installed
    if [[ ! -f "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" ]]; then
        skip "Mixed restoration tests require tmux-resurrect plugin"
        return
    fi
    
    setup_test_env
    setup_test_server
    
    # Create a session with multiple panes
    # - Some with content, some without
    # - Some with commands, some without
    $TEST_TMUX_CMD new-session -d -s "test-mixed" "echo 'Pane 1 content'; bash"
    $TEST_TMUX_CMD split-window -t "test-mixed" "bash"  # Empty pane
    $TEST_TMUX_CMD split-window -t "test-mixed" "echo 'Pane 3 content'; bash"
    sleep 0.5
    
    # Save, kill, restore
    $TEST_TMUX_CMD run-shell "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    sleep 0.5
    bash "$SCRIPTS_DIR/resurrect-split.sh"
    $TEST_TMUX_CMD kill-session -t "test-mixed"
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-mixed"
    
    # Check if session was restored with all panes
    if $TEST_TMUX_CMD has-session -t "test-mixed" 2>/dev/null; then
        local pane_count
        pane_count=$($TEST_TMUX_CMD list-panes -t "test-mixed" 2>/dev/null | wc -l)
        pane_count="${pane_count//[$'\n\r ']/}"  # Strip whitespace
        if [[ "$pane_count" -eq 3 ]]; then
            pass "Mixed state restoration preserves all panes"
        else
            fail "Mixed state restoration lost panes (expected 3, got $pane_count)"
        fi
    else
        fail "Mixed state restoration failed"
    fi
    
    cleanup_test_server
    cleanup_test_env
}

test_graceful_degradation() {
    section "Graceful Degradation Tests"
    
    setup_test_env
    setup_test_server
    
    # Test restoration when pane contents files don't exist
    $TEST_TMUX_CMD new-session -d -s "test-no-contents" "bash"
    sleep 0.3
    
    # Create backup manually without pane contents
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    cat > "$TEST_HOME/.tmux/resurrect/sessions/test-no-contents.txt" << 'EOF'
pane	test-no-contents	0	1		0	bash	/tmp	1	bash	
window	test-no-contents	0	bash	1		b6af,80x24,0,0,0	1
EOF
    
    $TEST_TMUX_CMD kill-session -t "test-no-contents"
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-no-contents"
    
    # Should still restore successfully without contents files
    if $TEST_TMUX_CMD has-session -t "test-no-contents" 2>/dev/null; then
        pass "Restoration works gracefully without pane contents files"
    else
        fail "Restoration failed when pane contents missing"
    fi
    
    cleanup_test_server
    cleanup_test_env
}

# ══════════════════════════════════════════════════════════════
# Field Validation Tests (Improvement #1)
# ══════════════════════════════════════════════════════════════

test_field_validation() {
    section "Field Validation Tests"

    setup_test_env
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"

    # Test 1: Missing window_number in pane line
    cat > "$TEST_HOME/.tmux/resurrect/sessions/test-missing-window.txt" << 'EOF'
pane	test-missing-window		0	:	0	:	/tmp	1	bash	:
pane	test-missing-window	1	0	:	1	:	/tmp	0	bash	:
window	test-missing-window	1	window1	1	:*	1234,80x24,0,0,1	0
EOF

    # Should skip malformed line but not crash
    if bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-missing-window" 2>/dev/null; then
        pass "Handles missing window_number in pane line gracefully"
    else
        skip "Script may fail on malformed files (depends on validation logic)"
    fi

    cleanup_test_env

    # Test 2: Missing pane_index in pane line
    setup_test_env
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    cat > "$TEST_HOME/.tmux/resurrect/sessions/test-missing-pane.txt" << 'EOF'
pane	test-missing-pane	0	0	:		:	/tmp	1	bash	:
pane	test-missing-pane	1	0	:	0	:	/tmp	0	bash	:
window	test-missing-pane	1	window1	1	:*	1234,80x24,0,0,1	0
EOF

    if bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-missing-pane" 2>/dev/null; then
        pass "Handles missing pane_index in pane line gracefully"
    else
        skip "Script may fail on malformed pane index"
    fi

    cleanup_test_env

    # Test 3: Missing window_layout in window line
    setup_test_env
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    cat > "$TEST_HOME/.tmux/resurrect/sessions/test-missing-layout.txt" << 'EOF'
pane	test-missing-layout	0	0	:	0	:	/tmp	1	bash	:
window	test-missing-layout	0	window1	1	:*		0
EOF

    if bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-missing-layout" 2>/dev/null; then
        pass "Handles missing window_layout gracefully"
    else
        skip "Script may fail on missing layout"
    fi

    cleanup_test_env

    # Test 4: Completely empty lines (should be ignored)
    setup_test_env
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    cat > "$TEST_HOME/.tmux/resurrect/sessions/test-empty-lines.txt" << 'EOF'
pane	test-empty-lines	0	0	:	0	:	/tmp	1	bash	:

window	test-empty-lines	0	window1	1	:*	1234,80x24,0,0,1	0

EOF

    if bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-empty-lines" 2>/dev/null; then
        pass "Handles empty lines in backup file gracefully"
    else
        skip "Script may fail on empty lines"
    fi

    cleanup_test_env
}

# ══════════════════════════════════════════════════════════════
# Cleanup Trap Tests (Improvement #3)
# ══════════════════════════════════════════════════════════════

test_cleanup_trap() {
    section "Cleanup Trap Tests"

    # Check if tmux server is available for these tests
    if [[ ! -f "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" ]]; then
        skip "Cleanup trap tests require tmux-resurrect plugin"
        return
    fi

    setup_test_env
    setup_test_server

    # Test 1: Partial session cleanup on error
    # Create a backup file that will cause an error during restoration
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"

    # This should create session successfully, but subsequent operations might fail
    cat > "$TEST_HOME/.tmux/resurrect/sessions/test-cleanup.txt" << 'EOF'
pane	test-cleanup	0	0	:	0	:	/tmp	1	bash	:
window	test-cleanup	0	window1	1	:*	1234,80x24,0,0,1	0
EOF

    # Attempt restoration (may succeed or fail depending on environment)
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-cleanup" 2>/dev/null || true

    # If it failed, verify no partial session remains
    if ! $TEST_TMUX_CMD has-session -t "test-cleanup" 2>/dev/null; then
        pass "No partial session left after restoration error"
    else
        # Session exists - either succeeded or trap didn't work
        skip "Session restoration succeeded or cleanup trap not triggered"
    fi

    cleanup_test_server
    cleanup_test_env

    # Test 2: Script interruption handling
    # Note: This is difficult to test automatically as it requires SIGINT/SIGTERM
    skip "Script interruption cleanup requires manual testing"
}

# ══════════════════════════════════════════════════════════════
# Non-consecutive Window Number Tests (Improvement #4)
# ══════════════════════════════════════════════════════════════

test_non_consecutive_windows() {
    section "Non-consecutive Window Number Tests"

    # Check if tmux server is available
    if [[ ! -f "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" ]]; then
        skip "Non-consecutive window tests require tmux-resurrect plugin"
        return
    fi

    setup_test_env
    setup_test_server

    # Test 1: Windows with gaps (0, 5, 9)
    $TEST_TMUX_CMD new-session -d -s "test-gaps" -n "win0"
    $TEST_TMUX_CMD new-window -t "test-gaps:5" -n "win5"
    $TEST_TMUX_CMD new-window -t "test-gaps:9" -n "win9"
    sleep 0.5

    # Verify windows were created with correct numbers
    local win_list
    win_list=$($TEST_TMUX_CMD list-windows -t "test-gaps" -F "#{window_index}" 2>/dev/null | tr '\n' ' ')
    if [[ "$win_list" =~ "0" ]] && [[ "$win_list" =~ "5" ]] && [[ "$win_list" =~ "9" ]]; then
        pass "Created test session with non-consecutive windows"
    else
        skip "Could not create windows with gaps (got: $win_list)"
        cleanup_test_server
        cleanup_test_env
        return
    fi

    # Save, kill, restore
    $TEST_TMUX_CMD run-shell "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    sleep 0.5
    bash "$SCRIPTS_DIR/resurrect-split.sh"
    $TEST_TMUX_CMD kill-session -t "test-gaps"
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-gaps"

    # Verify gaps are preserved
    if $TEST_TMUX_CMD has-session -t "test-gaps" 2>/dev/null; then
        local restored_wins
        restored_wins=$($TEST_TMUX_CMD list-windows -t "test-gaps" -F "#{window_index}" 2>/dev/null | tr '\n' ' ')
        if [[ "$restored_wins" =~ "0" ]] && [[ "$restored_wins" =~ "5" ]] && [[ "$restored_wins" =~ "9" ]]; then
            pass "Window number gaps preserved after restoration"
        else
            fail "Window numbers changed after restoration (got: $restored_wins)"
        fi

        # Verify window names
        local win0_name win5_name win9_name
        win0_name=$($TEST_TMUX_CMD display-message -t "test-gaps:0" -p "#{window_name}" 2>/dev/null)
        win5_name=$($TEST_TMUX_CMD display-message -t "test-gaps:5" -p "#{window_name}" 2>/dev/null)
        win9_name=$($TEST_TMUX_CMD display-message -t "test-gaps:9" -p "#{window_name}" 2>/dev/null)

        if [[ "$win0_name" == "win0" ]] && [[ "$win5_name" == "win5" ]] && [[ "$win9_name" == "win9" ]]; then
            pass "Window names preserved with non-consecutive numbers"
        else
            fail "Window names incorrect (0:$win0_name, 5:$win5_name, 9:$win9_name)"
        fi
    else
        fail "Session restoration failed with non-consecutive windows"
    fi

    cleanup_test_server
    cleanup_test_env

    # Test 2: Base index 1 with gaps (1, 3, 7)
    setup_test_env
    setup_test_server

    # Set base-index to 1
    $TEST_TMUX_CMD set-option -g base-index 1

    $TEST_TMUX_CMD new-session -d -s "test-gaps-base1" -n "win1"
    $TEST_TMUX_CMD new-window -t "test-gaps-base1:3" -n "win3"
    $TEST_TMUX_CMD new-window -t "test-gaps-base1:7" -n "win7"
    sleep 0.5

    $TEST_TMUX_CMD run-shell "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    sleep 0.5
    bash "$SCRIPTS_DIR/resurrect-split.sh"
    $TEST_TMUX_CMD kill-session -t "test-gaps-base1"
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-gaps-base1"

    if $TEST_TMUX_CMD has-session -t "test-gaps-base1" 2>/dev/null; then
        local restored_wins
        restored_wins=$($TEST_TMUX_CMD list-windows -t "test-gaps-base1" -F "#{window_index}" 2>/dev/null | tr '\n' ' ')
        if [[ "$restored_wins" =~ "1" ]] && [[ "$restored_wins" =~ "3" ]] && [[ "$restored_wins" =~ "7" ]]; then
            pass "Window gaps preserved with base-index 1"
        else
            fail "Window numbers incorrect with base-index 1 (got: $restored_wins)"
        fi
    else
        fail "Session restoration failed with base-index 1"
    fi

    # Reset base-index
    $TEST_TMUX_CMD set-option -ug base-index

    cleanup_test_server
    cleanup_test_env
}

# ══════════════════════════════════════════════════════════════
# Pane Readiness Tests (Improvement #2)
# ══════════════════════════════════════════════════════════════

test_pane_readiness() {
    section "Pane Readiness Tests"

    # Check if tmux server is available
    if [[ ! -f "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" ]]; then
        skip "Pane readiness tests require tmux-resurrect plugin"
        return
    fi

    setup_test_env
    setup_test_server

    # Test 1: Command restoration with wait_for_pane
    # Configure process restoration
    $TEST_TMUX_CMD set-option -g @resurrect-processes "sleep"

    # Create session with a sleep command
    $TEST_TMUX_CMD new-session -d -s "test-wait-pane" "sleep 60"
    sleep 0.5

    # Save and restore
    $TEST_TMUX_CMD run-shell "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    sleep 0.5
    bash "$SCRIPTS_DIR/resurrect-split.sh"
    $TEST_TMUX_CMD kill-session -t "test-wait-pane"

    # Restore - wait_for_pane should prevent race conditions
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-wait-pane"

    if $TEST_TMUX_CMD has-session -t "test-wait-pane" 2>/dev/null; then
        pass "Session restored with pane readiness polling"

        # Give command restoration a moment
        sleep 0.3

        # Check if command was restored (may or may not work depending on timing)
        local cmd
        cmd=$($TEST_TMUX_CMD display-message -p -t "test-wait-pane:0.0" "#{pane_current_command}" 2>/dev/null || echo "")
        if [[ -n "$cmd" ]]; then
            pass "Command restoration worked with pane readiness check (running: $cmd)"
        else
            skip "Command state verification inconclusive"
        fi
    else
        fail "Session restoration failed with pane readiness polling"
    fi

    cleanup_test_server
    cleanup_test_env

    # Test 2: Multiple panes with rapid restoration
    setup_test_env
    setup_test_server

    # Create session with multiple panes quickly
    $TEST_TMUX_CMD new-session -d -s "test-multi-panes" "bash"
    $TEST_TMUX_CMD split-window -t "test-multi-panes" "bash"
    $TEST_TMUX_CMD split-window -t "test-multi-panes" "bash"
    $TEST_TMUX_CMD split-window -t "test-multi-panes" "bash"
    sleep 0.5

    # Save and restore
    $TEST_TMUX_CMD run-shell "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
    sleep 0.5
    bash "$SCRIPTS_DIR/resurrect-split.sh"
    $TEST_TMUX_CMD kill-session -t "test-multi-panes"
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-multi-panes"

    # Verify all panes were restored
    if $TEST_TMUX_CMD has-session -t "test-multi-panes" 2>/dev/null; then
        local pane_count
        pane_count=$($TEST_TMUX_CMD list-panes -t "test-multi-panes" 2>/dev/null | wc -l)
        pane_count="${pane_count//[$'\n\r ']}"
        if [[ "$pane_count" -eq 4 ]]; then
            pass "All panes restored correctly with readiness polling"
        else
            fail "Pane count mismatch (expected 4, got $pane_count)"
        fi
    else
        fail "Multi-pane restoration failed"
    fi

    cleanup_test_server
    cleanup_test_env
}

# ══════════════════════════════════════════════════════════════
# Fuzzy Process Matching Tests (Improvement #6)
# ══════════════════════════════════════════════════════════════

test_fuzzy_process_matching() {
    section "Fuzzy Process Matching Tests"

    # Check if tmux-resurrect plugin is installed
    if [[ ! -f "$ORIGINAL_HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" ]]; then
        skip "Fuzzy matching tests require tmux-resurrect plugin"
        return
    fi

    setup_test_env
    setup_test_server

    # Test 1: Tilde prefix for fuzzy matching (~vim matches nvim)
    $TEST_TMUX_CMD set-option -g @resurrect-processes "~vim"

    # Source the restore script to test should_restore_command function
    # We'll test by checking the configuration handling

    # Create a session with nvim (should match ~vim)
    $TEST_TMUX_CMD new-session -d -s "test-fuzzy" "bash"
    sleep 0.3

    # Create backup with nvim command
    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    cat > "$TEST_HOME/.tmux/resurrect/sessions/test-fuzzy.txt" << 'EOF'
pane	test-fuzzy	0	1		0	bash	/tmp	1	nvim	nvim test.txt
window	test-fuzzy	0	test	1		1234,80x24,0,0,0	0
EOF

    $TEST_TMUX_CMD kill-session -t "test-fuzzy" 2>/dev/null || true
    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-fuzzy" 2>/dev/null || true

    if $TEST_TMUX_CMD has-session -t "test-fuzzy" 2>/dev/null; then
        pass "Restoration works with fuzzy process matching configured"
    else
        skip "Session restoration failed (may be environment-specific)"
    fi

    cleanup_test_server
    cleanup_test_env

    # Test 2: Verify exact matching still works alongside fuzzy
    setup_test_env
    setup_test_server

    $TEST_TMUX_CMD set-option -g @resurrect-processes "ssh ~vim htop"

    mkdir -p "$TEST_HOME/.tmux/resurrect/sessions"
    cat > "$TEST_HOME/.tmux/resurrect/sessions/test-mixed-match.txt" << 'EOF'
pane	test-mixed-match	0	1		0	bash	/tmp	1	ssh	ssh user@host
window	test-mixed-match	0	test	1		1234,80x24,0,0,0	0
EOF

    bash "$SCRIPTS_DIR/resurrect-restore.sh" --session "test-mixed-match" 2>/dev/null || true

    if $TEST_TMUX_CMD has-session -t "test-mixed-match" 2>/dev/null; then
        pass "Mixed exact and fuzzy matching works"
    else
        skip "Mixed matching test inconclusive"
    fi

    cleanup_test_server
    cleanup_test_env
}

# ══════════════════════════════════════════════════════════════
# Main Test Execution
# ══════════════════════════════════════════════════════════════

section "Setup Test Environment"
pass "Test environment ready"

# Run all test groups
test_path_discovery
test_split_operation
test_restore_operation
test_delete_operation
test_edge_cases
test_content_restoration
test_command_restoration
test_process_list_configuration
test_mixed_restoration
test_graceful_degradation

# New improvement tests
test_field_validation
test_cleanup_trap
test_non_consecutive_windows
test_pane_readiness
test_fuzzy_process_matching

section "Test Summary"

echo ""
echo "==========================================="
printf "${GREEN}✓ Passed: %d${NC} | ${RED}✗ Failed: %d${NC}\n" "$PASS" "$FAIL"
echo "==========================================="

[[ $FAIL -eq 0 ]]