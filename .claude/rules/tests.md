---
paths:
  - "**/test-*.sh"
  - "**/tests/**"
  - "**/test-*-libs.sh"
  - "scripts/run-tests.sh"
---

# Test Patterns

Tests use a simple pass/fail pattern:
```bash
source "path/to/_test-helpers.sh"  # For tmux tests
section "Test Group Name"
assert_success "description" command args
assert_equals "description" "expected" "$actual"
```

Tmux tests use isolated test servers via `setup_test_server`/`cleanup_test_server`.

## Test Discovery

The test runner (`scripts/run-tests.sh`) automatically discovers all test files:
- Library tests: `*/_lib/test-*-libs.sh`
- Script tests: `tmux/scripts/tests/test-*.sh`
- Integration tests: `scripts/tests/test-*.sh`

Tests requiring tmux are automatically detected and skipped if tmux is not available.

## Test Libraries

**`scripts/_lib/test-install-libs.sh`**: Installation library test suite
- Tests for common.sh, brewfile.sh functionality
- Includes test framework helpers (pass, fail, skip, section)

**`tmux/scripts/_lib/test-tmux-libs.sh`**: Tmux library test suite
- Tests for tmux common.sh, paths.sh, session.sh, alerts.sh
- Includes assertion helpers (assert_success, assert_failure, assert_equals)
