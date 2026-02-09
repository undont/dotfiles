#!/usr/bin/env bash
set -euo pipefail

# Unit tests for launcher management scripts:
#   - launchers/list.sh (output format, launcher discovery, dedup)
#   - launchers/run.sh (get_base_session_name, is_fixed_session, metadata)
#   - launchers/delete.sh (repo protection, path traversal guard)
#   - new-launcher.sh (name validation)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LIST_LAUNCHERS="$SCRIPT_DIR/../launchers/list.sh"
RUN_LAUNCHER="$SCRIPT_DIR/../launchers/run.sh"
DELETE_LAUNCHER="$SCRIPT_DIR/../launchers/delete.sh"
NEW_LAUNCHER="$DOTFILES_ROOT/scripts/new-launcher.sh"

# Test counters
PASS=0
FAIL=0
SKIP=0

# Colours
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

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

# ===========================================================================
# launchers/list.sh tests
# ===========================================================================

section "launchers/list.sh: Script Exists and Is Executable"

if [[ -f "$LIST_LAUNCHERS" ]]; then
    pass "launchers/list.sh exists"
else
    fail "launchers/list.sh not found at $LIST_LAUNCHERS"
    exit 1
fi

if [[ -x "$LIST_LAUNCHERS" ]]; then
    pass "launchers/list.sh is executable"
else
    fail "launchers/list.sh is not executable"
fi

section "launchers/list.sh: Shebang"

shebang=$(head -1 "$LIST_LAUNCHERS")
if [[ "$shebang" == "#!/usr/bin/env bash" ]]; then
    pass "uses portable shebang (#!/usr/bin/env bash)"
else
    fail "should use #!/usr/bin/env bash, got: $shebang"
fi

section "launchers/list.sh: ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2155 -e SC2015 -e SC2016 -e SC2034 "$LIST_LAUNCHERS" 2>/dev/null; then
        pass "launchers/list.sh passes shellcheck"
    else
        fail "launchers/list.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "launchers/list.sh: Sources common.sh (no find_dotfiles_root duplication)"

list_content=$(cat "$LIST_LAUNCHERS")

if [[ "$list_content" == *'source "$SCRIPT_DIR/../_lib/common.sh"'* ]]; then
    pass "sources common.sh library"
else
    fail "should source common.sh library"
fi

if [[ "$list_content" == *"find_dotfiles_root"* ]]; then
    fail "should NOT contain find_dotfiles_root (use common.sh instead)"
else
    pass "no find_dotfiles_root duplication"
fi

section "launchers/list.sh: Output Format"

output=$("$LIST_LAUNCHERS" 2>&1) || true

# Should have dotfiles ASCII art logo in header
if [[ "$output" == *'__| | ___ | |_'* ]]; then
    pass "output includes dotfiles logo header"
else
    fail "output should include dotfiles logo header"
fi

# Should list repo launchers (tnew has @description)
if [[ "$output" == *"tnew"* ]]; then
    pass "output lists tnew launcher"
else
    fail "output should list tnew launcher (has @description tag)"
fi

# Should show description from @description tag
if [[ "$output" == *"Dev session"* ]]; then
    pass "output shows tnew description"
else
    fail "output should show tnew @description text"
fi

# code launcher has no @description — should be hidden
if [[ "$output" != *"VS Code"* ]]; then
    pass "launchers without @description are hidden (code)"
else
    fail "launchers without @description should be hidden"
fi

# Template should be excluded
if [[ "$output" != *"launcher.template"* ]]; then
    pass "template file is excluded from listing"
else
    fail "launcher.template should be excluded from listing"
fi

section "launchers/list.sh: Launcher Dedup (user overrides repo)"

