---
name: ignitify-runs
description: Start and control Ignitify runs - task:run with --payload, --wait, --timeout-sec, --on-busy, --deployment, --at and --idempotency-key; run statuses; safe retries with no duplicate run; scheduled runs, one-time (--at) and recurring (schedule:create with a cron expression, schedule:update, schedule:show, schedule:pause, schedule:resume, schedule:list, schedule:cancel); webhooks that start runs (hook:create, signing); end-of-run callbacks (notify:set); run:cancel; and flows built from runs (chain runs, fan-out, fan-in, branch, loop, one at a time). Use it when the user wants to run a task, pass input, run later, trigger from another system, chain steps into a flow, or stop a run.
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
| `--timeout-sec <n>` | Time limit for this run only. Default: the deployment's `run.timeout_sec`. |
| `--wait` | Follow the run to its end and print the result. Exit code 0 only when the run is `COMPLETED`. |
| `--on-busy queue\|reject` | When the run cannot start at once: `queue` waits for room for a limited time, `reject` fails at once. Default: the deployed `execution.on_busy`, else `queue`. A bidirectional task runs one VM at a time: queued runs run in turn, but behind a busy pinned VM a run is accepted, then fails (`bidirectional-busy`), also with `queue`. The flag sets only `on_busy`; every other setting stays the deployed one (CLI 3.8.0 or later). |
| `--deployment <id>` | Run this deployment, not the newest one. |
| `--at <iso>` | Run later (below). |
| `--idempotency-key <key>` | Start at most one run for this key. A retry with the same key gets the first answer (below). |
| `--dir <base-dir>` | Folder that holds the task folders. |

Without `--deployment` and without local state, `task:run` runs the task's newest deploy request (by `admitted_at`). A redeploy of earlier code brings back its old deployment, and that deployment then counts as the newest.

Without `--wait`, `task:run` returns at once with the run id and status `PENDING`. Follow it with `ignitify run:get <run-id>` or `ignitify run:timeline <run-id> --follow`. Ctrl+C stops the wait, not the run. `task.yaml` is never written by these flags.

The run uses the preset, the time limit and `execution` that the deployment stored from its `task.yaml`. A local edit of `run.preset`, `run.timeout_sec` or `execution` takes effect only after `ignitify task:deploy`. `--deployment <id>` runs an older deployment with that deployment's settings. The local `run.payload` is still the default payload.

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
- A user key needs `schedules.write` for `--at` and for every schedule write (`schedules.read` to list or show), besides `runs.write` for `--at`; without it the command gets `permission denied`.
- After it fires, the schedule leaves `schedule:list` and the run shows in `run:list`.
- `schedule:cancel` asks first. Ask the user before you cancel.
- In the task, a run started with `--at` has `ctx.run.schedule_id` and `ctx.run.scheduled_for` both empty, although `schedule:list` showed a `sch_…` id for it. Its key is `ctx.run.id`.

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
- The task reads its slot in `ctx.run`: `schedule_id` (the `sch_…` id) and `scheduled_for` (the slot time, UTC). When the task writes to another system, key the write on `(schedule_id, scheduled_for)` or on `ctx.run.id`, so one slot writes once (see `ignitify-task-authoring`, the `ctx` table).
- A slot that only waited for a run seat the platform held (for example during a host outage) does not count toward the pause.
- When the platform is late past a slot's start deadline, the slot is skipped: a `schedule.missed` notification with the reason `deadline-passed`. It does not run by itself.

**Resume after a platform incident.** Resume only the schedules the incident paused. The user puts the start of the incident (UTC) in the filter, so a schedule paused before it for another cause stays paused. Ask the user first:

```sh
ignitify schedule:list --json | jq -r '.[]
  | select(.kind=="cron" and .status=="auto_paused" and .pause_reason=="consecutive-misses"
           and .updated_at >= "2027-01-15T01:00:00Z")
  | .schedule_id' | xargs -n1 ignitify schedule:resume
```

**Run a past slot by hand** (to test a schedule, or to run a missed day again). The task reads the slot as `payload.slot ?? ctx.run.scheduled_for`, because a run you start has no schedule. Get the payload of an earlier run (`ignitify run:list --schedule <sch-id> --limit 1`, then `ignitify run:get <run-id> --full`). `ignitify hook:list <slug>` names the deployment the schedule runs. Then, from the task folder, with the user's consent:

```sh
ignitify task:run <slug> --deployment <deployment-id> \
  --payload '{"slot":"2027-01-15T02:00:00.000Z"}' \
  --idempotency-key <sch-id>-2027-01-15T02-00Z --wait
```

