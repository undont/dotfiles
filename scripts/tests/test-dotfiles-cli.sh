#!/usr/bin/env bash
set -euo pipefail

# Behavioural tests for the dotfiles CLI.
#
# These tests assert the CLI's externally observable behaviour: exit codes,
# stdout/stderr substrings, side effects on a sandbox HOME. They deliberately
# avoid grepping for internal function names so refactors that preserve
# behaviour stay green.
#
# Other concerns (rollback lib, uninstall, create-symlinks, themes, prereqs,
# launchers) live in their own test-*.sh files in this directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOTFILES_CLI="$DOTFILES_DIR/scripts/dotfiles"

# shellcheck source=scripts/tests/_test-helpers.sh
source "$SCRIPT_DIR/_test-helpers.sh"

echo "==========================================="
echo "Dotfiles CLI Behavioural Tests"
echo "==========================================="

# ─── 1. Existence and executable ──────────────────────────────────────

section "CLI script existence"

if [[ -f "$DOTFILES_CLI" ]]; then
    pass "scripts/dotfiles exists"
else
    fail "scripts/dotfiles not found"
fi

if [[ -x "$DOTFILES_CLI" ]]; then
    pass "scripts/dotfiles is executable"
else
    fail "scripts/dotfiles is not executable"
fi

# ─── 2. ShellCheck ─────────────────────────────────────────────────────

section "ShellCheck"

if command -v shellcheck &>/dev/null; then
    for f in \
        "$DOTFILES_DIR/scripts/dotfiles" \
        "$DOTFILES_DIR/scripts/_lib/cli.sh" \
        "$DOTFILES_DIR/scripts/_lib/common.sh"; do
        if [[ -f "$f" ]]; then
            if shellcheck -x -S warning -e SC1091 "$f" 2>/dev/null; then
                pass "shellcheck: $(basename "$f")"
            else
                fail "shellcheck: $(basename "$f") has warnings"
            fi
        fi
    done
else
    skip "shellcheck not installed"
fi

# ─── 3. Help system ────────────────────────────────────────────────────

section "Main help"

main_help=$("$DOTFILES_CLI" help 2>&1)

for cmd in update status health set theme links diff sync aliases notes version edit cd; do
    if [[ "$main_help" == *"$cmd"* ]]; then
        pass "main help mentions '$cmd'"
    else
        fail "main help missing '$cmd'"
    fi
done

if [[ "$main_help" == *"USAGE"* ]]; then
    pass "main help shows USAGE section"
else
    fail "main help should show USAGE section"
fi

section "Top-level help/version flags"

if [[ "$("$DOTFILES_CLI" --help 2>&1)" == *"USAGE"* ]]; then
    pass "--help works"
else
    fail "--help broken"
fi

if [[ "$("$DOTFILES_CLI" -h 2>&1)" == *"USAGE"* ]]; then
    pass "-h works"
else
    fail "-h broken"
fi

if [[ "$("$DOTFILES_CLI" --version 2>&1)" == *"Version:"* ]]; then
    pass "--version works"
else
    fail "--version broken"
fi

if [[ "$("$DOTFILES_CLI" -V 2>&1)" == *"Version:"* ]]; then
    pass "-V works"
else
    fail "-V broken"
fi

section "Per-command help"

for cmd in update status set theme links diff sync notes version aliases health edit cd; do
    out=$("$DOTFILES_CLI" help "$cmd" 2>&1)
    if [[ "$out" == *"$cmd"* ]] && [[ "$out" == *"USAGE"* ]]; then
        pass "dotfiles help $cmd shows per-command help"
    else
        fail "dotfiles help $cmd missing or wrong"
    fi
done

# `--help` on a command must short-circuit before performing any side effect
out=$("$DOTFILES_CLI" update --help 2>&1)
if [[ "$out" == *"USAGE"* ]] && [[ "$out" != *"Fetching from origin"* ]]; then
    pass "update --help short-circuits before fetching"
else
    fail "update --help leaked into command body"
fi

# `dotfiles <cmd> help` should behave like `dotfiles <cmd> --help`
for cmd in update status set links diff sync notes version aliases health edit cd theme; do
    out=$("$DOTFILES_CLI" "$cmd" help 2>&1)
    if [[ "$out" == *"USAGE"* ]]; then
        pass "$cmd help shows usage"
    else
        fail "$cmd help did not show usage"
    fi
