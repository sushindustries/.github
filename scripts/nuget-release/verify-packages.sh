#!/usr/bin/env bash
# verify-packages.sh DIR VERSION
# Checks the pack output: at least one *.nupkg, and every *.nupkg / *.snupkg carries VERSION
# (name ends in .VERSION.nupkg). Prints the package list. Exit 1 otherwise, so a project that
# ignored the tag version can never be published.
set -euo pipefail

dir="${1:?usage: verify-packages.sh DIR VERSION}"
version="${2:?usage: verify-packages.sh DIR VERSION}"
[ -d "$dir" ] || { echo "verify-packages: no folder $dir" >&2; exit 1; }

count=0 bad=0
for f in "$dir"/*.nupkg "$dir"/*.snupkg; do
  [ -e "$f" ] || continue
  name="$(basename "$f")"
  case "$name" in
    *".$version.nupkg"|*".$version.snupkg") echo "ok  $name" ;;
    *) echo "BAD $name (want version $version)" >&2; bad=$((bad+1)) ;;
  esac
  case "$name" in *.nupkg) count=$((count+1)) ;; esac
done

[ "$count" -gt 0 ] || { echo "verify-packages: no .nupkg in $dir" >&2; exit 1; }
[ "$bad" = 0 ] || { echo "verify-packages: $bad package(s) without version $version" >&2; exit 1; }
echo "verify-packages: $count package(s) at $version"
