---
name: ignitify-runs
description: Start and control Ignitify runs - task:run with --payload, --wait, --timeout-sec, --on-busy, --deployment, --at and --idempotency-key; run statuses; safe retries with no duplicate run; scheduled runs, one-time (--at) and recurring (schedule:create with a cron expression, schedule:update, schedule:show, schedule:pause, schedule:resume, schedule:list, schedule:cancel); webhooks that start runs (hook:create, signing); end-of-run callbacks (notify:set); and run:cancel. Use it when the user wants to run a task, pass input, run later, trigger from another system, or stop a run.
license: Apache-2.0
---

# Run a task

Read `ignitify-getting-started` first. A run is a write that uses the plan's limits and costs compute: ask the user before `task:run`.

## Start a run

```sh
ignitify task:run <slug> --wait
ignitify task:run <slug> --payload '{"name":"Ada"}' --wait
```

| Flag | Meaning |
| :-- | :-- |
| `--payload <json>` | Input for this run only. Must be valid JSON and fit the payload limit. Default: `run.payload` from `task.yaml`. |
| `--timeout-sec <n>` | Time limit for this run only. Default: `run.timeout_sec`. |
| `--wait` | Follow the run to its end and print the result. Exit code 0 only when the run is `COMPLETED`. |
| `--on-busy queue\|reject` | When the run cannot start at once: `queue` (default) waits for room for a limited time, `reject` fails at once. |
| `--deployment <id>` | Run this deployment, not the newest one. |
| `--at <iso>` | Run later (below). |
| `--idempotency-key <key>` | Start at most one run for this key. A retry with the same key gets the first answer (below). |
| `--dir <base-dir>` | Folder that holds the task folders. |

Without `--deployment` and without local state, `task:run` runs the task's newest deploy request (by `admitted_at`). A redeploy of earlier code brings back its old deployment, and that deployment then counts as the newest.

Without `--wait`, `task:run` returns at once with the run id and status `PENDING`. Follow it with `ignitify run:get <run-id>` or `ignitify run:timeline <run-id> --follow`. Ctrl+C stops the wait, not the run. `task.yaml` is never written by these flags.

The task must be deployed (`READY`). See `ignitify-deploy`.

## Run status

| Status | Final | Meaning |
| :-- | :-- | :-- |
| `PENDING` | no | Waits for a place to start. |
| `PROVISIONING` | no | A VM boots. |
| `RUNNING` | no | The code runs. |
| `RETRYING` | no | A short-lived platform failure; it goes back to `PENDING`. It still counts against limits. |
| `COMPLETED` | yes | The task returned a result. |
| `FAILED` | yes | The task failed, or the platform gave up after the last try. |
| `CANCELLED` | yes | Someone stopped it, or its deployment or task was deleted. |

The platform retries only platform failures. A failure of your code is not retried.

## Do not start a run twice

A `task:run` that fails with a network error or a timeout of the CLI call may still have started the run. Retry only with an idempotency key:

```sh
ignitify task:run <slug> --deployment <deployment-id> --idempotency-key <key> --wait
```

- Pass `--idempotency-key` on the **first** try, not only on the retry, and keep every other flag the same. A retry with the same key gets the first answer and starts no second run; the CLI says on stderr: `this is the answer to an earlier request with the same --idempotency-key; no new run was started.`
- Pin `--deployment <id>` (from `ignitify task:deploy` or `ignitify deployment:list`). Without it the run takes the task's newest deploy, and a new deploy between two tries changes the request.
- The key: 8 to 255 characters of `A-Z a-z 0-9 . _ : -`, for example `<slug>-2027-01-15-1` or a UUID. Use a new key for each new run. The same key with a different run (another payload, deployment or run setting) is refused: "Use a new --idempotency-key for a different run."
- A refusal that says an earlier request with this key may still be running: retry with the same key shortly.
- The user agreed to one run. A retry with the same key and the same flags is that same run, not a new one.
- **Never retry a `task:run` that was sent without a key.** First check whether the run exists: `ignitify run:list --task-name <slug> --limit 5`. Ask the user before a new run.

A webhook call can carry an `x-ignitify-delivery` header: a repeated value returns the same run.

## Run later

```sh
ignitify task:run <slug> --at 2027-01-15T03:00:00Z
ignitify schedule:list
ignitify schedule:cancel <sch-id>
```

- The time must be in the future (ISO 8601; `Z` means UTC). No run exists until it fires.
- `--at` and `--wait` cannot go together.
- After it fires, the schedule leaves `schedule:list` and the run shows in `run:list`.
- `schedule:cancel` asks first. Ask the user before you cancel.

