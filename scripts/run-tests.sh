#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# run-tests.sh
# ══════════════════════════════════════════════════════════════
# Dynamic test discovery and runner for dotfiles test suite.
# Discovers and runs all test-*.sh files in the repository.
#
# Usage:
#   ./scripts/run-tests.sh                # Run all tests
#   ./scripts/run-tests.sh --verbose      # Verbose output
#   ./scripts/run-tests.sh --tmux-only    # Only tmux-dependent tests
#   ./scripts/run-tests.sh --no-tmux      # Skip tmux-dependent tests
# ══════════════════════════════════════════════════════════════

set -euo pipefail

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERBOSE=false
TMUX_ONLY=false
NO_TMUX=false

# Global counters
GLOBAL_TOTAL=0
GLOBAL_PASSED=0
GLOBAL_FAILED=0
GLOBAL_SKIPPED=0

# Per-suite counters
SUITE_TOTAL=0
SUITE_PASSED=0
SUITE_FAILED=0
SUITE_SKIPPED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --tmux-only)
            TMUX_ONLY=true
            shift
            ;;
        --no-tmux)
            NO_TMUX=true
            shift
            ;;
        *)
            printf "${RED}Unknown option: %s${NC}\n" "$1"
            exit 1
            ;;
    esac
done

# Check for conflicting options
if [[ "$TMUX_ONLY" = true && "$NO_TMUX" = true ]]; then
    printf "${RED}Error: Cannot use --tmux-only and --no-tmux together${NC}\n"
    exit 1
fi

# ──────────────────────────────────────────────────────────────
# Helper functions
# ──────────────────────────────────────────────────────────────

# Check if a test requires tmux
requires_tmux() {
    local test_file="$1"
    grep -q "_test-helpers.sh\|setup_test_server\|cleanup_test_server" "$test_file" 2>/dev/null
}

# Reset suite counters
reset_suite_counters() {
    SUITE_TOTAL=0
    SUITE_PASSED=0
    SUITE_FAILED=0
    SUITE_SKIPPED=0
}

# Print suite summary
print_suite_summary() {
    local suite_name="$1"
    printf "\n"
    printf "${BOLD}%s Summary:${NC} " "$suite_name"
    printf "%d total, " "$SUITE_TOTAL"
    printf "${GREEN}%d passed${NC}" "$SUITE_PASSED"
    
    if [[ $SUITE_FAILED -gt 0 ]]; then
        printf ", ${RED}%d failed${NC}" "$SUITE_FAILED"
    fi
    
    if [[ $SUITE_SKIPPED -gt 0 ]]; then
        printf ", ${YELLOW}%d skipped${NC}" "$SUITE_SKIPPED"
    fi
    
    printf "\n\n"
}

# Increment counters for test result
increment_counters() {
    local result="$1"  # "passed", "failed", or "skipped"
    
    SUITE_TOTAL=$((SUITE_TOTAL + 1))
    GLOBAL_TOTAL=$((GLOBAL_TOTAL + 1))
    
    case "$result" in
        passed)
            SUITE_PASSED=$((SUITE_PASSED + 1))
            GLOBAL_PASSED=$((GLOBAL_PASSED + 1))
            ;;
        failed)
            SUITE_FAILED=$((SUITE_FAILED + 1))
            GLOBAL_FAILED=$((GLOBAL_FAILED + 1))
            ;;
        skipped)
            SUITE_SKIPPED=$((SUITE_SKIPPED + 1))
            GLOBAL_SKIPPED=$((GLOBAL_SKIPPED + 1))
            ;;
    esac
}

# Print skip message and increment counters
skip_test() {
    local test_name="$1"
    local reason="$2"
    
    printf "${YELLOW}⊘${NC} %-50s ${YELLOW}SKIP${NC} (%s)\n" "$test_name" "$reason"
    increment_counters "skipped"
}

