---
name: ignitify-cli-reference
description: The full list of `ignitify` CLI commands and flags (tasks, runs, access control), the global flags, environment variables, exit codes, --json rules, confirmation rules, and which commands are safe for an AI client to run (read), need the user's consent (write), or are for the user only. Use it to look up a command or a flag, or to decide if you may run a command.
license: Apache-2.0
---

# CLI reference

Checked against ignitify CLI 3.8.0; the harness needs 3.8.0 or newer. When the installed CLI differs, `ignitify help <command>` wins.

## Rules for every command

- Form: `ignitify <resource>:<verb> [arguments] [flags]`. A flag or argument that a command does not take is refused.
- Global flags: `--json` (one JSON document on stdout), `-h` / `--help`, `-y` / `--yes` (answer a delete's question), `-v` / `--version` (first word only).
- Environment: `IGNITIFY_API_KEY` (a key; wins over the saved login), `IGNITIFY_TASKS_DIR` (folder of task folders; default `tasks`), `NO_COLOR`.
- Exit codes: 0 success; 1 error or refusal; 130 Ctrl+C during a wait. `task:run --wait` and an ended `run:timeline` exit 0 only for `COMPLETED`.
- Errors are text on stderr (also with `--json`), with `server trace id: …` after a failed request. A failed request prints the server's sentence and its stable code: `Error: secret not found [secret-not-found]`. Decide on the code in brackets, not on the sentence. With `--json` the raw error body may print instead.
- The CLI talks to one fixed Ignitify address. No flag or environment variable changes it.
- Every delete and cancel asks first. Without a terminal it is refused unless `--yes` is given. `--force` unlocks a refusal; it never skips the question.
- No server, no key: `task:create --local`, `task:validate` (without `--review-packages`), `task:pack`, `task:deploy --check`, `permission:list`, `help`.
- A user key runs only what its groups' permissions allow (`ignitify whoami`, the "This Key" block). Other commands get `permission denied: this key needs the <permission> permission`; `user:*`, `group:*` and `key:*` with a user key get `owner key required`.

## Who may run it

- **read**: safe for an AI client.
- **ask**: a write. Ask the user first, show the exact command.
- **user**: give the command to the user. Never run it yourself.
- **owner**: an access command. It needs an owner key. Never run it yourself, not even a `:list` or `:get`; give the command to the tenant owner.

## Commands

| Command | Synopsis | Who |
| :-- | :-- | :-- |
| `help` | `ignitify help [<command>]` | read |
| `--version` | `ignitify --version` | read |
| `login` | `ignitify login [--name <label>] [--no-browser]` | user |
| `logout` | `ignitify logout` | user |
| `whoami` | `ignitify whoami` | read |
| `permission:list` | `ignitify permission:list [--json]` | read |
| `quota` | `ignitify quota` | read |
| `usage` | `ignitify usage [--period YYYY-MM] [--axis <axis>] [--vm <vm-id>] [--run <run-id>] [--runs\|--vms] [--json]` | read |
| `usage:export` | `ignitify usage:export [--period YYYY-MM] [--axis <axis>] [--vm <vm-id>] [--run <run-id>] (--json\|--csv)` | read |
| `usage:series` | `ignitify usage:series [--days N] [--json]` | read |
| `notification:list` | `ignitify notification:list [--unread \| --open] [--kind <kind>] [--limit N] [--json]` | read |
| `task:create` | `ignitify task:create <task-id> [--lang node\|python\|go\|rust] [--local] [--no-init] [--no-scaffold] [--dir <base-dir>]` | ask (with `--local`: read) |
| `task:list` | `ignitify task:list [--limit N] [--after-id <id>] [--after <iso>]` | read |
| `task:get` | `ignitify task:get <task-id> [--dir <base-dir>]` | read |
| `task:validate` | `ignitify task:validate <task-id> [--dir <base-dir>] [--review-packages]` | read |
| `task:pack` | `ignitify task:pack <task-id> [--dir <base-dir>]` | read |
| `task:deploy` | `ignitify task:deploy <task-id> [--dir <base-dir>] [--check]` | ask (with `--check`: read) |
| `task:run` | `ignitify task:run <task-id> [--dir <base-dir>] [--deployment <id>] [--payload <json>] [--timeout-sec <n>] [--on-busy queue\|reject] [--at <iso>] [--idempotency-key <key>] [--wait]` | ask |
| `task:delete` | `ignitify task:delete <task-id> [--dir <base-dir>] [--yes] [--json]` | user |
| `deployment:list` | `ignitify deployment:list [--limit N] [--after-id <id>] [--after <iso>]` | read |
| `deployment:get` | `ignitify deployment:get <deployment-id>` | read |
| `deployment:logs` | `ignitify deployment:logs <deployment-id> [--raw]` | read |
| `deployment:delete` | `ignitify deployment:delete <deployment-id> [--yes]` | user |
| `run:list` | `ignitify run:list [--status S] [--deployment-id D] [--task-name N] [--preset P] [--schedule <sch-id>] [--correlation-id C] [--vm-id V] [--limit N] [--after-id <id>] [--after <iso>]` | read |
| `run:get` | `ignitify run:get <run-id> [--full]` | read |
| `run:logs` | `ignitify run:logs <run-id> [--follow] [--tail N] [--raw]` | read |
| `run:timeline` | `ignitify run:timeline <run-id> [--follow]` | read |
| `run:failures` | `ignitify run:failures [--days N] [--json]` | read |
| `run:cancel` | `ignitify run:cancel <run-id> [--yes] [--force] [--grace <ms>]` | ask |
| `run:delete` | `ignitify run:delete <run-id> [--yes]` | user |
| `vm:list` | `ignitify vm:list [--pinned] [--deployment-id D] [--task-name N] [--preset P] [--older-than 24h] [--limit N] [--after-id <vm-id>] [--after <iso>]` | read |
| `vm:get` | `ignitify vm:get <vm-id>` | read |
| `vm:delete` | `ignitify vm:delete <vm-id> [--yes] [--force]` | user |
| `secret:list` | `ignitify secret:list` | read |
| `secret:set` | `ignitify secret:set <NAME> --stdin` | user |
| `secret:delete` | `ignitify secret:delete <NAME> [--yes]` | user |
| `integration:add` | `ignitify integration:add <name> --task <slug> [--yes \| --dry-run] [--dir <base-dir>]` | ask (with `--dry-run`: read) |
| `schedule:list` | `ignitify schedule:list` | read |
| `schedule:show` | `ignitify schedule:show <sch-id>` | read |
| `schedule:preview` | `ignitify schedule:preview <cron> [--tz <zone>]` | read |
| `schedule:create` | `ignitify schedule:create <task> --cron <expression> [--tz <zone>] [--payload <json>] [--preset <preset>] [--timeout-sec <n>] [--deadline-sec <n>] [--overlap skip\|allow]` | ask (starts a paid run at every slot) |
| `schedule:update` | `ignitify schedule:update <sch-id> [--cron <expression>] [--tz <zone>] [--payload <json>] [--preset <preset>] [--timeout-sec <n>] [--deadline-sec <n>] [--overlap skip\|allow]` | ask (changes when and how paid runs start) |
| `schedule:pause` | `ignitify schedule:pause <sch-id>` | ask |
| `schedule:resume` | `ignitify schedule:resume <sch-id>` | ask |
| `schedule:cancel` | `ignitify schedule:cancel <sch-id> [--yes]` | ask |
| `hook:list` | `ignitify hook:list <task> [--limit N] [--after-id <id>] [--after <iso>]` | read |
| `hook:create` | `ignitify hook:create <task>` | user (prints a secret once) |
| `hook:delete` | `ignitify hook:delete <hook-resource-id> [--yes]` | user |
| `notify:set` | `ignitify notify:set <deployment-id> --url <https://…> --secret-stdin` or `ignitify notify:set <deployment-id> --clear` | user |
| `user:create` | `ignitify user:create <name> [--json]` | owner |
| `user:list` | `ignitify user:list [--json]` | owner |
| `user:get` | `ignitify user:get <name> [--json]` | owner |
| `user:remove` | `ignitify user:remove <name> [--yes]` | owner |
| `group:create` | `ignitify group:create <name> --permissions <p1,p2,…> [--json]` | owner |
| `group:list` | `ignitify group:list [--json]` | owner |
| `group:get` | `ignitify group:get <name> [--json]` | owner |
| `group:grant` | `ignitify group:grant <name> <permission>` | owner |
| `group:revoke` | `ignitify group:revoke <name> <permission>` | owner |
| `group:add-user` | `ignitify group:add-user <group> <user>` | owner |
| `group:remove-user` | `ignitify group:remove-user <group> <user>` | owner |
| `group:delete` | `ignitify group:delete <name> [--yes]` | owner |
| `key:create` | `ignitify key:create --user <name> --label <text> [--out <file>] [--json]` | owner (prints a key once) |
| `key:list` | `ignitify key:list [--user <name>] [--json]` | owner |
| `key:revoke` | `ignitify key:revoke <key-resource-id> [--yes]` | owner |

`<axis>` is one of `compute`, `network`, `network_in`, `disk`, `scratch`, `runs`, `pin`, `build`.

Permissions (`ignitify permission:list`): `tasks.read`, `tasks.write`, `deployments.read`, `deployments.write`, `runs.read`, `runs.write`, `secrets.read`, `secrets.write`, `hooks.read`, `hooks.write`, `schedules.read`, `schedules.write`, `usage.read`. User and group names: 1 to 63 lower case letters, digits and `-`, starting with a letter or digit.

`task:run --idempotency-key <key>`: 8 to 255 characters of `A-Z a-z 0-9 . _ : -`. A retry with the same key gets the first answer and starts no second run. See `ignitify-runs`.

`task:validate --review-packages` sends the `build.system_packages` names and the runtime id to a platform-side AI review for advice. Nothing else leaves the machine, and the exit code does not change.

`<task>` is the task slug or id. A webhook belongs to the task, not to one deployment: each run it starts uses the task's newest `READY` deployment, so a code update keeps the URL and the secret. `hook:list` also prints a line on stderr that names that deployment (or says none is `READY`). `deployment:get` and `deployment:list` show `admitted_at`, when the latest build of the deployment was requested.

Full reference: https://ignitify.dev/docs/cli/all
