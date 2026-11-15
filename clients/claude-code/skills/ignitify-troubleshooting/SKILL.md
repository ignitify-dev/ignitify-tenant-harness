---
name: ignitify-troubleshooting
description: Diagnose and fix Ignitify failures at the tenant level - a failed or stuck run, a failed build, a refused request (API 401, 403, 413, 429, permission denied, owner key required), a plan limit, a blocked network call, a missing secret, a webhook that does not start a run - with a step-by-step flow, the error catalogue and what to collect before contacting support. Use it whenever an `ignitify` command prints `Error:` or a run is not COMPLETED.
license: Apache-2.0
---

# Troubleshoot

Read `ignitify-getting-started` first. Every diagnostic command below is read-only. Do not run a write to "test a fix" without the user's consent.

## The shape of an error

- Every failure prints an `Error:` line on stderr and exits 1 (130 after Ctrl+C during a wait).
- A failed request adds the HTTP status and a JSON body: `Error: API 429: {"error":"…","reason":"…","boundBy":"…"}`.
- Read the `reason` and `boundBy` fields, not the words: the words can change.
- The next line is `server trace id: <id>`. Keep it for support.
- `boundBy: tier-entitlement` is a plan limit. `boundBy: host-capacity` is a short lack of room on the platform.

The full catalogue, line by line: [errors.md](errors.md).

## Diagnosis flow for a run

1. **Get the facts.**
   - `ignitify run:get <run-id> --json`: status, task, deployment, preset, timeout, result or error.
   - `ignitify run:timeline <run-id>`: what happened, and the failure class with one sentence.
2. **Classify.** The failure class in the timeline (or `ignitify run:failures`):
   - `task` → the code or the deployment. Go to step 3.
   - `limit` → a plan limit. See `ignitify-limits-and-cost`; check `ignitify quota`.
   - `cancelled` → someone stopped it. The timeline says who (`via`).
   - `platform` → the platform side. If it repeats, prepare a support report (below).
3. **Read the output.** `ignitify run:logs <run-id> --tail 200`. Find the first error, not the last.
4. **Match a pattern** (table below). Read `task.yaml` and the code before you propose a fix.
5. **Propose one fix**, explain why, and say what the user will see when it works. Validate it offline (`ignitify task:validate <slug>`). Deploy and run again only with the user's consent.

For a build that failed, use `ignitify deployment:get <deployment-id>` and `ignitify deployment:logs <deployment-id>` (see `ignitify-deploy`).

For a task that fails often, start with `ignitify run:failures --days 7` and `ignitify task:get <slug>`.

## Common failure patterns

