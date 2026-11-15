---
description: Collect the facts for an Ignitify support request, with no secrets.
argument-hint: <run-id or deployment-id>
allowed-tools:
  - Bash(ignitify --version)
  - Bash(ignitify run:get *)
  - Bash(ignitify run:timeline *)
  - Bash(ignitify deployment:get *)
  - Bash(ignitify task:get *)
---
Prepare a support report for `$ARGUMENTS`. Use the `ignitify-troubleshooting` skill and its template `support-report.md` (in the skill folder).

Run these first. All are read-only:

1. `ignitify --version`
2. For a run id: `ignitify run:get $ARGUMENTS --json` and `ignitify run:timeline $ARGUMENTS`
3. For a deployment id: `ignitify deployment:get $ARGUMENTS`

Fill every field of the template. Copy the `server trace id` lines exactly. Ask the user what they expected and what they tried.

Before you show the report, remove every API key, token, password, secret value and personal data. Never include `~/.config/ignitify/credentials.json` or any `.env` file. Show the report to the user; do not send it anywhere.
