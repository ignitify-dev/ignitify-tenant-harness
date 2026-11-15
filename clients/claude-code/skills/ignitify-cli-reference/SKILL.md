---
name: ignitify-cli-reference
description: The full list of `ignitify` CLI commands and flags, the global flags, environment variables, exit codes, --json rules, confirmation rules, and which commands are safe for an AI client to run (read), need the user's consent (write), or are for the user only. Use it to look up a command or a flag, or to decide if you may run a command.
license: Apache-2.0
---

# CLI reference

Checked against ignitify CLI 1.2.2. When the installed CLI differs, `ignitify help <command>` wins. Rows marked *(after 1.2.2)* need the next CLI release. `run:timeline`, `run:failures`, `usage:series`, `notification:list` and the `run:logs` flags `--follow` and `--tail` come with the CLI release after 1.2.2. If `ignitify help` does not list them, use `ignitify run:get <run-id> --json` (status, `result.error`) in place of the timeline and the failure classes, and `ignitify run:logs <run-id> | tail -n 200` in place of `--tail 200`.

## Rules for every command

- Form: `ignitify <resource>:<verb> [arguments] [flags]`. A flag or argument that a command does not take is refused.
- Global flags: `--json` (one JSON document on stdout), `-h` / `--help`, `-y` / `--yes` (answer a delete's question), `-v` / `--version` (first word only).
- Environment: `IGNITIFY_API_KEY` (a key; wins over the saved login), `IGNITIFY_TASKS_DIR` (folder of task folders; default `tasks`), `NO_COLOR`.
- Exit codes: 0 success; 1 error or refusal; 130 Ctrl+C during a wait. `task:run --wait` and an ended `run:timeline` exit 0 only for `COMPLETED`.
- Errors are text on stderr (also with `--json`), with `server trace id: …` after a failed request.
- The CLI talks to one fixed Ignitify address. No flag or environment variable changes it.
- Every delete and cancel asks first. Without a terminal it is refused unless `--yes` is given. `--force` unlocks a refusal; it never skips the question.
- No server, no key: `task:create --local`, `task:validate` (without `--review-packages`), `task:pack`, `task:deploy --check`, `help`.

## Who may run it

- **read**: safe for an AI client.
- **ask**: a write. Ask the user first, show the exact command.
- **user**: give the command to the user. Never run it yourself.

## Commands

| Command | Synopsis | Who |
| :-- | :-- | :-- |
| `help` | `ignitify help [<command>]` | read |
| `--version` | `ignitify --version` | read |
| `login` | `ignitify login [--name <label>] [--no-browser]` | user |
| `logout` | `ignitify logout` | user |
| `whoami` | `ignitify whoami` | read |
| `quota` | `ignitify quota` | read |
| `usage` | `ignitify usage [--period YYYY-MM] [--axis <axis>] [--vm <vm-id>] [--run <run-id>] [--runs\|--vms] [--json]` | read |
| `usage:export` | `ignitify usage:export [--period YYYY-MM] [--axis <axis>] [--vm <vm-id>] [--run <run-id>] (--json\|--csv)` | read |
| `usage:series` *(after 1.2.2)* | `ignitify usage:series [--days N] [--json]` | read |
| `notification:list` *(after 1.2.2)* | `ignitify notification:list [--unread \| --open] [--kind <kind>] [--limit N] [--json]` | read |
| `task:create` | `ignitify task:create <task-id> [--lang node\|python\|go\|rust] [--local] [--no-init] [--no-scaffold] [--dir <base-dir>]` | ask (with `--local`: read) |
| `task:list` | `ignitify task:list [--limit N] [--after-id <id>] [--after <iso>]` | read |
| `task:get` | `ignitify task:get <task-id> [--dir <base-dir>]` | read |
| `task:validate` | `ignitify task:validate <task-id> [--dir <base-dir>] [--review-packages]` | read |
| `task:pack` | `ignitify task:pack <task-id> [--dir <base-dir>]` | read |
| `task:deploy` | `ignitify task:deploy <task-id> [--dir <base-dir>] [--check]` | ask (with `--check`: read) |
| `task:run` | `ignitify task:run <task-id> [--dir <base-dir>] [--deployment <id>] [--payload <json>] [--timeout-sec <n>] [--on-busy queue\|reject] [--at <iso>] [--wait]` | ask |
| `task:delete` | `ignitify task:delete <task-id> [--dir <base-dir>] [--yes] [--json]` | user |
| `deployment:list` | `ignitify deployment:list [--limit N] [--after-id <id>] [--after <iso>]` | read |
| `deployment:get` | `ignitify deployment:get <deployment-id>` | read |
| `deployment:logs` | `ignitify deployment:logs <deployment-id> [--raw]` | read |
| `deployment:delete` | `ignitify deployment:delete <deployment-id> [--yes]` | user |
| `run:list` | `ignitify run:list [--status S] [--deployment-id D] [--task-name N] [--preset P] [--correlation-id C] [--vm-id V] [--limit N] [--after-id <id>] [--after <iso>]` | read |
| `run:get` | `ignitify run:get <run-id> [--full]` | read |
| `run:logs` | `ignitify run:logs <run-id> [--follow] [--tail N] [--raw]` (`--follow`, `--tail` after 1.2.2) | read |
| `run:timeline` *(after 1.2.2)* | `ignitify run:timeline <run-id> [--follow]` | read |
| `run:failures` *(after 1.2.2)* | `ignitify run:failures [--days N] [--json]` | read |
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
| `schedule:cancel` | `ignitify schedule:cancel <sch-id> [--yes]` | ask |
| `hook:list` | `ignitify hook:list <deployment-id> [--limit N] [--after-id <id>] [--after <iso>]` | read |
| `hook:create` | `ignitify hook:create <deployment-id> --task-name <name>` | user (prints a secret once) |
| `hook:delete` | `ignitify hook:delete <hook-resource-id> [--yes]` | user |
| `notify:set` | `ignitify notify:set <deployment-id> --url <https://…> --secret-stdin` or `ignitify notify:set <deployment-id> --clear` | user |

`<axis>` is one of `compute`, `network`, `network_in`, `disk`, `scratch`, `runs`, `pin`, `build`.

`task:validate --review-packages` sends the `build.system_packages` names and the runtime id to a platform-side AI review for advice. Nothing else leaves the machine, and the exit code does not change.

Full reference: https://ignitify.dev/docs/cli/all