| You see | Likely cause | Check, then fix |
| :-- | :-- | :-- |
| Run `FAILED`, log ends in a stack trace | A bug in `run()` | Read the trace; fix the code. A thrown error is the run error. |
| Run `FAILED` at once, init message | `init()` threw | The first run after a boot fails with the init error. Fix `init()`. |
| Run `FAILED`, `result exceeds max size` | The result is over the result limit | Return less; write big data to your own storage and return a link. |
| Run `FAILED` after about `timeout_sec` | No sign of life within `timeout_sec` | Raise `run.timeout_sec` (plan cap: `ignitify whoami`), or use `duration: long` for long work. |
| Task error `ECONNRESET` on one host | The host is not in `egress_allow` (a redirect to another host is also blocked) | Add the exact host; check `network.type` is not `none`. |
| Every outbound call fails | `network.type: none` (the default) | Set `type: egress`. |
| Node task error `fetch failed` and nothing more | Node's `fetch` puts the network reason in `err.cause` | Log or rethrow `err.cause.code`. `ECONNRESET`: host not in `egress_allow`. `EAI_AGAIN` or `ENOTFOUND`: the name did not resolve (a typo, or DNS trouble; if it repeats for a correct name, prepare a support report). |
| Run `FAILED`, a declared secret has no value | `secret:set` was never run for that name | Compare `secrets:` with `ignitify secret:list`. The user sets the value. |
| A secret reads as empty or missing in code | The name is not in `secrets:` in `task.yaml` | Declare it; only declared names reach `ctx.secrets`. |
| Bidirectional run fails, no public URL | `ctx.ready()` never called, or the task listens on another port | Call `ctx.ready()` after listen; `inbound_port` must equal the port in code. |
| Public URL answers 404 | The path is not in `inbound_routes` | Add a `prefix` or `path`. Prefixes are case-sensitive. |
| Crash or kill with no error of yours | Possibly: memory too small for the work | Try a bigger `run.preset` your plan allows. |
| Chunks never reach the caller | `interaction: boundary-only` | Set `interaction: continuous`. |
| Run stays `PENDING`, timeline "Queued: waiting for capacity" | No room right now | Wait; or `--on-busy reject` to fail fast. |
| Run in `RETRYING` | A short-lived platform failure | Wait. It counts against limits. Repeats → support. |
| `Error: API 429 … concurrent-run-quota` | All run slots in use | `ignitify quota`; wait or cancel a run (with consent). |
| `Error: API 429 … run-unit-quota` | Units full | A lighter preset, or wait. |
| `Error: API 429 … run-rate-quota` | Too many runs in the window | Wait for the window. |
| `Error: API 429: {"error":"API request rate limit exceeded"}` | A script sends too fast | Slow down. |
| `Run refused — a monthly limit is reached` | The monthly allowance is used | `ignitify quota` shows the reset time. |
| `Error: API 403 … not included in your current tier` | The plan lacks a capability | `ignitify whoami`, the `may_…` lines. |
| `Error: API 401` | The key is wrong, revoked or expired (90 days without use) | The user runs `ignitify login`. |
| `Not signed in.` | No saved key and no `IGNITIFY_API_KEY` | The user runs `ignitify login`. |
| `permission denied: this key needs the <permission> permission` | A user key whose groups lack that permission | Stop. Tell the user the command needs `<permission>`: ask the owner to grant it to your group (`ignitify group:grant <group> <permission>`, owner only). Do not retry, and do not look for another key. |
| `owner key required` | A user key on a `user:*`, `group:*` or `key:*` command | Only the tenant owner manages access. An AI client never runs these commands. |
| `this is the answer to an earlier request with the same --idempotency-key` | A retry of `task:run` with the same key | Not an error: no second run started. The run id is the first one's. |
| `Cannot reach <address> (…)` | Network, DNS or TLS on this machine | Check the network; the reason in brackets names it. |
| `unknown flag --x for <command>` | Typo or wrong command | `ignitify help <command>`. |
| `Refusing to proceed: not a TTY` | A delete in a script | The user runs it in a terminal. Do not add `--yes`. |
| A webhook answers 401 | The signature is over other bytes, or the content type is not JSON | Sign the exact body; send `content-type: application/json`. |
| A webhook answers 404 | The hook was deleted or belongs to an old deployment | `ignitify hook:list <deployment-id>`. |
| Timeline "Callback blocked" | The `notify:set` URL is not allowed | Use a public HTTPS address the platform can resolve. |
| The CLI warns the client is older than the API supports | An old CLI | The user upgrades: `npm install --global ignitify@latest`. |

## Before you contact support

Collect, and never include a key or a secret value:

- `ignitify --version` (both lines);
- the command, the full `Error:` line, and the `server trace id`;
- for a run: `ignitify run:get <run-id> --json` and `ignitify run:timeline <run-id>`;
- for a build: `ignitify deployment:get <deployment-id>`;
- `task.yaml` (it holds no secret values);
- what you expected, and what you tried.

The support report template is [support-report.md](support-report.md). The prompt `prepare-support-report` fills it.

Docs: https://ignitify.dev/docs/guides/troubleshoot and https://ignitify.dev/docs/reference/errors