done

# Unknown topic falls back to main help with an error
if out=$("$DOTFILES_CLI" help no_such_topic_xyz 2>&1); then
    : # exit code 1 expected — `if` runs negated branch
fi
if [[ "$out" == *"No help available"* ]]; then
    pass "help <unknown> reports a clear error"
else
    fail "help <unknown> should print 'No help available'"
fi

# ─── 4. Per-command behaviour (read-only, no sandbox needed) ──────────

section "cmd_cd"

cd_out=$("$DOTFILES_CLI" cd 2>&1)
if [[ -d "$cd_out" ]]; then
    pass "cd outputs a valid directory"
else
    fail "cd outputs an invalid directory: $cd_out"
fi

# Exactly one line of output (no trailing extra)
cd_lines=$(printf '%s' "$cd_out" | wc -l | tr -d ' ')
if [[ "$cd_lines" == "0" ]]; then
    pass "cd output is single-line (no trailing newline noise)"
else
    fail "cd output should be single-line, got $((cd_lines + 1)) lines"
fi

section "cmd_version"

ver_out=$("$DOTFILES_CLI" version 2>&1)

for label in "Version:" "Preset:" "Branch:" "Path:"; do
    if [[ "$ver_out" == *"$label"* ]]; then
        pass "version output includes '$label'"
    else
        fail "version output missing '$label'"
    fi
done

section "cmd_links"

links_out=$("$DOTFILES_CLI" links 2>&1)

if [[ "$links_out" == *"Managed Symlinks"* ]]; then
    pass "links shows 'Managed Symlinks' header"
else
    fail "links missing header"
fi

for section_name in Zsh Tmux CLI; do
    if [[ "$links_out" == *"$section_name"* ]]; then
        pass "links includes $section_name section"
    else
        fail "links missing $section_name section"
    fi
done

section "cmd_diff"

if "$DOTFILES_CLI" diff >/dev/null 2>&1; then
    pass "diff exits 0 on a healthy install"
else
    # diff exits non-zero only if there are real diffs and `set -e` propagated;
    # the command itself uses `|| true` internally so this should not happen.
    fail "diff exited non-zero unexpectedly"
fi

section "cmd_aliases — real source"

# Run against the real DOTFILES_DIR (no sandbox) — a smoke check that the
# parser produces a coherent cheatsheet for the actual zsh/dotfiles.zsh.
aliases_out=$("$DOTFILES_CLI" aliases 2>&1)

if [[ "$aliases_out" == *"SHELL REFERENCE"* ]]; then
    pass "aliases shows SHELL REFERENCE header"
else
    fail "aliases missing header"
fi

for sect in NAVIGATION FILES GIT TMUX "DOTFILES CLI"; do
    if [[ "$aliases_out" == *"$sect"* ]]; then
        pass "aliases includes section: $sect"
    else
        fail "aliases missing section: $sect"
    fi
done

# A sample of well-known shortcuts must always be present
for entry in gs gd mkcd brewup; do
    if [[ "$aliases_out" == *"$entry"* ]]; then
        pass "aliases includes '$entry'"
    else
        fail "aliases missing '$entry'"
    fi
done

section "cmd_status"

# `status` runs git fetch, so it can take a moment; redirect to /dev/null
if "$DOTFILES_CLI" status >/dev/null 2>&1; then
    pass "status exits 0"
else
    fail "status exits non-zero"
fi

# ─── 5. Flag parsing contract ──────────────────────────────────────────

section "Flag parsing — unknown flag exits 2"

if out=$("$DOTFILES_CLI" update --bogus 2>&1); then
    fail "update --bogus should fail"
else
    code=$?
    if [[ $code -eq 2 ]]; then
        pass "update --bogus exits with code 2"
    else
        fail "update --bogus exited $code, expected 2"
    fi
    if [[ "$out" == *"Unknown option"* ]]; then
        pass "unknown-flag error message"
    else
        fail "unknown-flag message missing 'Unknown option'"
    fi
    if [[ "$out" == *"dotfiles help update"* ]]; then
        pass "unknown-flag points to per-command help"
    else
        fail "unknown-flag does not point to help"
    fi
fi

section "Flag parsing — unknown command exits 1"

