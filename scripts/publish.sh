#!/bin/bash
# Publish one harness release on GitHub: check, tag, build the archive, create the release, check it.
#
#   bash scripts/publish.sh v0.1.5 notes.md
#
# notes.md holds only the change lines a user can see (one "- ..." line each). The script adds the
# minimum CLI (the first line of cli/commands.txt), the install line and the archive checksum.
# Needs git, gh (signed in, write access), curl and shasum. Run it from the root of a checkout, on a
# clean main that matches origin/main, after the version bump is committed and pushed.
set -euo pipefail

TAG=${1:?usage: bash scripts/publish.sh <tag> <notes-file>}
CHANGES=${2:?usage: bash scripts/publish.sh <tag> <notes-file>}
NAME=ignitify-tenant-harness
REPO=ignitify-dev/$NAME

test -s "$CHANGES" || { echo "notes file $CHANGES is missing or empty" >&2; exit 1; }

# 1. Clean tree on main, in step with GitHub, and the tag is new.
test "$(git branch --show-current)" = main || { echo "not on main" >&2; exit 1; }
test -z "$(git status --porcelain)" || { echo "the working tree is not clean" >&2; exit 1; }
git fetch -q origin
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || { echo "main differs from origin/main: push first" >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then echo "tag $TAG exists already" >&2; exit 1; fi

# 2. The docs name only commands and flags of the CLI this release was checked against.
CLI=$(head -1 cli/commands.txt | sed -n 's/^# cli //p')
test -n "$CLI" || { echo "cli/commands.txt line 1 does not name a CLI version" >&2; exit 1; }
sh scripts/check-commands.sh
sh scripts/sync-clients.sh --check

# 3. Tag, push the tag, build the archive and its checksum.
git tag -a "$TAG" -m "$TAG"
git push origin "$TAG"
sh scripts/release.sh "$TAG"
SUM=$(cut -d' ' -f1 "dist/$NAME-$TAG.tar.gz.sha256")

# 4. The GitHub release.
NOTES=$(mktemp)
trap 'rm -f "$NOTES"' EXIT
{
  printf 'For the ignitify CLI %s (the minimum).\n\n' "$CLI"
  cat "$CHANGES"
  printf '\nInstall (Claude Code):\n\n```sh\n'
  printf 'curl -fsSL https://raw.githubusercontent.com/%s/%s/install.sh | sh -s -- --client claude-code\n' "$REPO" "$TAG"
  printf '```\n\nSHA-256 of `%s-%s.tar.gz` (for `install.sh --sha256`):\n`%s`\n' "$NAME" "$TAG" "$SUM"
} > "$NOTES"
gh release create "$TAG" "dist/$NAME-$TAG.tar.gz" "dist/$NAME-$TAG.tar.gz.sha256" --title "$TAG" --notes-file "$NOTES"

# 5. Check: the release has both files, and the published checksum matches.
gh release view "$TAG" --json assets -q '[.assets[].name]'
GOT=$(curl -fsSL "https://github.com/$REPO/releases/download/$TAG/$NAME-$TAG.tar.gz" | shasum -a 256 | cut -d' ' -f1)
if [ "$GOT" = "$SUM" ]; then echo "publish: OK ($TAG, checksum $SUM)"; else echo "publish: checksum MISMATCH: published $GOT, built $SUM" >&2; exit 1; fi
