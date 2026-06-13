#!/usr/bin/env bash
# unit tests for pick-url.sh URL extraction logic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PICK_URL_SCRIPT="$SCRIPT_DIR/../utils/pick-url.sh"

source "$SCRIPT_DIR/_test-helpers.sh"

# source only the extract_urls function from pick-url.sh
# we extract it to avoid sourcing the full script (which has side effects)
eval "$(sed -n '/^extract_urls()/,/^}/p' "$PICK_URL_SCRIPT")"

# helper: assert a single URL is extracted correctly from input text
assert_extracts() {
    local description="$1"
    local input="$2"
    local expected="$3"
    local actual
    actual=$(printf '%s\n' "$input" | extract_urls)
    if [[ "$actual" == "$expected" ]]; then
        pass "$description"
    else
        fail "$description — expected '$expected', got '$actual'"
    fi
}

# helper: assert multiple URLs are extracted (newline-separated expected)
assert_extracts_multi() {
    local description="$1"
    local input="$2"
    local expected="$3"
    local actual
    actual=$(printf '%s\n' "$input" | extract_urls)
    if [[ "$actual" == "$expected" ]]; then
        pass "$description"
    else
        fail "$description"
        printf "    expected: %s\n" "$(echo "$expected" | tr '\n' ' ')"
        printf "    got:      %s\n" "$(echo "$actual" | tr '\n' ' ')"
    fi
}

# helper: assert no URLs are extracted
assert_no_urls() {
    local description="$1"
    local input="$2"
    local actual
    actual=$(printf '%s\n' "$input" | extract_urls) || true
    if [[ -z "$actual" ]]; then
        pass "$description"
    else
        fail "$description — expected no URLs, got '$actual'"
    fi
}

# ===========================================================================
# tests
# ===========================================================================

section "Script exists and is executable"

if [[ -f "$PICK_URL_SCRIPT" ]]; then
    pass "pick-url.sh exists"
else
    fail "pick-url.sh not found at $PICK_URL_SCRIPT"
    exit 1
fi

if [[ -x "$PICK_URL_SCRIPT" ]]; then
    pass "pick-url.sh is executable"
else
    fail "pick-url.sh is not executable"
fi

section "ShellCheck validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x "$PICK_URL_SCRIPT" 2>/dev/null; then
        pass "shellcheck passes"
    else
        fail "shellcheck reports issues"
    fi
else
    skip "shellcheck not installed"
fi

section "Basic URL extraction"

assert_extracts "simple https URL" \
    "visit https://example.com for more" \
    "https://example.com"

assert_extracts "simple http URL" \
    "go to http://example.com now" \
    "http://example.com"

assert_extracts "URL with path" \
    "see https://example.com/foo/bar" \
    "https://example.com/foo/bar"

assert_extracts "URL with query string" \
    "link: https://example.com/search?q=test&page=1" \
    "https://example.com/search?q=test&page=1"

assert_extracts "URL with fragment" \
    "see https://example.com/page#section" \
    "https://example.com/page#section"

assert_extracts "URL with port" \
    "running at https://localhost:3000/api" \
    "https://localhost:3000/api"

section "Trailing punctuation stripping"

assert_extracts "trailing comma" \
    "go to https://gist.github.com, create one" \
    "https://gist.github.com"

assert_extracts "trailing period" \
    "Visit https://example.com/page." \
    "https://example.com/page"

assert_extracts "trailing semicolon" \
    "see https://example.com/path;" \
    "https://example.com/path"

assert_extracts "trailing colon" \
    "check https://example.com:" \
    "https://example.com"

assert_extracts "trailing exclamation" \
    "wow https://example.com/cool!" \
    "https://example.com/cool"

assert_extracts "trailing question mark" \
    "is it https://example.com/real?" \
    "https://example.com/real"

assert_extracts "multiple trailing punctuation" \
    "really https://example.com/wow!." \
    "https://example.com/wow"

assert_extracts "trailing ellipsis" \
    "see https://example.com/page..." \
    "https://example.com/page"

section "Balanced parentheses"

assert_extracts "unbalanced trailing paren stripped" \
    "link: https://example.com/foo)" \
    "https://example.com/foo"

assert_extracts "balanced parens preserved (wikipedia style)" \
    "wiki https://en.wikipedia.org/wiki/Foo_(bar) is great" \
    "https://en.wikipedia.org/wiki/Foo_(bar)"

assert_extracts "markdown link — unbalanced paren stripped" \
    "[click here](https://example.com/path)" \
    "https://example.com/path"

assert_extracts "unbalanced bracket stripped" \
    "url https://example.com/api]" \
    "https://example.com/api"

section "Quoting and delimiters"

assert_extracts "double-quoted URL" \
    'see "https://example.com/test" for info' \
    "https://example.com/test"

assert_extracts "single-quoted URL" \
    "it's at 'https://example.com/foo' here" \
    "https://example.com/foo"

assert_extracts "angle-bracketed URL" \
    "link <https://example.com/resource> here" \
    "https://example.com/resource"

section "Multiple URLs"

assert_extracts_multi "multiple URLs on one line" \
    "see https://a.com, https://b.com." \
    "$(printf '%s\n' 'https://a.com' 'https://b.com')"

assert_extracts_multi "URLs across multiple lines" \
    "$(printf '%s\n' 'first https://example.com/one' 'second https://example.com/two')" \
    "$(printf '%s\n' 'https://example.com/one' 'https://example.com/two')"

section "Deduplication"

assert_extracts "duplicate URLs deduplicated" \
    "$(printf '%s\n' 'https://example.com' 'https://example.com')" \
    "https://example.com"

assert_extracts_multi "different URLs both kept" \
    "$(printf '%s\n' 'https://a.com' 'https://b.com')" \
    "$(printf '%s\n' 'https://a.com' 'https://b.com')"

section "Edge cases"

assert_no_urls "no URLs in text" \
    "this is just regular text with no links"

assert_no_urls "ftp is not matched" \
    "ftp://files.example.com/pub"

assert_extracts "URL with encoded chars" \
    "https://example.com/path%20with%20spaces" \
    "https://example.com/path%20with%20spaces"

assert_extracts "URL with tilde" \
    "https://example.com/~user/page" \
    "https://example.com/~user/page"

assert_extracts "URL with dash in domain" \
    "https://my-site.example.com/page" \
    "https://my-site.example.com/page"

assert_extracts "URL ending with slash" \
    "see https://example.com/path/" \
    "https://example.com/path/"

assert_extracts "GitHub URL with trailing comma (original bug)" \
    "1. Create a gist — go to https://gist.github.com, create one with any content" \
    "https://gist.github.com"

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