if out=$("$DOTFILES_CLI" no_such_command_xyz 2>&1); then
    fail "unknown command should fail"
else
    code=$?
    if [[ $code -eq 1 ]]; then
        pass "unknown command exits 1"
    else
        fail "unknown command exited $code, expected 1"
    fi
    if [[ "$out" == *"Unknown command"* ]]; then
        pass "unknown-command error message"
    else
        fail "unknown-command message missing 'Unknown command'"
    fi
fi

section "Flag parsing — sync --force / -f"

# Just verifies parsing doesn't error; sync is read-only without --force
if "$DOTFILES_CLI" sync >/dev/null 2>&1; then
    pass "sync (no flags) parses and runs"
else
    fail "sync (no flags) failed unexpectedly"
fi

# ─── 6. Side effects in a sandbox ──────────────────────────────────────

section "cmd_set side effects (sandboxed)"

setup_cli_sandbox

cat > "$HOME/.zshrc" << 'EOF'
# YOUR PERSONAL CONFIGURATION
EOF

mkdir -p "$TEST_HOME/src"
"$TEST_DOTFILES_DIR/scripts/dotfiles" set dev "$TEST_HOME/src" >/dev/null

if grep -q '^export DEV_ROOT=' "$HOME/.zshrc"; then
    pass "set dev wrote DEV_ROOT export"
else
    fail "set dev did not write DEV_ROOT"
fi

if grep -qF "$TEST_HOME/src" "$HOME/.zshrc" || grep -qF '$HOME/src' "$HOME/.zshrc"; then
    pass "set dev wrote a path matching the input"
else
    fail "set dev wrote an unexpected path"
fi

# Setting projects too should also write PROJECT_DIRS automatically
mkdir -p "$TEST_HOME/playground"
"$TEST_DOTFILES_DIR/scripts/dotfiles" set projects "$TEST_HOME/playground" >/dev/null

if grep -q '^export PROJECTS_ROOT=' "$HOME/.zshrc"; then
    pass "set projects wrote PROJECTS_ROOT"
else
    fail "set projects did not write PROJECTS_ROOT"
fi

if grep -q '^export PROJECT_DIRS=' "$HOME/.zshrc"; then
    pass "set auto-derives PROJECT_DIRS"
else
    fail "set should auto-derive PROJECT_DIRS"
fi

# Customised PROJECT_DIRS (extra roots appended) is preserved across re-set
# shellcheck disable=SC2016
custom_line='export PROJECT_DIRS="$DEV_ROOT:$PROJECTS_ROOT:$HOME/work"'
# Use awk to replace the auto-generated line with the customised one
awk -v new="$custom_line" '/^export PROJECT_DIRS=/ {print new; next} {print}' "$HOME/.zshrc" > "$HOME/.zshrc.tmp" \
    && mv "$HOME/.zshrc.tmp" "$HOME/.zshrc"

mkdir -p "$TEST_HOME/code"
"$TEST_DOTFILES_DIR/scripts/dotfiles" set dev "$TEST_HOME/code" >/dev/null

if grep -qF '$HOME/work' "$HOME/.zshrc"; then
    pass "set preserves customised PROJECT_DIRS (extra roots intact)"
else
    fail "set should preserve customised PROJECT_DIRS when both refs are present"
fi

# A stale PROJECT_DIRS that doesn't reference both vars should still be rewritten
cat > "$HOME/.zshrc" << 'EOF'
# YOUR PERSONAL CONFIGURATION
export DEV_ROOT="$HOME/src"
export PROJECTS_ROOT="$HOME/playground"
export PROJECT_DIRS="/some/hardcoded/path"
EOF

"$TEST_DOTFILES_DIR/scripts/dotfiles" set dev "$TEST_HOME/src" >/dev/null

# shellcheck disable=SC2016
if grep -qF 'PROJECT_DIRS="$DEV_ROOT:$PROJECTS_ROOT"' "$HOME/.zshrc"; then
    pass "set rewrites stale PROJECT_DIRS missing both refs"
else
    fail "set should rewrite stale PROJECT_DIRS that does not reference both vars"
fi

# Missing argument → exit 2 with hint
if "$TEST_DOTFILES_DIR/scripts/dotfiles" set 2>/dev/null; then
    fail "set with no arg should fail"