# Create temporary user launcher dir with a duplicate name
TEST_XDG=$(mktemp -d)
TEST_USER_DIR="$TEST_XDG/dotfiles/launchers"
mkdir -p "$TEST_USER_DIR"
cat > "$TEST_USER_DIR/tnew" << 'TESTEOF'
#!/usr/bin/env bash
# @description: User override of tnew
echo "user tnew"
TESTEOF
chmod +x "$TEST_USER_DIR/tnew"

dedup_output=$(XDG_CONFIG_HOME="$TEST_XDG" "$LIST_LAUNCHERS" 2>&1) || true
# Strip ANSI for counting
plain_dedup=$(printf '%s' "$dedup_output" | sed 's/\x1b\[[0-9;]*m//g')
tnew_count=$(printf '%s' "$plain_dedup" | grep -c 'tnew' || true)

if [[ "$tnew_count" -eq 1 ]]; then
    pass "dedup: tnew appears exactly once when user overrides repo"
else
    fail "dedup: tnew should appear once, got $tnew_count times"
fi

# User version description should win
if [[ "$dedup_output" == *"User override"* ]]; then
    pass "dedup: user launcher description takes priority"
else
    fail "dedup: user launcher description should override repo"
fi

rm -rf "$TEST_XDG"

# ===========================================================================
# launchers/run.sh tests (pure function logic)
# ===========================================================================

section "launchers/run.sh: Script Exists and Is Executable"

if [[ -f "$RUN_LAUNCHER" ]]; then
    pass "launchers/run.sh exists"
else
    fail "launchers/run.sh not found"
fi

if [[ -x "$RUN_LAUNCHER" ]]; then
    pass "launchers/run.sh is executable"
else
    fail "launchers/run.sh is not executable"
fi

section "launchers/run.sh: ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2155 -e SC2015 -e SC2016 -e SC2034 "$RUN_LAUNCHER" 2>/dev/null; then
        pass "launchers/run.sh passes shellcheck"
    else
        fail "launchers/run.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "launchers/run.sh: get_base_session_name() Regex Parsing"

# Source launchers/run.sh functions by extracting and testing them
# We can't source the whole file (it has side effects), so test via grep/pattern
run_content=$(cat "$RUN_LAUNCHER")

# Verify function exists
if [[ "$run_content" == *"get_base_session_name()"* ]]; then
    pass "get_base_session_name function exists"
else
    fail "get_base_session_name function should exist"
fi

# Test the regex patterns by creating a mini test harness
test_base_session() {
    local input="$1"
    local expected="$2"
    local desc="$3"

    # Replicate the function's logic
    local val="$input"
    local result
    if [[ "$val" =~ :-([^}]+)\} ]]; then
        result="${BASH_REMATCH[1]}"
    else
        # shellcheck disable=SC2016
        result=$(printf '%s' "$val" | tr -d '${}')
    fi

    if [[ "$result" == "$expected" ]]; then
        pass "get_base_session_name: $desc"
    else
        fail "get_base_session_name: $desc (expected '$expected', got '$result')"
    fi
}

# Plain session name
test_base_session "myproject" "myproject" "plain value 'myproject'"

# ${SESSION_NAME:-default} pattern
test_base_session '${SESSION_NAME:-dana}' "dana" '${SESSION_NAME:-dana} extracts default'

# Complex default with dashes
test_base_session '${SESSION_NAME:-my-app}' "my-app" '${SESSION_NAME:-my-app} preserves dashes'

section "launchers/run.sh: is_fixed_session() Detection"

# is_fixed_session returns true when session_value is non-empty
if [[ "$run_content" == *"is_fixed_session()"* ]]; then
    pass "is_fixed_session function exists"
else
    fail "is_fixed_session function should exist"
fi

# tnew has no SESSION= line — should be detected as parameterised
if grep -q '^SESSION=' "$DOTFILES_ROOT/launchers/tnew"; then
    fail "tnew should NOT have a SESSION= line (it's parameterised)"
else
    pass "tnew correctly has no SESSION= line (parameterised launcher)"
fi

