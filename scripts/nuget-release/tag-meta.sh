#!/usr/bin/env bash
# tag-meta.sh TAG [FAMILIES_ROOT] [EXCLUDE]
# Turns a release tag into key=value lines (for $GITHUB_OUTPUT):
#   version, prerelease (true|false), family (empty for a whole-repo tag), dir, tag_prefix
# TAG is vX.Y.Z[-pre] (the whole repo) or <family>/vX.Y.Z[-pre] (one folder under FAMILIES_ROOT,
# default "packages"). EXCLUDE is a comma or space list of families this repo must never release
# (stale copies, blocked families). The folder must exist under REPO_ROOT (env, default ".").
# Exit 1 with a message on stderr for a bad tag, an excluded family or a missing folder.
set -euo pipefail

tag="${1:-}"
root="${2:-packages}"
exclude="${3:-}"
repo_root="${REPO_ROOT:-.}"

die() { echo "tag-meta: $*" >&2; exit 1; }
[ -n "$tag" ] || die "usage: tag-meta.sh TAG [FAMILIES_ROOT] [EXCLUDE]"

semver='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$'
family=""
case "$tag" in
  */*)
    family="${tag%%/*}"
    rest="${tag#*/}"
    [[ "$family" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad family name in tag: $tag"
    [[ "$rest" == v* ]] || die "tag must look like <family>/vX.Y.Z: $tag"
    version="${rest#v}"
    prefix="$family/v"
    dir="$root/$family"
    ;;
  v*)
    version="${tag#v}"
    prefix="v"
    dir="."
    ;;
  *) die "tag must be vX.Y.Z or <family>/vX.Y.Z: $tag" ;;
esac

[[ "$version" =~ $semver ]] || die "not a semantic version: $version (tag $tag)"

if [ -n "$family" ] && [ -n "$exclude" ]; then
  for x in ${exclude//,/ }; do
    [ "$x" = "$family" ] && die "family '$family' is excluded from releases in this repo"
  done
fi
[ -d "$repo_root/$dir" ] || die "folder not found: $dir"

prerelease=false
case "$version" in *-*) prerelease=true ;; esac

echo "version=$version"
echo "prerelease=$prerelease"
echo "family=$family"
echo "dir=$dir"
echo "tag_prefix=$prefix"