The run uses the preset, the time limit and `execution` that the deployment stored from its `task.yaml`, as a slot does. A slot also uses the run settings of the schedule (`run_settings` in `ignitify schedule:show <sch-id> --json`). If the schedule sets a time limit, pass the same `--timeout-sec`.

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
- A webhook run uses the preset, the time limit and `execution` (with `storage_mib`) that the deployment stored from its `task.yaml`. If a stored time limit or disk is now above the plan's limit, a delivery is refused with 409 `deployment-not-bootable`; a capability the plan no longer has gives 403. Fix `task.yaml` and deploy again.

## Get a call when a run ends (notify)

The user sets it, because it needs a signing secret on stdin (32 characters or more):

```sh
printf %s "$NOTIFY_SECRET" | ignitify notify:set <deployment-id> --url https://example.com/hook --secret-stdin
ignitify notify:set <deployment-id> --clear
```

The callback is a POST with the same `x-ignitify-signature` header. Its body is `{"run_id", "status", "deployment_id", "tenant_id"}`, with no result. The receiver reads the result with `ignitify run:get <run_id>`.

- **A callback belongs to one deployment.** A `task:deploy` that makes a new deployment starts with no callback, for scheduled and webhook runs alike. The user runs `notify:set` on the new deployment again, with the same URL and secret. `task:deploy` warns on stderr when the deployment before had a callback. Check with `ignitify deployment:get <deployment-id> --json` (`notify_url`). Terraform sets it on each new deployment.

## Stop a run

```sh
ignitify run:cancel <run-id>              # graceful: the task is asked to stop, then killed
ignitify run:cancel <run-id> --grace 30000
ignitify run:cancel <run-id> --force      # kill now; also needed for a run on a pinned VM
```

Ask the user first. `run:delete` deletes the record only and does not stop a live run.

## Build flows (chain runs, flow shapes)

A run does one step. Something outside the VM starts the next step. **Never write a task that starts runs, and never put an API key in a task**, also not to read another run.

Chain runs (https://ignitify.dev/docs/flows/chain-runs):

- **The next step in the result.** The task returns `next` (task and payload) or `done`; the caller reads the result and starts that step.
- **Your own orchestrator.** The user's workflow tool, cron job or queue keeps the flow state, starts each step (`task:run`), waits (`--wait`, `run:get`, or a callback to its own receiver) and starts the next.
- **Run B when A ends.** A's callback (`notify:set`) points at B's webhook URL, signed with B's webhook secret; the user sets both. B gets A's `run_id` and `status`, never A's result, on every final status: B stops unless `status` is `COMPLETED`. Set it again after each deploy of A. A dropped callback starts no B (`callback.failing`). No circles.

Flow shapes (https://ignitify.dev/docs/flows/flow-shapes):

- **Fan-out.** The orchestrator or a script starts one run per part, a key per part. Above the plan's run limit a start gets `API 429`: start a few at a time.
- **Fan-in.** The orchestrator keeps the run ids, waits until each is final (`run:get`), then combines the results. Large parts go to the user's own database.
- **Branch and loop.** The task returns the branch or "again"; the caller starts it, counts, and stops at a maximum.
- **One at a time.** The orchestrator starts the next run after the last one ended; or a schedule with `--overlap skip`; or a bidirectional task with `on_busy: queue` (runs in turn on one VM and, with `state: across-runs`, share its memory; behind a busy pinned VM a run fails with `bidirectional-busy`).

Practices for every flow:

- A flow id in every payload and result. The platform has no flow view.
- `--idempotency-key <flow-id>:<step>` on every start. A new try after a `FAILED` run is a new run with a new key.
- The platform retries only its own failures: the orchestrator retries a failed step a few times, then stops the flow. Make each step safe to run twice.
- `--deployment <id>` on every step keeps one code version for the whole flow.
- On stop, `run:cancel` the runs the flow started.

## Common mistakes

- A payload with shell quoting errors. Put JSON in single quotes.
- A big payload. Pass a link; the limit is small (see `ignitify-limits-and-cost`).
- Treating a run with no `--wait` as finished. It is `PENDING`.
- `--on-busy queue` does not wait for the plan's run limits. Those give `API 429` at once.
- A second `task:run` after a timeout of the CLI call with no `--idempotency-key`. Use a key from the first try; without one, check `run:list` first.

Docs: https://ignitify.dev/docs/guides/pass-input-and-read-results
