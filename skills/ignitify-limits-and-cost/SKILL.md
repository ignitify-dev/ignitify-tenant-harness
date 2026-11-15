---
name: ignitify-limits-and-cost
description: Explain Ignitify plans (tiers), limits, presets and usage - whoami, quota, usage, usage:series and usage:export; run slots, units and preset weights; payload and result size; monthly allowances; what makes a task cost more. Use it when the user asks what the plan allows, why a run was refused for a limit, which preset to choose, or what they used this month.
license: Apache-2.0
---

# Limits and cost

Read `ignitify-getting-started` first. Every command here is read-only.

**Never quote a number from memory.** Plans change. Read the numbers of this account from the CLI.

## Which command shows what

| Question | Command |
| :-- | :-- |
| Which plan, and what does it allow? | `ignitify whoami` (`--json` for scripts) |
| What do I hold right now against the limits? | `ignitify quota` |
| What did I use this month, by axis? | `ignitify usage` (`--period YYYY-MM`, `--axis`, `--runs`, `--vms`) |
| Usage per day? | `ignitify usage:series --days 7` |
| The raw lines for a spreadsheet? | `ignitify usage:export --period YYYY-MM --csv` (or `--json`; name exactly one) |

`whoami` shows the plan name and version, then the entitlements: `max_tasks`, `max_running_vms`, `max_units`, `max_pinned_vms`, `max_warm_vms`, `max_secrets`, `max_webhooks`, the allowed presets, the scratch ceiling, the `may_…` capability lines, and the payload and result limits (`limits.max_payload_bytes`, `limits.max_result_bytes` in `--json`).

`quota` counts what you hold now (`used / max`) and the monthly allowances with their reset time. `usage` is the ledger for a calendar month.

## The limits that refuse work

| Limit | Checked | When hit |
| :-- | :-- | :-- |
| Running VMs (run slots) | at each run | `API 429 concurrent-run-quota` |
| Units (only some plans) | at each run; a run uses its preset's weight | `API 429 run-unit-quota` |
| Runs per window | at each run | `API 429 run-rate-quota` |
| API requests per second | each request | `API 429 API request rate limit exceeded` |
| Monthly allowance (for example compute) | at each run | `Run refused — a monthly limit is reached` |
| Presets, max `timeout_sec`, scratch (`storage_mib`) | at deploy and at run | refused, never lowered for you |
| Capabilities: outbound network, secrets, `duration: long`, `cardinality: continuous`, `state: across-runs`, pins, inbound network, webhooks, retries | each can be off for a plan; see the `may_…` lines of `ignitify whoami` | `API 403` or a refusal at deploy |
| Payload and result size (same on every plan) | per run | payload: refused before the run; result: the run fails |

Details of each refusal: the `ignitify-troubleshooting` skill.

## Presets

`run.preset` sets vCPU, memory and the default scratch disk. Names: `std.micro`, `std.small`, `std.medium`, `std.large`, `std.xlarge`, `mem.large`, `mem.xlarge`, `cpu.large`. The plan sells only some (`ignitify whoami`). On a plan with units, a bigger preset uses more units while it runs. The sizes are on https://ignitify.dev/docs/concepts/presets-and-limits.

Choose the smallest preset that runs the work. If a run crashes with no error of its own, try the next size.

## Usage axes (`ignitify usage`)

| Axis | Unit | What grows it |
| :-- | :-- | :-- |
| `compute` | time | VM time of runs (counted when the VM closes). |
| `network` | bytes | Outbound traffic. |
| `network_in` | bytes | Inbound traffic. |
| `disk` | byte-hours | Stored images of deployments. |
| `scratch` | byte-hours | Scratch disk reserved by VMs. |
| `runs` | runs | Runs started. |
| `pin` | time | Time VMs stay pinned. |
| `build` | time | Build time of deployments. |

## What makes a task cost more

- A pinned VM (`residency: pinned`): it holds its slot until the user deletes it. Check `ignitify vm:list --pinned`.
- A warm VM (`cardinality: many`) that stays idle; a resident VM (`continuous`).
- A large `storage_mib`: the disk is reserved in full at boot.
- A preset larger than the work needs.
- A long `timeout_sec` on a task that hangs.
- Many deployments kept: each image is stored. Old deployments can be deleted by the user.
- Retried platform failures count against limits.

Prices and plans: https://ignitify.dev/pricing