# launcher.template has SESSION= — should be detected as fixed
if grep -q '^SESSION=' "$DOTFILES_ROOT/launchers/launcher.template"; then
    pass "launcher.template has SESSION= line (fixed launcher)"
else
    fail "launcher.template should have a SESSION= line"
fi

section "launchers/run.sh: Metadata Extraction"

# Verify @description extraction pattern
if [[ "$run_content" == *'# @description:'* ]]; then
    pass "extracts @description metadata"
else
    fail "should extract @description metadata"
fi

# Verify @instance extraction pattern
if [[ "$run_content" == *'# @instance:'* ]]; then
    pass "extracts @instance metadata"
else
    fail "should extract @instance metadata"
fi

section "launchers/run.sh: Input Sanitisation"

# Check that fzf become() commands sanitise user input
if [[ "$run_content" == *"tr -c '[:alnum:]_.-' '_'"* ]]; then
    pass "sanitises suffix input in become() command"
else
    fail "should sanitise suffix with tr in become() command"
fi

if [[ "$run_content" == *"realpath"* ]]; then
    pass "sanitises directory path with realpath in become() command"
else
    fail "should sanitise directory path with realpath in become() command"
fi

section "launchers/run.sh: DOTFILES_ROOT Validation"

if [[ "$run_content" == *'DOTFILES_ROOT'*'invalid'* ]] || [[ "$run_content" == *'-z "${DOTFILES_ROOT'* ]]; then
    pass "validates DOTFILES_ROOT after sourcing common.sh"
else
    fail "should validate DOTFILES_ROOT is set and valid"
fi

section "launchers/run.sh: fzf Dependency Check"

if [[ "$run_content" == *"require_fzf"* ]]; then
    pass "checks for fzf availability"
else
    fail "should check for fzf availability"
fi

# ===========================================================================
# launchers/delete.sh tests
# ===========================================================================

section "launchers/delete.sh: Script Exists and Is Executable"

if [[ -f "$DELETE_LAUNCHER" ]]; then
    pass "launchers/delete.sh exists"
else
    fail "launchers/delete.sh not found"
fi

if [[ -x "$DELETE_LAUNCHER" ]]; then
    pass "launchers/delete.sh is executable"
else
    fail "launchers/delete.sh is not executable"
fi

section "launchers/delete.sh: ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2155 -e SC2015 -e SC2016 -e SC2034 "$DELETE_LAUNCHER" 2>/dev/null; then
        pass "launchers/delete.sh passes shellcheck"
    else
        fail "launchers/delete.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "launchers/delete.sh: Path Traversal Protection"

del_content=$(cat "$DELETE_LAUNCHER")

if [[ "$del_content" == *"basename"* ]]; then
    pass "uses basename to strip path separators"
else
    fail "should use basename to prevent path traversal"
fi

# Check for dot/dotdot rejection
if [[ "$del_content" == *'".."'* ]] || [[ "$del_content" == *'"."'* ]]; then
    pass "rejects . and .. as launcher names"
else
    fail "should reject . and .. as launcher names"
fi

section "launchers/delete.sh: Repo Launcher Protection"

if [[ "$del_content" == *"Cannot delete repo launcher"* ]]; then
    pass "protects repo launchers from deletion"
else
    fail "should prevent deletion of repo launchers"
fi

if [[ "$del_content" == *"show_visual_confirm"* ]]; then
    pass "shows confirmation dialog before deleting"
else
    fail "should show confirmation before deleting"
fi

# ===========================================================================
# new-launcher.sh tests (name validation)
# ===========================================================================

section "new-launcher.sh: Script Exists and Is Executable"

if [[ -f "$NEW_LAUNCHER" ]]; then
    pass "new-launcher.sh exists"
else
    fail "new-launcher.sh not found"
fi

if [[ -x "$NEW_LAUNCHER" ]]; then
    pass "new-launcher.sh is executable"
else
    fail "new-launcher.sh is not executable"
fi

