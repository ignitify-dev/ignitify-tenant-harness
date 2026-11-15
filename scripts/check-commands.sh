#!/bin/sh
# Check that every `ignitify <command> [--flag ...]` in the harness exists in the CLI.
#
# The list of real commands and flags is cli/commands.txt. It is a snapshot of the help pages of
# one CLI version (its first line names the version).
#
#   scripts/check-commands.sh            check the docs against cli/commands.txt
#   scripts/check-commands.sh --refresh  rewrite cli/commands.txt from the `ignitify` on PATH, then check
#   scripts/check-commands.sh --live     check the docs against the `ignitify` on PATH (writes nothing)
#
# A line ending in "# planned" is skipped: it names a command that is not shipped yet.
# Exit 0: every command and flag is real. Exit 1: the script lists what is not.
# Needs: sh, awk, sed, grep, find. `--refresh` and `--live` also need `ignitify` (no key, no network).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SNAPSHOT="$ROOT/cli/commands.txt"

# Print the snapshot format from the installed CLI: a version line, a global line, then one line
# per command: "<command> --flag --flag ...".
snapshot_from_cli() {
  command -v ignitify >/dev/null 2>&1 || { echo "check-commands: 'ignitify' is not on PATH" >&2; exit 2; }
  version=$(NO_COLOR=1 ignitify --version 2>/dev/null | head -n 1 | awk '{print $2}')
  echo "# cli $version"
  echo "* --json --help --yes --version"
  NO_COLOR=1 ignitify help |
    awk '/^  [a-z][a-z-]*(:[a-z][a-z-]*)? {2,}/ && $1 != "ignitify" { print $1 }' |
    while read -r cmd; do
      flags=$(NO_COLOR=1 ignitify help "$cmd" |
        awk '/^Flags/ {f=1; next} /^[A-Z]/ {f=0} f && /^  --[a-z]/ {print $1}' | tr '\n' ' ')
      echo "$cmd $flags" | sed 's/ *$//'
    done
}

case "${1:-}" in
  --refresh) snapshot_from_cli > "$SNAPSHOT"; echo "wrote $SNAPSHOT" ;;
  --live) LIVE=$(mktemp); trap 'rm -f "$LIVE"' EXIT; snapshot_from_cli > "$LIVE"; SNAPSHOT=$LIVE ;;
  "") ;;
  *) echo "usage: $0 [--refresh|--live]" >&2; exit 2 ;;
esac

[ -f "$SNAPSHOT" ] || { echo "check-commands: no $SNAPSHOT; run with --refresh" >&2; exit 2; }

# Every text file a client reads. The CLI snapshot itself and this script are not docs.
FILES=$(find "$ROOT" -type f \( -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.json' -o -name '*.mdc' \) \
  -not -path '*/.git/*' -not -path "$ROOT/cli/*" -not -name LICENSE | sort)

# The skills name the CLI version they were checked against; it must be the snapshot's version.
snap_version=$(sed -n '1s/^# cli //p' "$SNAPSHOT")
# shellcheck disable=SC2086
stale=$(grep -HnoE 'ignitify CLI [0-9]+(\.[0-9]+)*' $FILES | grep -v "ignitify CLI $snap_version\$" || true)
[ -z "$stale" ] || { echo "$stale" | sed "s/\$/ (snapshot is $snap_version)/"; exit 1; }

# shellcheck disable=SC2086
awk -v snap="$SNAPSHOT" '
  BEGIN {
    while ((getline line < snap) > 0) {
      if (line ~ /^#/ || line == "") continue
      n = split(line, w, " ")
      known[w[1]] = 1
      for (i = 2; i <= n; i++) flag[w[1] " " w[i]] = 1
    }
    bad = 0
  }
  # A line that ends in "# planned" names a command the CLI does not ship yet.
  /# planned$/ { next }
  {
    rest = $0
    # A command is "ignitify " then a lower-case word, with an optional ":verb".
    while (match(rest, /(^|[^a-zA-Z0-9_.\/-])ignitify +(--version|--help|-v|-h|[a-z][a-z-]*(:[a-z][a-z-]*)?)/)) {
      hit = substr(rest, RSTART, RLENGTH)
      sub(/^[^i]*ignitify +/, "", hit)
      after = substr(rest, RSTART + RLENGTH)
      rest = after
      if (hit == "--version" || hit == "--help" || hit == "-v" || hit == "-h") continue
      if (!(hit in known)) { printf "%s:%d: unknown command: ignitify %s\n", FILENAME, FNR, hit; bad = 1; continue }
      # The flags that belong to this command: up to a shell separator, a closing backtick or the next command.
      seg = after
      cut = match(seg, /[`|;&)]|ignitify /)
      if (cut) seg = substr(seg, 1, RSTART - 1)
      while (match(seg, /(^|[ [(])--[a-z][a-z-]*/)) {
        f = substr(seg, RSTART, RLENGTH); sub(/^[ [(]/, "", f)
        seg = substr(seg, RSTART + RLENGTH)
        if (!((hit " " f) in flag) && !(("* " f) in flag)) { printf "%s:%d: unknown flag for %s: %s\n", FILENAME, FNR, hit, f; bad = 1 }
      }
    }
  }
  END { exit bad }
' $FILES && echo "check-commands: OK ($(echo "$FILES" | wc -l | tr -d ' ') files, $(sed -n 1p "$SNAPSHOT"))"
