#!/usr/bin/env bash
# pack-target.sh DIR
# Prints what to build, test and pack in DIR (relative to DIR): its one top-level *.slnx/*.sln,
# else its one packable *.csproj (has <PackageId> or <IsPackable>true), skipping tests, bin, obj
# and node_modules. Exit 1 when it is not exactly one; the caller then sets the pack-target input.
set -euo pipefail

dir="${1:?usage: pack-target.sh DIR}"
cd "$dir"

slns="$(find . -maxdepth 1 -type f \( -name '*.slnx' -o -name '*.sln' \) | sed 's|^\./||' | sort)"
n="$(printf '%s' "$slns" | grep -c . || true)"
if [ "$n" = 1 ]; then echo "$slns"; exit 0; fi
if [ "$n" -gt 1 ]; then
  echo "pack-target: $n solutions in $dir, set the pack-target input: $(echo "$slns" | tr '\n' ' ')" >&2
  exit 1
fi

projs="$(find . -type f -name '*.csproj' \
  -not -path '*/bin/*' -not -path '*/obj/*' -not -path '*/node_modules/*' \
  -not -name '*Tests.csproj' -not -name '*.Tests.*.csproj' -print0 \
  | xargs -0 grep -l -E '<PackageId>|<IsPackable>[[:space:]]*true' 2>/dev/null | sed 's|^\./||' | sort || true)"
n="$(printf '%s' "$projs" | grep -c . || true)"
if [ "$n" = 1 ]; then echo "$projs"; exit 0; fi
echo "pack-target: found $n packable projects and no solution in $dir, set the pack-target input" >&2
exit 1
