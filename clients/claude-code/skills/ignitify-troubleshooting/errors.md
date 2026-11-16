# Ignitify error catalogue (tenant)

Each entry: what you see, what it means, the fix. Words after `Error:` can change between CLI versions; the code in brackets at the end of a failed request (`Error: <sentence> [<reason>]`) is stable. With `--json`, or from an older CLI, the raw body prints (`Error: API <status>: {…}`); its `reason` and `boundBy` fields are the same stable data. The public page is the authority: https://ignitify.dev/docs/reference/errors

## Three gates refuse a request

| Gate | `boundBy` | Fix |
| :-- | :-- | :-- |
| Plan limit | `tier-entitlement` | Wait for the window or the reset, use less, or a bigger plan. |
| Capacity | `host-capacity` | Wait a short time and try again. It never names a plan. |
| Capability | (403, names the capability) | Change what you declare, or the plan. |

A user key can also be refused by its permissions (403, below: "Access"). That is not a plan limit.

## Plan limits

| `reason` | You see | Meaning and fix |
| :-- | :-- | :-- |
| `monthly-compute-quota` | `✗ Run refused — a monthly limit is reached (monthly-compute-quota).` | The monthly allowance is used. `ignitify quota` shows when it resets. While a payment has failed, it resets at the next paid renewal. |
| `concurrent-run-quota` | `Error: <sentence> [concurrent-run-quota]` (raw: `API 429: {… "reason":"concurrent-run-quota" …}`) | All run slots are in use. `limit` = allowed, `observed` = now. `--on-busy queue` does not wait for it. Wait, or cancel a run. |
| `run-unit-quota` | `Error: <sentence> [run-unit-quota]` (raw: `API 429: {… "reason":"run-unit-quota" …}`) | The new run needs more units than are free. Each preset has a weight (`ignitify whoami`). Use a lighter preset or wait. |
| `run-rate-quota` | `Error: <sentence> [run-rate-quota]` (raw: `API 429: {… "reason":"run-rate-quota", "window":"minute" …}`) | Too many runs started in the window. Wait for the window. |
| `rate-limited` | `Error: <sentence> [rate-limited]` (raw: `API 429: {"error":"API request rate limit exceeded", …}`) | Too many API requests per second. Slow the script. |

A webhook gets the same 429 and starts no run. A scheduled run waits and tries again for a limited time.

## Capability and declarations

| You see | Meaning and fix |
| :-- | :-- |
| `Error: API 403: {"error":"webhooks are not included in your current tier (capability 'may_use_webhooks' …)"}` | The plan does not allow it. `ignitify whoami` lists the `may_…` lines. |
| `Error: task.yaml: unknown run.preset "…" (valid: …)` | Use a name from the list. |
| A `task.yaml` line naming a field (`task:validate` or `task:deploy`) | A value the platform cannot honour. Fix the named field. Pins and inbound network need a plan that allows them. A value above the plan (`storage_mib`, and the ceilings the docs name) is refused, not lowered; `inbound_max_concurrent` above its ceiling is lowered. |
| `Error: API 400: {"error":"execution.storage_mib=… exceeds the scratch limit (… MiB)"}` | Declare at most the plan's scratch limit (`ignitify whoami`). |
| `✗ Run refused — this bidirectional deployment already has a live VM.` | A task with inbound traffic runs one VM at a time. `--on-busy queue` waits for it. |

## Before the request is sent

| You see | Meaning and fix |
| :-- | :-- |
| `Error: Not signed in. Run 'ignitify login', or set the IGNITIFY_API_KEY environment variable.` | No key. The user runs `ignitify login`. |
| `Error: API 401` | The key is wrong, revoked or expired. The user runs `ignitify login`. |
| `Error: unknown flag --… for <command>. Did you mean …?` | `ignitify help <command>`. |
| `Error: payload is N bytes; the limit is M bytes` | Pass a link, not the data. |
| `Error: --wait cannot be used with --at …` | A scheduled run has no run id yet. Drop `--wait`. |
| `Error: at must be in the future` | Give a future ISO 8601 time. |
| `Cannot reach <address> (<reason>)` | No HTTP answer: the reason names DNS, refused connection, timeout or TLS. Check the network. |
| `The saved key is for <address>, not <address>.` | The saved login belongs to another API address. The user signs in again. |
| `… can be read by other users (mode 0…). Run: chmod 600 …` | The saved key file is too open. The user runs the `chmod`. |

## Access (user keys)

