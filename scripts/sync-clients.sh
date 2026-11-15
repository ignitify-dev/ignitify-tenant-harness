#!/bin/sh
# Copy the shared skills and prompts into the client packs. A Claude Code plugin cannot read files
# outside its own folder, so it holds copies. skills/ and prompts/ are the only sources: edit there.
#
#   scripts/sync-clients.sh          rewrite the copies
#   scripts/sync-clients.sh --check  exit 1 when a copy differs from its source (writes nothing)
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN="$ROOT/clients/claude-code"

build() {
  out=$1
  mkdir -p "$out/skills" "$out/commands"
  cp -R "$ROOT/skills/." "$out/skills/"
  cp "$ROOT/prompts/"*.md "$out/commands/"
}

case "${1:-}" in
  "")
    rm -rf "$PLUGIN/skills" "$PLUGIN/commands"
    build "$PLUGIN"
    echo "sync-clients: wrote $PLUGIN/skills and $PLUGIN/commands"
    ;;
  --check)
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    build "$tmp"
    if diff -r "$tmp/skills" "$PLUGIN/skills" >/dev/null 2>&1 && diff -r "$tmp/commands" "$PLUGIN/commands" >/dev/null 2>&1; then
      echo "sync-clients: OK"
    else
      echo "sync-clients: the plugin copies differ from skills/ or prompts/; run scripts/sync-clients.sh" >&2
      exit 1
    fi
    ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac
