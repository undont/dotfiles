#!/usr/bin/env bash
set -euo pipefail

# explicitly trust all currently-installed third-party taps
#
# Homebrew 5.x is deprecating implicit trust of non-official taps: it currently
# trusts them by default but warns once per tap, and a future release will make
# untrusted taps an error. the dotfiles now export HOMEBREW_REQUIRE_TAP_TRUST=1
# to opt into that stricter behaviour early. before enforcement kicks in we
# record every tap the user already has in Homebrew's trust store
# ($HOMEBREW_PREFIX/var/homebrew/trust.json) so nothing they rely on breaks
#
# idempotent: `brew trust --tap` reports "Already trusted" for known taps and
# "always trusted" for official ones, and re-running adds nothing new

if ! command -v brew >/dev/null 2>&1; then
    echo "    brew not found — skipping tap trust"
    exit 0
fi

# `brew trust` only exists on newer Homebrew (5.x+); on older versions there's
# nothing to do, implicit trust is still the only behaviour
if ! brew trust --help >/dev/null 2>&1; then
    echo "    This Homebrew has no \`brew trust\` command — skipping (implicit trust still in effect)"
    exit 0
fi

trusted=0
while read -r tap; do
    [[ -n "$tap" ]] || continue
    # official taps are always trusted; `brew trust` prints a note and is a no-op
    if brew trust --tap "$tap" >/dev/null 2>&1; then
        trusted=$((trusted + 1))
    fi
done < <(brew tap)

echo "    Trusted ${trusted} installed tap(s) (run \`brew tap\` to review)"
