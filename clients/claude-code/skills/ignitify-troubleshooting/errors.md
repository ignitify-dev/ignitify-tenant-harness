# Ignitify error catalogue (tenant)

Each entry: what you see, what it means, the fix. Words after `Error:` can change between CLI versions; the `reason` and `boundBy` fields of an `API <status>` body are stable. The public page is the authority: https://ignitify.dev/docs/reference/errors

## Three gates refuse a request

| Gate | `boundBy` | Fix |
| :-- | :-- | :-- |
| Plan limit | `tier-entitlement` | Wait for the window or the reset, use less, or a bigger plan. |
| Capacity | `host-capacity` | Wait a short time and try again. It never names a plan. |
| Capability | (403, names the capability) | Change what you declare, or the plan. |

## Plan limits

| `reason` | You see | Meaning and fix |
| :-- | :-- | :-- |
| `monthly-compute-quota` | `✗ Run refused — a monthly limit is reached (monthly-compute-quota).` | The monthly allowance is used. `ignitify quota` shows when it resets. While a payment has failed, it resets at the next paid renewal. |
| `concurrent-run-quota` | `Error: API 429: {… "reason":"concurrent-run-quota" …}` | All run slots are in use. `limit` = allowed, `observed` = now. `--on-busy queue` does not wait for it. Wait, or cancel a run. |
| `run-unit-quota` | `Error: API 429: {… "reason":"run-unit-quota" …}` | The new run needs more units than are free. Each preset has a weight (`ignitify whoami`). Use a lighter preset or wait. |
| `run-rate-quota` | `Error: API 429: {… "reason":"run-rate-quota", "window":"minute" …}` | Too many runs started in the window. Wait for the window. |
| (no reason) | `Error: API 429: {"error":"API request rate limit exceeded"}` | Too many API requests per second. Slow the script. |

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

## Deploys and builds

| You see | Meaning and fix |
| :-- | :-- |
| `Error: task_id not found in .ignitify/state.json — run \`ignitify task:create <task-id>\` first` | The folder was made with `--local` and never registered, or `.ignitify/` was removed. The user registers it once: `ignitify task:create <slug> --no-scaffold` (the slug is reserved forever). |
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

## Scripts

| You see | Meaning and fix |
| :-- | :-- |
| `Error: Refusing to proceed: not a TTY. Re-run with --yes to confirm non-interactively.` | A delete or cancel asks first. An AI client must not add `--yes`; the user runs the command. |

## Webhooks and callbacks

| You see | Meaning and fix |
| :-- | :-- |
| `401 {"error":"invalid signature"}` | Sign the exact body bytes with HMAC-SHA256, hex, header `x-ignitify-signature: sha256=<hex>`, `content-type: application/json`. |
| `404 {"error":"unknown hook"}` | The hook id is wrong or deleted. |
| `413 {"error":"payload too large"}` | The body is over the payload limit; it is refused before the signature check. |
| `429 {"error":"rate limited"}` | Too fast, or a plan run limit. No run started. |
| `notify url rejected: no-resolution` | The platform cannot resolve the host of the `notify:set` URL. Use a public host name. |
