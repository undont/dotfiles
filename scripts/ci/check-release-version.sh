#!/usr/bin/env bash
# Guard against unreleased changes landing on main without a version bump.
#
# The auto-tag job reads the topmost dated `## [X.Y.Z]` heading from
# CHANGELOG.md and tags it. If commits land past the latest release tag
# without a new dated heading (e.g. entries left under `[Unreleased]`), the
# tag already exists, auto-tag silently skips, and `dotfiles update` never
# surfaces the change. This check turns that silent miss into a loud failure.
#
# Bypass: include `[skip release]` in a commit message in the range for
# changes that intentionally ship no release (docs/tooling tweaks).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHANGELOG="$DOTFILES_DIR/CHANGELOG.md"

# Topmost dated version (skips [Unreleased]) — what auto-tag would tag.
version=$(sed -n 's/^## \[\([0-9][^]]*\)\].*/\1/p' "$CHANGELOG" | head -1)
if [[ -z "$version" ]]; then
    echo "::error::No dated '## [X.Y.Z]' heading found in CHANGELOG.md"
    exit 1
fi
tag="v${version}"

# Tag doesn't exist yet → this push/PR introduces the bump. auto-tag handles it.
if ! git rev-parse -q --verify "refs/tags/${tag}" >/dev/null 2>&1; then
    echo "CHANGELOG tops out at ${version}; ${tag} not tagged yet — this is a release bump. OK"
    exit 0
fi

# Tag exists. Anything new on top of it?
count=$(git rev-list --count "${tag}..HEAD")
if [[ "$count" -eq 0 ]]; then
    echo "No commits since ${tag}. OK"
    exit 0
fi

# Explicit opt-out for intentional non-release commits.
if git log --format='%B' "${tag}..HEAD" | grep -qiF '[skip release]'; then
    echo "::notice::${count} commit(s) since ${tag} with no version bump, but [skip release] is present — allowed"
    exit 0
fi

# Otherwise: content has shipped past a release with no new dated heading.
{
    echo "::error::${count} commit(s) have landed since ${tag} but CHANGELOG.md still tops out at ${version}."
    echo "Promote the [Unreleased] entries to a new dated heading, e.g.:"
    echo "    ## [<next-version>] - $(date +%Y-%m-%d)"
    echo "Or, if this change intentionally ships no release, add [skip release] to a commit message."
    echo "Unreleased commits:"
    git log --oneline "${tag}..HEAD"
} >&2
exit 1
