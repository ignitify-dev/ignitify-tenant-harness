#!/bin/sh
# Install the Ignitify tenant harness for an AI client. No root, no npm.
#
#   curl -fsSL https://raw.githubusercontent.com/ignitify-dev/ignitify-tenant-harness/v0.1.4/install.sh | sh -s -- --client claude-code
#
# Options:
#   --client claude-code|generic   what to install (required)
#                                  claude-code: skills and slash commands into .claude/
#                                  generic:     skills, prompts, templates, examples and the AGENTS.md block into .ignitify-harness/
#   --scope user|project           claude-code only: user = ~/.claude (default), project = ./.claude
#   --version <tag>                the release to install (default: the tag this script belongs to)
#   --sha256 <hex>                 the expected checksum of the release archive (default: the published .sha256 file)
#   --from <dir>                   copy from a local checkout instead of downloading
#   --force                        replace files that this script did not install, or that you changed
#   --uninstall                    remove exactly the files the last install wrote (changed files are kept)
#
# Every install writes a manifest (.ignitify-harness.manifest) beside what it installed: one line per
# file with its sha256. A new install replaces only unchanged files of the old manifest and removes
# the ones the new release no longer has. --uninstall reads it.
set -eu

usage() {
  cat <<'USAGE'
Usage: install.sh --client claude-code|generic [--scope user|project] [--version <tag>]
                  [--sha256 <hex>] [--from <dir>] [--force] [--uninstall]
  --client claude-code  skills and slash commands into ~/.claude (or ./.claude with --scope project)
  --client generic      skills, prompts, templates, examples and an AGENTS.md block into ./.ignitify-harness
  --version <tag>       the release to install
  --sha256 <hex>        the expected checksum of the release archive (from the release notes)
  --from <dir>          copy from a local checkout; no download, no checksum
  --force               replace files that this script did not install, or that you changed
  --uninstall           remove exactly the files the last install wrote (changed files are kept)
USAGE
}

HARNESS_VERSION="v0.1.4"
REPO="ignitify-dev/ignitify-tenant-harness"
NAME="ignitify-tenant-harness"
MANIFEST_NAME=".ignitify-harness.manifest"

client="" scope="user" version="$HARNESS_VERSION" want_sum="" from="" force=0 uninstall=0

die() { echo "install.sh: $*" >&2; exit 1; }
say() { echo "install.sh: $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --client) client=${2:-}; shift 2 ;;
    --scope) scope=${2:-}; shift 2 ;;
    --version) version=${2:-}; shift 2 ;;
    --sha256) want_sum=${2:-}; shift 2 ;;
    --from) from=${2:-}; shift 2 ;;
    --force) force=1; shift ;;
    --uninstall) uninstall=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

[ "$(id -u)" -ne 0 ] || die "do not run as root"
want_sum=$(printf '%s' "$want_sum" | tr 'A-F' 'a-f')
case "$client" in claude-code|generic) ;; *) die "--client must be claude-code or generic" ;; esac
case "$scope" in user|project) ;; *) die "--scope must be user or project" ;; esac

# Where the files go, by client and scope.
if [ "$client" = claude-code ]; then
  if [ "$scope" = user ]; then base="$HOME/.claude"; else base="$PWD/.claude"; fi
else
  base="$PWD/.ignitify-harness"
fi
manifest="$base/$MANIFEST_NAME"
# --scope means something for claude-code only, so the generic hint leaves it out.
if [ "$client" = claude-code ]; then scope_arg=" --scope $scope"; else scope_arg=""; fi
remove_hint="curl -fsSL https://raw.githubusercontent.com/$REPO/$HARNESS_VERSION/install.sh | sh -s -- --client $client$scope_arg --uninstall"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else die "need sha256sum or shasum"; fi
}

# ---- uninstall -------------------------------------------------------------------------------------
if [ "$uninstall" -eq 1 ]; then
  [ -f "$manifest" ] || die "no manifest at $manifest: nothing to remove"
  grep -v '^#' "$manifest" | while read -r sum rel; do
    f="$base/$rel"
    [ -f "$f" ] || continue
    if [ "$(sha256_of "$f")" = "$sum" ]; then rm -f "$f"
    else echo "install.sh: kept $f (changed after install)" >&2; fi
  done
  # Remove the folders the install created, deepest first, only when empty.
  grep -v '^#' "$manifest" | awk '{print $2}' | while read -r rel; do
    d=$(dirname "$rel")
    while [ "$d" != "." ]; do echo "$d"; d=$(dirname "$d"); done
  done | sort -ru | while read -r d; do rmdir "$base/$d" 2>/dev/null || true; done
  rm -f "$manifest"
  [ "$client" = generic ] && rmdir "$base" 2>/dev/null || true
  say "removed the files listed in $manifest"
  exit 0
fi

# ---- get the release -----------------------------------------------------------------------------
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ -n "$from" ]; then
  [ -d "$from/skills" ] || die "$from does not look like a harness checkout (no skills/)"
  src=$(CDPATH= cd -- "$from" && pwd)
  version="local"
  say "copying from $src (no download, so no checksum)"
