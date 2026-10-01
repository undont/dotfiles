#!/usr/bin/env bash
# shared test helpers for the scripts/tests/ and scripts/_lib/ suites

_SCRIPTS_TEST_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$_SCRIPTS_TEST_HELPERS_DIR/../.." && pwd)"

# shellcheck source=scripts/_lib/colours.sh
source "$DOTFILES_ROOT/scripts/_lib/colours.sh"

PASS=0
FAIL=0
SKIP=0

pass() {
    PASS=$((PASS + 1))
    printf "${GREEN}✓${NC} %s\n" "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf "${RED}✗${NC} %s\n" "$1"
}

skip() {
    SKIP=$((SKIP + 1))
    printf "${YELLOW}○${NC} %s (skipped)\n" "$1"
}

section() {
    echo ""
    echo "─────────────────────────────────────────"
    echo "$1"
    echo "─────────────────────────────────────────"
}

assert_success() {
    local desc="$1"
    shift
    if "$@" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

assert_failure() {
    local desc="$1"
    shift
    if ! "$@" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

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

# points HOME at a temp dir. sets TEST_DIR, TEST_HOME, ORIGINAL_HOME
setup_sandbox() {
    TEST_DIR=$(mktemp -d)
    TEST_HOME="$TEST_DIR/home"
    mkdir -p "$TEST_HOME"
    ORIGINAL_HOME="$HOME"
    export HOME="$TEST_HOME"
}

cleanup_sandbox() {
    export HOME="$ORIGINAL_HOME"
    # setup_dotfiles_sandbox and setup_cli_sandbox override DOTFILES_DIR;
    # restore the prior value, or unset it if there was none
    if [[ -n "${_ORIGINAL_DOTFILES_DIR+x}" ]]; then
        if [[ -z "$_ORIGINAL_DOTFILES_DIR" ]]; then
            unset DOTFILES_DIR
        else
            export DOTFILES_DIR="$_ORIGINAL_DOTFILES_DIR"
        fi
        unset _ORIGINAL_DOTFILES_DIR
    fi
    rm -rf "$TEST_DIR"
}

# setup_sandbox plus an empty TEST_DOTFILES_DIR exported as DOTFILES_DIR
setup_dotfiles_sandbox() {
    setup_sandbox
    TEST_DOTFILES_DIR="$TEST_DIR/dotfiles"
    mkdir -p "$TEST_DOTFILES_DIR"
    _ORIGINAL_DOTFILES_DIR="${DOTFILES_DIR:-}"
    export DOTFILES_DIR="$TEST_DOTFILES_DIR"
}

# dotfiles tree for CLI tests: scripts, themes and launchers are symlinks to
# the real ones; the CHANGELOG is fake, zsh/ is empty and ~/.zshrc is blank
setup_cli_sandbox() {
    setup_dotfiles_sandbox

    ln -s "$DOTFILES_ROOT/scripts" "$TEST_DOTFILES_DIR/scripts"
    ln -s "$DOTFILES_ROOT/themes" "$TEST_DOTFILES_DIR/themes"
    ln -s "$DOTFILES_ROOT/launchers" "$TEST_DOTFILES_DIR/launchers"
    # tests write a synthesised cheatsheet source into zsh/
    mkdir -p "$TEST_DOTFILES_DIR/zsh"

    cat >"$TEST_DOTFILES_DIR/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

### Added
- Fake unreleased entry for testing.

## [9.9.9] - 2099-01-01

### Added
- Fake released entry for testing.
EOF

    touch "$TEST_HOME/.zshrc"
}

# runs the sandbox CLI with stderr merged into stdout
# usage: dotfiles_run update --preview
dotfiles_run() {
    "$TEST_DOTFILES_DIR/scripts/dotfiles" "$@" 2>&1
}

print_summary() {
    echo ""
    echo "==========================================="
    printf "Test Results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}" "$PASS" "$FAIL"
    if [[ $SKIP -gt 0 ]]; then
        printf ", ${YELLOW}%d skipped${NC}" "$SKIP"
    fi
    echo ""
    echo "==========================================="
}
