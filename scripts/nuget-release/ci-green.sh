#!/usr/bin/env bash
# ci-green.sh REPO SHA [IGNORE_REGEX]
# Release gate: the commit must have at least one check run, all completed, and every conclusion
# success, neutral or skipped. Check runs whose name matches IGNORE_REGEX (the release workflow's
# own jobs) are left out. Needs gh with GH_TOKEN (checks: read). Exit 1 with the reason otherwise.
set -euo pipefail

repo="${1:?usage: ci-green.sh REPO SHA [IGNORE_REGEX]}"
sha="${2:?usage: ci-green.sh REPO SHA [IGNORE_REGEX]}"
ignore="${3:-}"

runs="$(gh api "repos/$repo/commits/$sha/check-runs?per_page=100" \
  --jq '.check_runs[] | [.name, .status, (.conclusion // "none")] | @tsv')"

total=0 bad=0
while IFS=$'\t' read -r name status conclusion; do
  [ -n "$name" ] || continue
  if [ -n "$ignore" ] && [[ "$name" =~ $ignore ]]; then continue; fi
  total=$((total+1))
  if [ "$status" != completed ]; then
    echo "not finished: $name ($status)" >&2; bad=$((bad+1)); continue
  fi
  case "$conclusion" in
    success|neutral|skipped) echo "green: $name" ;;
    *) echo "not green: $name ($conclusion)" >&2; bad=$((bad+1)) ;;
  esac
done <<EOF
$runs
EOF

[ "$total" -gt 0 ] || { echo "ci-green: no CI check runs on $sha; run CI before tagging" >&2; exit 1; }
[ "$bad" = 0 ] || { echo "ci-green: $bad check run(s) not green on $sha" >&2; exit 1; }
echo "ci-green: $total check run(s) green on $sha"
