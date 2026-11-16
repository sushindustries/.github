#!/usr/bin/env bash
# prev-tag.sh TAG PREFIX   (run inside the git repo)
# Prints the release tag before TAG with the same PREFIX ("v" or "<family>/v"), for release notes.
# A stable TAG compares against earlier stable tags only; a prerelease TAG against any earlier tag.
# Prints nothing when there is no earlier tag. Ordering: X.Y.Z numerically, then a prerelease
# sorts before its stable release (prerelease labels compare as text).
set -euo pipefail

tag="${1:?usage: prev-tag.sh TAG PREFIX}"
prefix="${2:?usage: prev-tag.sh TAG PREFIX}"

# sortable key: 9-digit major.minor.patch, then 1 for stable or 0<label> for a prerelease
key() {
  local v="${1#"$prefix"}" core pre="" a b c
  core="${v%%-*}"
  [ "$core" != "$v" ] && pre="${v#*-}"
  IFS=. read -r a b c <<EOF
$core
EOF
  if [ -n "$pre" ]; then printf '%09d%09d%09d0%s\n' "$a" "$b" "$c" "$pre"
  else printf '%09d%09d%09d1\n' "$a" "$b" "$c"; fi
}

semver='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$'
cur_key="$(key "$tag")"
cur_pre=no
case "${tag#"$prefix"}" in *-*) cur_pre=yes ;; esac

best="" best_key=""
while IFS= read -r t; do
  [ -n "$t" ] && [ "$t" != "$tag" ] || continue
  v="${t#"$prefix"}"
  [[ "$v" =~ $semver ]] || continue
  if [ "$cur_pre" = no ]; then case "$v" in *-*) continue ;; esac; fi
  k="$(key "$t")"
  [[ "$k" < "$cur_key" ]] || continue
  if [ -z "$best_key" ] || [[ "$k" > "$best_key" ]]; then best="$t"; best_key="$k"; fi
done <<EOF
$(git tag -l "${prefix}*")
EOF
[ -n "$best" ] && echo "$best"
exit 0