A user key holds only the permissions of its user's groups. `ignitify whoami` shows them in the "This Key" block; `ignitify permission:list` lists them all.

| You see | Meaning and fix |
| :-- | :-- |
| `Error: permission denied: this key needs the <permission> permission. Ask the owner to grant it to one of your groups.` | Reason `permission-denied`. The key is a user key and none of its groups grants `<permission>`. An AI client stops and tells the user which permission the command needs. The owner decides: `ignitify group:grant <group> <permission>`. Do not retry, and do not switch to another key. |
| `Error: owner key required: only owner keys manage users, groups and keys. This is a user key.` | Reason `owner-required`. `user:*`, `group:*` and `key:*` need an owner key (from `ignitify login`). The tenant owner runs them; an AI client never does. |
| `Error: user name "…" is not valid: use 1 to 63 lower case letters, digits and '-', starting with a letter or digit` (or `group name`) | A user or group name breaks the name rule. Checked before anything is sent. |
| `Error: unknown permission "…"` | Not one of the 11 permissions. `ignitify permission:list`. |
| `key:create` exits 1: the server answered without the key (a replay of an earlier request) | The key exists but is not shown again. The owner revokes it (`ignitify key:revoke <key-id>`) and creates another. |

## Deploys and builds

| You see | Meaning and fix |
| :-- | :-- |
| `Error: task_id not found in .ignitify/state.json — run \`ignitify task:create <task-id>\` first` | The folder was made with `--local` and never registered, or `.ignitify/` was removed. The user registers it once: `ignitify task:create <slug> --no-scaffold` (the slug stays registered). |
| No deployment found for the task | `ignitify task:deploy <slug>` (with consent). |
| The latest deploy is still building | Wait until `ignitify deployment:get <id>` shows `READY`, or pass `--deployment <older-id>`. |
| `✗ Build failed` and `Error: deployment … failed to build — the build failed at stage "…"` | `ignitify deployment:get <id>` prints the stage and the log tail. Fix the cause (see `ignitify-deploy`). |
| The latest deploy failed | Nothing new to run. Fix the task, deploy again, or run an older `READY` deployment with `--deployment`. |
| An upload refused for a symlink, a special file, or a registry token in `.npmrc` / `.yarnrc.yml` | Remove the file or the token. |
| A note that `.env` was excluded | Expected: `.env` files are never uploaded. Use secrets. |

## Runs

| You see | Meaning and fix |
| :-- | :-- |
| Run `FAILED` with `result exceeds max size (…)` | The result is over the limit. Return less. |
| A storage note: `storage_mib N is below the <preset> default …` | Not an error. The run uses the preset default. |
| `schedule:cancel` exits 1 with "0 rows" | The schedule already fired or is firing. Look for the run in `ignitify run:list`. |
| `Error: --idempotency-key must be 8 to 255 characters of A-Z a-z 0-9 . _ : -, got: …` | Use a key of that form. Checked before anything is sent. |
| `this is the answer to an earlier request with the same --idempotency-key; no new run was started.` | Not an error. The retry got the first run's answer. |
| A refused keyed run with the hint `Use a new --idempotency-key for a different run.` | The key was used before for a different request (another payload, deployment or flag). A retry must repeat the first request exactly; a new run needs a new key. Pin `--deployment` in a retrying script. |
| A refused keyed run with the hint `If an earlier request with this key is still running, retry with the same key shortly.` | The first request with this key may still be in progress. Wait a moment, then retry with the same key and flags. |

## Scripts

| You see | Meaning and fix |
| :-- | :-- |
| `Error: Refusing to proceed: not a TTY. Re-run with --yes to confirm non-interactively.` | A delete or cancel asks first. An AI client must not add `--yes`; the user runs the command. |

## Webhooks and callbacks

| You see | Meaning and fix |
| :-- | :-- |
| `401 {"error":"invalid signature"}` | Sign the exact body bytes with HMAC-SHA256, hex, header `x-ignitify-signature: sha256=<hex>`, `content-type: application/json`. |
| `404 {"error":"unknown hook"}` | The hook id is wrong or deleted. |
| `409` on a hook call | The task has no `READY` deployment. Deploy it; the hook keeps its URL and secret. |
| `413 {"error":"payload too large"}` | The body is over the payload limit; it is refused before the signature check. |
| `429 {"error":"rate limited"}` | Too fast, or a plan run limit. No run started. |
| `notify url rejected: no-resolution` | The platform cannot resolve the host of the `notify:set` URL. Use a public host name. |