# Run a single test file
run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file")
    
    # Check if test requires tmux
    local needs_tmux=false
    if requires_tmux "$test_file"; then
        needs_tmux=true
    fi
    
    # Handle skip conditions
    if [[ "$needs_tmux" = true && "$NO_TMUX" = true ]]; then
        skip_test "$test_name" "tmux required"
        return 0
    fi
    
    if [[ "$needs_tmux" = false && "$TMUX_ONLY" = true ]]; then
        skip_test "$test_name" "not tmux test"
        return 0
    fi
    
    if [[ "$needs_tmux" = true ]] && ! command -v tmux &>/dev/null; then
        skip_test "$test_name" "tmux not installed"
        return 0
    fi

    # Run the test
    local output
    local exit_code
    
    if [[ "$VERBOSE" = true ]]; then
        printf "${CYAN}▶${NC} Running: %s\n" "$test_name"
    fi
    
    if output=$("$test_file" 2>&1); then
        printf "${GREEN}✓${NC} %-50s ${GREEN}PASS${NC}\n" "$test_name"
        increment_counters "passed"
    else
        exit_code=$?
        if [[ "$VERBOSE" = true ]]; then
            printf "${RED}✗${NC} %-50s ${RED}FAIL${NC} (exit code: %d)\n" "$test_name" "$exit_code"
        else
            printf "${RED}✗${NC} %-50s ${RED}FAIL${NC}\n" "$test_name"
            printf "${RED}Output:${NC}\n%s\n" "$output"
        fi
        increment_counters "failed"
    fi
}

# ──────────────────────────────────────────────────────────────
# Test discovery
# ──────────────────────────────────────────────────────────────

printf "${BOLD}${CYAN}Dotfiles Test Suite${NC}\n"
printf "${CYAN}═══════════════════════════════════════════════════════════${NC}\n\n"

cd "$REPO_ROOT"

# Find all test files using bash 3.2-compatible approach
# Store test file paths as newline-delimited strings

# Library tests (scripts/_lib/test-install-libs.sh, tmux/scripts/_lib/test-tmux-libs.sh)
LIBRARY_TESTS=$(find . -path "*/_lib/test-*-libs.sh" -type f | sort)

# Tmux script tests
SCRIPT_TESTS=$(find tmux/scripts/tests -name "test-*.sh" -type f | sort)

# Integration tests
INTEGRATION_TESTS=$(find scripts/tests -name "test-*.sh" -type f 2>/dev/null | sort || true)

# Run a test suite (bash 3.2+ compatible - using temp file for test list)
run_suite() {
    local suite_name="$1"
    local tests="$2"  # Newline-delimited test file paths
    
    # Skip if no tests
    if [[ -z "$tests" ]]; then
        return
    fi
    
    reset_suite_counters
    printf "${BOLD}%s${NC}\n" "$suite_name"
    
    # Save IFS and set to newline only for iteration
    local old_IFS="$IFS"
    IFS=$'\n'
    
    # Process each test (newline-delimited)
    for test in $tests; do
        [[ -z "$test" ]] && continue
        run_test "$test"
    done
    
    # Restore IFS
    IFS="$old_IFS"
    
    print_suite_summary "$suite_name"
}

# ──────────────────────────────────────────────────────────────
# Run tests
# ──────────────────────────────────────────────────────────────

run_suite "Library Tests" "$LIBRARY_TESTS"
run_suite "Script Tests" "$SCRIPT_TESTS"
run_suite "Integration Tests" "$INTEGRATION_TESTS"

# ──────────────────────────────────────────────────────────────
# Overall Summary
# ──────────────────────────────────────────────────────────────

printf "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BOLD}Overall Summary${NC}\n"
printf "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
printf "Total:   %d\n" "$GLOBAL_TOTAL"
printf "${GREEN}Passed:  %d${NC}\n" "$GLOBAL_PASSED"
printf "${RED}Failed:  %d${NC}\n" "$GLOBAL_FAILED"
printf "${YELLOW}Skipped: %d${NC}\n" "$GLOBAL_SKIPPED"
printf "\n"

# Exit with appropriate code
if [[ $GLOBAL_FAILED -gt 0 ]]; then
    printf "${RED}${BOLD}Tests failed!${NC}\n"
    exit 1
else
    printf "${GREEN}${BOLD}All tests passed!${NC}\n"
    exit 0
fi