else
  command -v curl >/dev/null 2>&1 || die "need curl"
  archive="$NAME-$version.tar.gz"
  url="https://github.com/$REPO/releases/download/$version/$archive"
  say "downloading $url"
  curl -fsSL -o "$work/$archive" "$url" || die "download failed: $url"
  if [ -z "$want_sum" ]; then
    curl -fsSL -o "$work/$archive.sha256" "$url.sha256" || die "download failed: $url.sha256"
    want_sum=$(awk '{print $1}' "$work/$archive.sha256")
  fi
  got_sum=$(sha256_of "$work/$archive")
  [ "$got_sum" = "$want_sum" ] || die "checksum mismatch for $archive: expected $want_sum, got $got_sum"
  say "checksum OK ($got_sum)"
  mkdir "$work/x"
  tar -xzf "$work/$archive" -C "$work/x"
  src="$work/x/$NAME-$version"
  [ -d "$src/skills" ] || die "the archive has no $NAME-$version/skills folder"
fi

# ---- plan: source file -> relative destination ------------------------------------------------------
plan="$work/plan"
: > "$plan"
add_tree() { # <source dir> <destination prefix>
  ( cd "$1" && find . -type f | sed 's|^\./||' ) | while read -r rel; do
    printf '%s\t%s\n' "$1/$rel" "$2/$rel" >> "$plan"
  done
}
if [ "$client" = claude-code ]; then
  add_tree "$src/skills" "skills"
  for p in "$src/prompts/"*.md; do
    printf '%s\t%s\n' "$p" "commands/ignitify-$(basename "$p")" >> "$plan"
  done
else
  add_tree "$src/skills" "skills"
  add_tree "$src/prompts" "prompts"
  add_tree "$src/templates" "templates"
  add_tree "$src/examples" "examples"
  printf '%s\t%s\n' "$src/clients/generic/AGENTS.md" "AGENTS.md" >> "$plan"
fi

# The sha256 the last install recorded for a relative path, or nothing.
installed_sum() { [ -f "$manifest" ] && awk -v r="$1" '$1 !~ /^#/ && $2 == r {print $1}' "$manifest"; }

# Refuse to replace a file that this script did not install, or that changed since, unless --force.
if [ "$force" -eq 0 ]; then
  while IFS="$(printf '\t')" read -r s rel; do
    [ -e "$base/$rel" ] || continue
    recorded=$(installed_sum "$rel" || true)
    [ -n "$recorded" ] || die "$base/$rel exists and was not installed by this script (use --force to replace it)"
    [ "$(sha256_of "$base/$rel")" = "$recorded" ] || die "$base/$rel changed after the last install (use --force to replace it)"
  done < "$plan"
fi

# Files of the last install that this release no longer has: remove them when unchanged.
if [ -f "$manifest" ]; then
  grep -v '^#' "$manifest" | while read -r sum rel; do
    awk -F '\t' -v r="$rel" '$2 == r {f = 1} END {exit !f}' "$plan" && continue
    f="$base/$rel"
    [ -f "$f" ] || continue
    if [ "$(sha256_of "$f")" = "$sum" ]; then rm -f "$f"; else echo "install.sh: kept $f (changed after install)" >&2; fi
  done
fi

# ---- copy and write the manifest -----------------------------------------------------------------
new_manifest="$work/manifest"
echo "# $NAME $version client=$client scope=$scope" > "$new_manifest"
while IFS="$(printf '\t')" read -r s rel; do
  mkdir -p "$(dirname "$base/$rel")"
  cp "$s" "$base/$rel"
  printf '%s  %s\n' "$(sha256_of "$base/$rel")" "$rel" >> "$new_manifest"
done < "$plan"
cp "$new_manifest" "$manifest"

count=$(grep -vc '^#' "$manifest")
say "installed $count files into $base ($version)"

if [ "$client" = claude-code ]; then
  cat <<EOF
Next steps:
  1. Restart Claude Code. The skills start with "ignitify-"; the commands are /ignitify-<name>.
  2. Optional, recommended: add the permission rules of clients/claude-code/settings.example.json
     (in the harness repository) to your .claude/settings.json. They allow read-only ignitify
     commands, ask before writes, and deny deletes, secrets, webhooks, access commands and sign-in.
  3. Give Claude Code its own read-only key (needs ignitify CLI 3.2.0 or newer; you run these, not Claude):
       ignitify group:create readers --permissions tasks.read,deployments.read,runs.read,secrets.read,hooks.read,usage.read
       ignitify user:create ai-assistant
       ignitify group:add-user readers ai-assistant
       ignitify key:create --user ai-assistant --label laptop --out ~/ignitify-ai-assistant.key
     Then start Claude Code with that key in its environment only:
       IGNITIFY_API_KEY="\$(cat ~/ignitify-ai-assistant.key)" claude
     The AI client must never run user:*, group:* or key:* commands, nor read the key file.
     Without it, the key on this machine is full access: review every write Claude proposes.
Remove: $remove_hint
EOF
else
  cat <<EOF
Next steps:
  1. Copy the block in $base/AGENTS.md into your project's AGENTS.md (or the instruction file of your AI client).
  2. Point your client at $base/skills/ (start with ignitify-getting-started/SKILL.md).
  3. Give your AI client its own read-only key (needs ignitify CLI 3.2.0 or newer; you run these, not the client):
       ignitify group:create readers --permissions tasks.read,deployments.read,runs.read,secrets.read,hooks.read,usage.read
       ignitify user:create ai-assistant
       ignitify group:add-user readers ai-assistant
       ignitify key:create --user ai-assistant --label laptop --out ~/ignitify-ai-assistant.key
     Then set IGNITIFY_API_KEY to that key in the client's environment only, when you start it.
     The AI client must never run user:*, group:* or key:* commands, nor read the key file.
     Without it, the key on this machine is full access: review every write your client proposes.
Remove: $remove_hint
EOF
fi