section "new-launcher.sh: ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2155 -e SC2015 -e SC2016 -e SC2034 "$NEW_LAUNCHER" 2>/dev/null; then
        pass "new-launcher.sh passes shellcheck"
    else
        fail "new-launcher.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "new-launcher.sh: Name Validation"

nl_content=$(cat "$NEW_LAUNCHER")

# sanitise_launcher_name lives in scripts/_lib/common.sh (shared library)
COMMON_LIB="$DOTFILES_ROOT/scripts/_lib/common.sh"
common_lib_content=$(cat "$COMMON_LIB")

# new-launcher.sh should call sanitise_launcher_name (from common.sh)
if [[ "$nl_content" == *"sanitise_launcher_name"* ]]; then
    pass "calls sanitise_launcher_name from shared library"
else
    fail "should call sanitise_launcher_name from shared library"
fi

# Should sanitise special characters
if [[ "$common_lib_content" == *"tr -c '[:alnum:]_.-' '_'"* ]]; then
    pass "sanitises special characters in launcher names"
else
    fail "should sanitise special characters in launcher names"
fi

# Should lowercase names
if [[ "$common_lib_content" == *"tr '[:upper:]' '[:lower:]'"* ]]; then
    pass "lowercases launcher names"
else
    fail "should lowercase launcher names"
fi

# Should strip leading dots/dashes
if [[ "$common_lib_content" == *'strip leading dots/dashes'* ]] || [[ "$common_lib_content" == *'%%[[:alnum:]_]'* ]]; then
    pass "strips leading dots/dashes from names"
else
    fail "should strip leading dots/dashes from names"
fi

# Should enforce length limit
if [[ "$common_lib_content" == *':0:64'* ]] || [[ "$common_lib_content" == *'{name:0:64}'* ]]; then
    pass "enforces 64-character name length limit"
else
    fail "should enforce 64-character name length limit"
fi

# Should block shell reserved words
if [[ "$common_lib_content" == *"test|cd|ls"* ]]; then
    pass "blocks shell reserved words as launcher names"
else
    fail "should block shell reserved words (test, cd, ls, etc.)"
fi

section "new-launcher.sh: Window Count Cap"

if [[ "$nl_content" == *"-gt 20"* ]]; then
    pass "caps maximum window count at 20"
else
    fail "should cap window count at 20"
fi

section "new-launcher.sh: Single-Quote Escaping in Generated Scripts"

if [[ "$nl_content" == *"wcmd=\"\${wcmd//\\'/"* ]] || [[ "$nl_content" == *"Escape single quotes"* ]]; then
    pass "escapes single quotes in generated send-keys commands"
else
    fail "should escape single quotes in user commands for generated scripts"
fi

section "new-launcher.sh: exec < /dev/tty Documentation"

if [[ "$nl_content" == *"Security note"* ]] || [[ "$nl_content" == *"controlling terminal"* ]]; then
    pass "documents exec < /dev/tty security implications"
else
    fail "should document exec < /dev/tty security implications"
fi

# ===========================================================================
# Shared library: launcher path constants
# ===========================================================================

section "Shared Library: Launcher Path Constants"

common_content=$(cat "$DOTFILES_ROOT/tmux/scripts/_lib/common.sh")

if [[ "$common_content" == *"USER_LAUNCHERS="* ]]; then
    pass "common.sh defines USER_LAUNCHERS constant"
else
    fail "common.sh should define USER_LAUNCHERS constant"
fi

if [[ "$common_content" == *"DOTFILES_LAUNCHERS="* ]]; then
    pass "common.sh defines DOTFILES_LAUNCHERS constant"
else
    fail "common.sh should define DOTFILES_LAUNCHERS constant"
fi

if [[ "$common_content" == *"require_fzf()"* ]]; then
    pass "common.sh defines require_fzf helper"
else
    fail "common.sh should define require_fzf helper"
fi

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "==========================================="
echo "Test Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC}"
echo "==========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
