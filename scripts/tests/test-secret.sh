#!/usr/bin/env bash
set -euo pipefail

# tests for the secret script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRET="$DOTFILES_ROOT/scripts/secret"

source "$SCRIPT_DIR/_test-helpers.sh"

setup_sandbox
trap cleanup_sandbox EXIT
export XDG_CONFIG_HOME="$TEST_HOME/.config"
secrets_file="$XDG_CONFIG_HOME/dotfiles/secrets"

section "get and set"

assert_failure "a missing name fails" "$SECRET" NOPE
assert_failure "an invalid name fails" "$SECRET" "bad-name"

printf 'abc=123 x\n' | "$SECRET" set API_TOKEN >/dev/null
assert_equals "stores a value containing = and spaces" "abc=123 x" "$("$SECRET" API_TOKEN)"
assert_equals "creates the file 600" "600" "$(stat -f %Lp "$secrets_file" 2>/dev/null || stat -c %a "$secrets_file")"

printf 'other\n' | "$SECRET" set OTHER >/dev/null
printf 'new\n' | "$SECRET" set API_TOKEN >/dev/null
assert_equals "set replaces an existing value" "new" "$("$SECRET" API_TOKEN)"
assert_equals "set keeps one line per name" "API_TOKEN OTHER" "$("$SECRET" list | sort | paste -sd' ' -)"
assert_failure "a value passed as an argument is refused" "$SECRET" set ARG_VALUE abc
assert_failure "an empty value is not stored" bash -c "printf '\n' | '$SECRET' set EMPTY"

printf 'API_TOKEN_OLD=x\n' >>"$secrets_file"
assert_equals "a name is not matched by its prefix" "new" "$("$SECRET" API_TOKEN)"

section "import"

cat >"$TEST_HOME/secrets.zsh" <<'EOF'
export IMPORTED="a b"
  export QUOTED='q$x'
export PLACEHOLDER="your_api_key"
export OTHER="from zsh"
# export COMMENTED="nope"
EOF
assert_success "imports the exports" "$SECRET" import "$TEST_HOME/secrets.zsh"
assert_equals "keeps a value with spaces" "a b" "$("$SECRET" IMPORTED)"
assert_equals "keeps a single-quoted value as written" 'q$x' "$("$SECRET" QUOTED)"
assert_equals "leaves a stored value" "other" "$("$SECRET" OTHER)"
assert_failure "skips a placeholder" "$SECRET" PLACEHOLDER
assert_failure "skips a commented export" "$SECRET" COMMENTED

print_summary
[[ "$FAIL" -eq 0 ]] || exit 1
