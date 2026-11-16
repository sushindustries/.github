#!/usr/bin/env bash
# Offline tests for scripts/nuget-release/*.sh (no network; gh is a stub).
# Usage: tests/nuget-release.test.sh   (exit 0 = all passed)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
S="$HERE/../scripts/nuget-release"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/nuget-release-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

PASS=0 FAIL=0
eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "ok   - $1"; else FAIL=$((FAIL+1)); echo "FAIL - $1: got [$2] want [$3]"; fi; }
rc() { "$@" >/dev/null 2>&1; echo $?; }

# ---------- tag-meta.sh ----------
R="$TMP/repo"; mkdir -p "$R/packages/seo" "$R/packages/commerce"
meta() { (cd "$R" && bash "$S/tag-meta.sh" "$@" 2>/dev/null); }
get() { meta "${@:2}" | sed -n "s/^$1=//p"; }

eq "whole-repo tag: version"      "$(get version v18.1.0)" "18.1.0"
eq "whole-repo tag: dir"          "$(get dir v18.1.0)" "."
eq "whole-repo tag: prefix"       "$(get tag_prefix v18.1.0)" "v"
eq "whole-repo tag: no family"    "$(get family v18.1.0)" ""
eq "stable is not prerelease"     "$(get prerelease v18.1.0)" "false"
eq "rc is prerelease"             "$(get prerelease v18.1.0-rc.1)" "true"
eq "family tag: family"           "$(get family seo/v18.0.2)" "seo"
eq "family tag: dir"              "$(get dir seo/v18.0.2)" "packages/seo"
eq "family tag: prefix"           "$(get tag_prefix seo/v18.0.2)" "seo/v"
eq "family tag: custom root"      "$(cd "$R" && mkdir -p src/x && bash "$S/tag-meta.sh" x/v1.0.0 src | sed -n 's/^dir=//p')" "src/x"
eq "bad: no v"                    "$(rc meta 18.1.0)" 1
eq "bad: not semver"              "$(rc meta v18.1)" 1
eq "bad: family without v"        "$(rc meta seo/18.0.0)" 1
eq "bad: uppercase family"        "$(rc meta Seo/v1.0.0)" 1
eq "bad: missing folder"          "$(rc meta forms/v1.0.0)" 1
eq "excluded family refused"      "$(rc meta commerce/v1.0.0 packages "deploy,commerce")" 1
eq "other family still allowed"   "$(rc meta seo/v1.0.0 packages "deploy,commerce")" 0
eq "no args"                      "$(rc meta)" 1

# ---------- prev-tag.sh ----------
G="$TMP/git"; git init -q "$G"; git -C "$G" commit -q --allow-empty -m init
for t in v1.0.0 v1.2.0 v1.10.0 v1.10.1-rc.1 v2.0.0-rc.1 seo/v18.0.0 seo/v18.0.1 other; do git -C "$G" tag "$t"; done
prev() { (cd "$G" && bash "$S/prev-tag.sh" "$@"); }
eq "prev: numeric order (1.10 > 1.2)"      "$(prev v1.10.1 v)" "v1.10.0"
eq "prev: stable skips prereleases"        "$(prev v2.0.0 v)" "v1.10.0"
eq "prev: prerelease sees earlier pre"     "$(prev v2.0.0-rc.2 v)" "v2.0.0-rc.1"
eq "prev: rc sorts before its release"     "$(prev v1.10.1 v)" "v1.10.0"
eq "prev: first tag has none"              "$(prev v1.0.0 v)" ""
eq "prev: family prefix only"              "$(prev seo/v18.0.2 seo/v)" "seo/v18.0.1"
eq "prev: family first release"            "$(prev forms/v1.0.0 forms/v)" ""

# ---------- pack-target.sh ----------
P="$TMP/pack"; mkdir -p "$P/one" "$P/two" "$P/proj/src/A" "$P/proj/tests/A.Tests" "$P/none" "$P/many/src/A" "$P/many/src/B"
touch "$P/one/X.slnx" "$P/two/A.sln" "$P/two/B.slnx"
printf '<Project><PropertyGroup><PackageId>A</PackageId></PropertyGroup></Project>' > "$P/proj/src/A/A.csproj"
printf '<Project><PropertyGroup><IsPackable>true</IsPackable></PropertyGroup></Project>' > "$P/proj/tests/A.Tests/A.Tests.csproj"
printf '<Project/>' > "$P/none/Lib.csproj"
printf '<Project><PropertyGroup><PackageId>A</PackageId></PropertyGroup></Project>' > "$P/many/src/A/A.csproj"
printf '<Project><PropertyGroup><IsPackable>true</IsPackable></PropertyGroup></Project>' > "$P/many/src/B/B.csproj"
eq "pack: one solution"                 "$(bash "$S/pack-target.sh" "$P/one" 2>/dev/null)" "X.slnx"
eq "pack: two solutions refused"        "$(rc bash "$S/pack-target.sh" "$P/two")" 1
eq "pack: one packable project, tests skipped" "$(bash "$S/pack-target.sh" "$P/proj" 2>/dev/null)" "src/A/A.csproj"
eq "pack: nothing packable refused"     "$(rc bash "$S/pack-target.sh" "$P/none")" 1
eq "pack: several projects refused"     "$(rc bash "$S/pack-target.sh" "$P/many")" 1

# ---------- verify-packages.sh ----------
V="$TMP/out"; mkdir -p "$V/good" "$V/bad" "$V/empty"
touch "$V/good/Sush.Seo.18.0.2.nupkg" "$V/good/Sush.Seo.18.0.2.snupkg" "$V/good/Sush.Seo.Core.18.0.2.nupkg"
touch "$V/bad/Sush.Seo.18.0.2.nupkg" "$V/bad/Sush.Seo.Core.0.1.0.nupkg"
eq "verify: all at version"            "$(rc bash "$S/verify-packages.sh" "$V/good" 18.0.2)" 0
eq "verify: one at another version"    "$(rc bash "$S/verify-packages.sh" "$V/bad" 18.0.2)" 1
eq "verify: prefix of version not enough" "$(rc bash "$S/verify-packages.sh" "$V/good" 18.0)" 1
eq "verify: empty output refused"      "$(rc bash "$S/verify-packages.sh" "$V/empty" 1.0.0)" 1

# ---------- ci-green.sh (stub gh prints $STUB_RUNS) ----------
B="$TMP/bin"; mkdir -p "$B"
printf '#!/usr/bin/env bash\nprintf "%%b" "$STUB_RUNS"\n' > "$B/gh"; chmod +x "$B/gh"
green() { STUB_RUNS="$1" PATH="$B:$PATH" bash "$S/ci-green.sh" o/r abc "${2:-}" >/dev/null 2>&1; echo $?; }
eq "ci: all success"                 "$(green 'checks\tcompleted\tsuccess\nlint\tcompleted\tskipped\n')" 0
eq "ci: one failure"                 "$(green 'checks\tcompleted\tsuccess\ntests\tcompleted\tfailure\n')" 1
eq "ci: one still running"           "$(green 'checks\tin_progress\tnone\n')" 1
eq "ci: no runs at all"              "$(green '')" 1
eq "ci: own release job ignored"     "$(green 'checks\tcompleted\tsuccess\nrelease / release\tin_progress\tnone\n' '^release')" 0
eq "ci: only own job is not enough"  "$(green 'release / release\tin_progress\tnone\n' '^release')" 1

echo "# $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