else
    code=$?
    if [[ $code -eq 2 ]]; then
        pass "set with no arg exits with code 2"
    else
        fail "set with no arg exited $code, expected 2"
    fi
fi

cleanup_sandbox

# ─── 7. Theme command delegation (Plan 1 fix) ──────────────────────────

section "Theme delegation — child help renders parent name"

# Plan 1 added DOTFILES_INVOKED_AS so child scripts render the canonical
# user-facing command name in their help text instead of the raw basename.
out=$("$DOTFILES_CLI" theme delete help 2>&1)
if [[ "$out" == *"dotfiles theme delete"* ]]; then
    pass "theme delete help shows canonical command name"
else
    fail "theme delete help should show 'dotfiles theme delete'"
fi

if [[ "$out" != *"theme-delete <theme-name>"* ]]; then
    pass "theme delete help no longer leaks 'theme-delete' basename"
else
    fail "theme delete help still leaks internal basename"
fi

out=$("$DOTFILES_CLI" theme generate help 2>&1)
if [[ "$out" == *"dotfiles theme generate"* ]]; then
    pass "theme generate help shows canonical command name"
else
    fail "theme generate help should show 'dotfiles theme generate'"
fi

# Sanity: theme list works
if "$DOTFILES_CLI" theme list >/dev/null 2>&1; then
    pass "theme list runs cleanly"
else
    fail "theme list failed"
fi

# theme help advertises the 'switch' subcommand
out=$("$DOTFILES_CLI" theme --help 2>&1)
if [[ "$out" == *"switch <name>"* ]]; then
    pass "theme help documents 'switch' subcommand"
else
    fail "theme help should document 'switch <name>'"
fi

# 'theme switch' with no arg → exit 2 with hint
if "$DOTFILES_CLI" theme switch >/dev/null 2>&1; then
    fail "theme switch with no arg should fail"
else
    code=$?
    if [[ $code -eq 2 ]]; then
        pass "theme switch with no arg exits with code 2"
    else
        fail "theme switch with no arg exited $code, expected 2"
    fi
fi

# Bare 'theme <name>' is no longer accepted (must use 'theme switch <name>')
if "$DOTFILES_CLI" theme nonexistent-theme-bogus >/dev/null 2>&1; then
    fail "bare 'theme <name>' should be rejected"
else
    code=$?
    if [[ $code -eq 2 ]]; then
        pass "bare 'theme <name>' exits with code 2 (unknown subcommand)"
    else
        fail "bare 'theme <name>' exited $code, expected 2"
    fi
fi

# ─── 8. Library API (rollback lib) ─────────────────────────────────────
# Functional behaviour for the rollback library lives in test-rollback-lib.sh;
# here we just assert the public API is present and callable.

section "Rollback library — public API"

ROLLBACK_LIB="$DOTFILES_DIR/scripts/_lib/rollback.sh"

if [[ -f "$ROLLBACK_LIB" ]]; then
    # shellcheck source=scripts/_lib/rollback.sh
    source "$ROLLBACK_LIB"
    for fn in \
        init_rollback_state \
        record_step \
        get_last_step \
        record_backup_location \
        get_backup_location \
        record_symlink \
        get_created_symlinks \
        has_rollback_state \
        cleanup_rollback_state \
        restore_from_backup \
        perform_rollback; do
        if declare -F "$fn" >/dev/null; then
            pass "rollback lib defines $fn"
        else
            fail "rollback lib missing $fn"
        fi
    done
else
    skip "rollback library not found"
fi

# ─── 9. Cheatsheet parser tests (Plan 2) ───────────────────────────────

section "Cheatsheet — parser behaviour (synthetic source)"

setup_cli_sandbox

# Synthesise a minimal dotfiles.zsh that exercises every parse rule.
cat > "$TEST_DOTFILES_DIR/zsh/dotfiles.zsh" << 'EOF'
# @section: Navigation
alias c="clear"                          # clear screen
alias cl="printf '\033[2J'"              # clear + scrollback
alias _internal="some-thing"             # internal — convention says skip
alias undescribed="thing"

# @section: Git
alias gs="git status -sb"                # short status
# @cheat: mkdir + cd into <dir>
mkcd() { mkdir -p "$1" && cd "$1"; }

# @cheat: Opt+A | cd from history (fzf)
bindkey '\ea' fzf-cd-from-history-widget
EOF

