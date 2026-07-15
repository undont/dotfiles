#!/usr/bin/env bash
# recursively mirror a directory tree off an unmounted ext2/3/4 image using
# e2tools, since e2ls has no -R and e2cp only takes single files.
# symlinks are logged, not followed -- e2cp can't safely resolve them.
#
# usage:
#   ./e2backup.sh [--dry-run] <remote-path> <local-dest-dir>
#
# env:
#   E2_DEV    raw device or image file to read from (default /dev/rdisk13s2)
#   E2_SUDO   set to 0 to skip sudo (e.g. reading a local image file you own)

set -euo pipefail

DEV="${E2_DEV:-/dev/rdisk13s2}"
SUDO="${E2_SUDO:-1}"
[[ "$SUDO" == "1" ]] && SUDO_CMD=sudo || SUDO_CMD=""
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

REMOTE_ROOT="${1:?usage: e2backup.sh [--dry-run] <remote-path> <local-dest-dir>}"
LOCAL_ROOT="${2:?usage: e2backup.sh [--dry-run] <remote-path> <local-dest-dir>}"

walk() {
  local remote="$1" local="$2"
  [[ $DRY_RUN -eq 0 ]] && mkdir -p "$local"

  while IFS=$'\t' read -r perm name; do
    [[ "$name" == "." || "$name" == ".." || -z "$name" ]] && continue
    case "$perm" in
      d*)
        walk "$remote/$name" "$local/$name"
        ;;
      l*)
        echo "SYMLINK (skipped): $remote/$name" >&2
        ;;
      -*)
        if [[ $DRY_RUN -eq 1 ]]; then
          echo "$remote/$name"
        else
          echo "-> $local/$name"
          $SUDO_CMD e2cp -p "$DEV:$remote/$name" "$local/$name"
        fi
        ;;
      *)
        echo "unknown entry type ($perm): $remote/$name" >&2
        ;;
    esac
  done < <($SUDO_CMD e2ls -al "$DEV:$remote" | awk '{
      perm=$2
      name=$8
      for (i=9;i<=NF;i++) name=name" "$i
      print perm"\t"name
    }')
}

walk "$REMOTE_ROOT" "$LOCAL_ROOT"
