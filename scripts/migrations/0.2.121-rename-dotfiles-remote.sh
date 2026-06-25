#!/usr/bin/env bash
# migration: repoint the dotfiles git remote from the old github account to the
# new one (seanhalberthal -> undont) after the account rename. github's rename
# redirect keeps the old origin url working, but only until the old name is
# reclaimed with a same-named repo, so we move origin to the canonical url and
# stop depending on the redirect
#
# handles both https and ssh remote forms; only touches `origin`
#
# idempotent: no-op once origin is already on the new account

set -euo pipefail

old_owner="seanhalberthal"
new_owner="undont"

# repo root is two levels up from scripts/migrations/
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

remote_url="$(git -C "$repo" remote get-url origin 2>/dev/null)" || {
    echo "    no origin remote, nothing to migrate"
    exit 0
}

case "$remote_url" in
    *"$old_owner"/*) ;;
    *)
        echo "    origin not on $old_owner, nothing to migrate"
        exit 0
        ;;
esac

new_url="${remote_url/$old_owner\//$new_owner/}"
git -C "$repo" remote set-url origin "$new_url"
echo "    dotfiles origin moved to $new_url"