aliases_out=$("$TEST_DOTFILES_DIR/scripts/dotfiles" aliases 2>&1)

# Section detection
if [[ "$aliases_out" == *"NAVIGATION"* ]]; then
    pass "section 'NAVIGATION' rendered (uppercased)"
else
    fail "missing section NAVIGATION"
fi
if [[ "$aliases_out" == *"GIT"* ]]; then
    pass "section 'GIT' rendered"
else
    fail "missing section GIT"
fi

# Alias with description renders
if [[ "$aliases_out" == *"clear screen"* ]]; then
    pass "alias-with-description rendered"
else
    fail "alias 'c' with description should render"
fi
if [[ "$aliases_out" == *"short status"* ]]; then
    pass "git alias rendered"
else
    fail "alias 'gs' should render"
fi

# Alias without description is silently skipped
if [[ "$aliases_out" != *"undescribed"* ]]; then
    pass "alias without description is skipped"
else
    fail "alias without description leaked into output"
fi

# Function with @cheat directive
if [[ "$aliases_out" == *"mkcd"* ]] && [[ "$aliases_out" == *"mkdir + cd into"* ]]; then
    pass "function with @cheat rendered"
else
    fail "function 'mkcd' should render with description"
fi

# Free-form @cheat: <name> | <description>
if [[ "$aliases_out" == *"Opt+A"* ]] && [[ "$aliases_out" == *"cd from history"* ]]; then
    pass "free-form @cheat rendered"
else
    fail "Opt+A free-form @cheat should render"
fi

# Missing source file → clear error and exit 1
rm -f "$TEST_DOTFILES_DIR/zsh/dotfiles.zsh"
if out=$("$TEST_DOTFILES_DIR/scripts/dotfiles" aliases 2>&1); then
    fail "aliases should fail when source missing"
else
    if [[ "$out" == *"Shell source not found"* ]]; then
        pass "missing source produces a clear error"
    else
        fail "missing-source error should mention 'Shell source not found'"
    fi
fi

cleanup_sandbox

section "Cheatsheet — intentional omissions stay omitted"

# Aliases that live in zsh/dotfiles.zsh but are deliberately kept out of
# `dotfiles aliases`. Reasons vary: platform-conditional twins of an already
# described alias, internal implementations behind a shorter public alias,
# or thin wrappers that just prepend `cl &&`.
#
# If you remove an entry, ensure the alias gains a description so it renders.
# If you add one, leave a brief note explaining why it's hidden.
omitted_aliases=(
    "demo-rec"      # asciinema recording (developer-only)
    "pbcopy"        # Linux only — macOS has it natively
    "pbpaste"       # Linux only — macOS has it natively
    "alerts-clear"  # implementation behind the user-facing 'ac'
    "oc"            # opencode shorthand; opencode is already listed
    "ralph"         # cl && ralph wrapper
    "ralf"          # cl && ralf wrapper
    "btop"          # cl && btop wrapper
)

# Run with an empty HOME so the user's real ~/.zshrc can't leak aliases
# into the rendered output.
isolated_home=$(mktemp -d)
aliases_out=$(HOME="$isolated_home" "$DOTFILES_CLI" aliases 2>&1)
rm -rf "$isolated_home"

# Strip ANSI escapes so our column-anchored parsing sees plain text.
stripped=$(printf '%s\n' "$aliases_out" | sed -E $'s/\x1b\\[[0-9;]*m//g')

# Pull the leading word from each rendered column. Cheatsheet rows start with
# two spaces and are separated by " │ "; section headings have no leading
# whitespace, so the regex excludes them.
rendered_names=$(printf '%s\n' "$stripped" | awk -F'│' '
    /^[[:space:]]+[a-zA-Z]/ {
        for (i = 1; i <= NF; i++) {
            field = $i
            sub(/^[[:space:]]+/, "", field)
            split(field, parts, /[[:space:]]+/)
            if (parts[1] ~ /^[a-zA-Z]/) print parts[1]
        }
    }
')

for name in "${omitted_aliases[@]}"; do
    if grep -qFx "$name" <<<"$rendered_names"; then
        fail "alias '$name' rendered in cheatsheet (should be intentionally omitted)"
    else
        pass "alias '$name' kept out of cheatsheet"
    fi
done

# ─── Summary ───────────────────────────────────────────────────────────

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
