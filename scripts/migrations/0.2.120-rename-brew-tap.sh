#!/bin/bash
# migration: drop the personal homebrew tap from the old github account after the
# account rename (seanhalberthal -> undont). github redirects the old tap url for a
# while, but once the old name is reclaimable that redirect is a liability, so we
# stop tracking the old tap. the Brewfile already points at the new tap, and
# migrations run before `brew bundle`, so the bundle step right after reinstalls
# the formulae from the new tap with no gap
#
# only the old tap name is hardcoded here, so the script is fixed history
#
# idempotent: no-op once the old tap is gone

set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
    echo "    brew not found, skipping tap migration"
    exit 0
fi

old_tap="seanhalberthal/tap"

if ! brew tap 2>/dev/null | grep -qxF "$old_tap"; then
    echo "    $old_tap not tapped, nothing to migrate"
    exit 0
fi

# uninstall the leaf binaries from the old tap so it detaches cleanly; brew bundle
# reinstalls them from the new tap immediately after
for f in supplyscan seeql lazycron jiru; do
    if brew list --formula --versions "$f" >/dev/null 2>&1; then
        echo "    uninstalling $f (old tap)..."
        brew uninstall --formula --ignore-dependencies "$f" >/dev/null 2>&1 || true
    fi
done

echo "    untapping $old_tap..."
brew untap "$old_tap" >/dev/null 2>&1 || true

echo "    old tap removed; brew bundle will reinstall from the new tap"