## Run on a repeating schedule

```sh
ignitify schedule:preview "0 3 * * *" --tz Europe/Berlin
ignitify schedule:create <slug> --cron "0 3 * * *" --tz Europe/Berlin --payload '{"day":"yesterday"}'
ignitify schedule:show <sch-id>
ignitify schedule:update <sch-id> --cron "30 3 * * *"
ignitify run:list --schedule <sch-id>
ignitify schedule:pause <sch-id>
ignitify schedule:resume <sch-id>
```

- A recurring schedule starts a paid run at every slot, with no further human act. Ask the user before `schedule:create`, `schedule:update`, `schedule:pause` and `schedule:resume`, and show them the next fire times first (`schedule:preview`).
- The expression has 5 fields (minute hour day-of-month month day-of-week), read in the IANA zone of `--tz` (default UTC). Each slot runs the task's newest READY deployment, so a code update needs no new schedule.
- `--overlap skip` (the default) leaves a slot out while the schedule's last run is still active; `--overlap allow` starts it too.
- `schedule:update` changes a schedule in place: only the flags you give change, and it keeps its id, its runs and its status (a paused schedule stays paused). A new `--cron` or `--tz` counts the next slot from now. `--payload` replaces the whole payload. Do not cancel and create a schedule to change it.
- A resumed schedule fires from its next slot. It does not catch up the slots it missed.
- The platform pauses a schedule after too many missed slots in a row, or when the plan no longer allows what it runs. `schedule:show` says why in plain words. Fix the cause, then ask the user before `schedule:resume`. If the plan does not include recurring schedules, the resume is refused: the user changes plan first.
- The plan limits how many recurring schedules a tenant holds (`whoami`, `max_schedules`). One more is refused with `schedule-quota`.
- Never put a secret in a payload. The task reads secrets through `ctx.secrets`.

## Start runs from another system (webhooks)

The user creates the webhook. Do not run `hook:create` yourself: its reply shows a signing secret once, and that secret must not go into your context.

```sh
ignitify hook:create <slug>   # the user runs this
ignitify hook:list <slug>     # safe to run; also says which deployment the hook runs now
```

The sender signs the exact body: `x-ignitify-signature: sha256=<hex HMAC-SHA256 of the body, key = the secret>`, with `content-type: application/json`. The body becomes the run payload.

| Answer | Meaning |
| :-- | :-- |
| 202 | A run started. The body has `run_id`. |
| 401 | Bad signature (check the exact bytes and the content type). |
| 404 | Unknown hook (deleted, or a typo in the URL). |
| 413 | Body over the payload limit. |
| 429 | Rate limit or the plan's run limit. No run started. |

- A webhook belongs to the task. Each run it starts uses the task's newest `READY` deployment, so a new deploy keeps the URL and the secret. With no `READY` deployment, a delivery is refused with 409.
- Webhooks need a plan that allows them (`ignitify whoami`, the `may_…` lines). Otherwise `hook:create` gets `API 403`.
- A webhook run always uses the preset's default disk.

## Get a call when a run ends (notify)

The user sets it, because it needs a signing secret on stdin (32 characters or more):

```sh
printf %s "$NOTIFY_SECRET" | ignitify notify:set <deployment-id> --url https://example.com/hook --secret-stdin
ignitify notify:set <deployment-id> --clear
```

The callback is a POST with the same `x-ignitify-signature` header. Its body is `{"run_id", "status", "deployment_id", "tenant_id"}`, with no result. The receiver reads the result with `ignitify run:get <run_id>`.

## Stop a run

```sh
ignitify run:cancel <run-id>              # graceful: the task is asked to stop, then killed
ignitify run:cancel <run-id> --grace 30000
ignitify run:cancel <run-id> --force      # kill now; also needed for a run on a pinned VM
```

Ask the user first. `run:delete` deletes the record only and does not stop a live run.

## Common mistakes

- A payload with shell quoting errors. Put JSON in single quotes.
- A big payload. Pass a link; the limit is small (see `ignitify-limits-and-cost`).
- Treating a run with no `--wait` as finished. It is `PENDING`.
- `--on-busy queue` does not wait for the plan's run limits. Those give `API 429` at once.
- A second `task:run` after a timeout of the CLI call with no `--idempotency-key`. Use a key from the first try; without one, check `run:list` first.

Docs: https://ignitify.dev/docs/guides/pass-input-and-read-results
