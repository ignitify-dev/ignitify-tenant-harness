#!/bin/sh
# Build the release archive and its checksum for one tag. Run it after you create the tag.
#
#   scripts/release.sh v0.1.0   writes dist/ignitify-tenant-harness-v0.1.0.tar.gz and .sha256
#
# Then attach both files to the GitHub release of that tag. install.sh downloads them.
set -eu

tag=${1:?usage: scripts/release.sh <tag>}
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NAME=ignitify-tenant-harness
cd "$ROOT"

git rev-parse -q --verify "refs/tags/$tag" >/dev/null || { echo "release: no tag $tag" >&2; exit 1; }
# The version in install.sh and plugin.json must name this tag.
git show "$tag:install.sh" | grep -q "^HARNESS_VERSION=\"$tag\"\$" || { echo "release: install.sh HARNESS_VERSION is not $tag" >&2; exit 1; }
git show "$tag:clients/claude-code/.claude-plugin/plugin.json" | grep -q "\"version\": \"${tag#v}\"" ||
  { echo "release: plugin.json version is not ${tag#v}" >&2; exit 1; }

mkdir -p dist
archive="dist/$NAME-$tag.tar.gz"
git archive --format=tar.gz --prefix="$NAME-$tag/" -o "$archive" "$tag"

# Check the files of the tag, not the working tree.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
tar -xzf "$archive" -C "$tmp"
sh "$tmp/$NAME-$tag/scripts/check-commands.sh"
sh "$tmp/$NAME-$tag/scripts/sync-clients.sh" --check
if command -v sha256sum >/dev/null 2>&1; then sum=$(sha256sum "$archive" | awk '{print $1}'); else sum=$(shasum -a 256 "$archive" | awk '{print $1}'); fi
echo "$sum  $NAME-$tag.tar.gz" > "$archive.sha256"
echo "release: $archive"
echo "release: sha256 $sum (put it in the release notes too, for install.sh --sha256)"
