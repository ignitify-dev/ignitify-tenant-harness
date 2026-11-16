---
name: ignitify-task-authoring
description: Write or change an Ignitify task - the task.yaml file (schema_version, slug, runtime, entry, execution nature, network, secrets, run defaults, build with system_packages) and the task code with run(payload, ctx) for the node, python, go and rust runtimes. Use it when the user wants a new task, asks what a task.yaml field means, or a task.yaml check fails.
license: Apache-2.0
---

# Author a task

Read `ignitify-getting-started` first for the safety rules.

## Start from the scaffold

`ignitify task:create <slug> --lang node|python|go|rust --local` writes a task that deploys without edits: `task.yaml`, the entry file, the dependency manifest, the lockfile and a README. `--local` calls no server and needs no key.

- The folder goes under `--dir`, else `$IGNITIFY_TASKS_DIR`, else `./tasks`. The folder name must equal `slug`.
- Go and Rust tasks get the runtime client in an `ignitify/` folder. Do not edit it and do not write it by hand: always scaffold Go and Rust.
- Without `--local`, `task:create` also registers the slug on the server. The slug stays registered: after a delete, `task:create` with it brings the same task back (`revived: true`). Ask the user first.
- Starter `task.yaml` files and small working examples for each runtime: https://github.com/ignitify-dev/ignitify-tenant-harness (folders `templates/task-yaml/` and `examples/`).

## Runtimes

| `runtime` | Entry file (default) | Dependency manifest | Lockfile (required) |
| :-- | :-- | :-- | :-- |
| `node` | `index.ts` | `package.json` | `package-lock.json` |
| `python` | `main.py` | `requirements.txt` | `requirements.txt` (with `--hash` on every line) |
| `go` | `main.go` | `go.mod` | `go.sum` |
| `rust` | `src/main.rs` | `Cargo.toml` | `Cargo.lock` |

An upload without its lockfile is refused. The platform builds the task; you need no toolchain to deploy. Python is 3.11 (Debian bookworm). Python lockfile command (from the scaffold header):
`uv pip compile --universal --generate-hashes --python-version 3.11 requirements.in -o requirements.txt`

## The task code

`run(payload, ctx)` runs once per job. Return a JSON value; it is the run result. `init()` is optional and runs once per process, before the first job.

| Runtime | Shape |
| :-- | :-- |
| node | `export async function run(payload, ctx) { … }` and optional `export async function init() { … }` |
| python | `def run(payload, ctx):` (`async def` works) and optional `def init():` |
| go | `func main() { ignitify.Start(run) }` with `func run(payload json.RawMessage, ctx *ignitify.Ctx) (any, error)`; init: `ignitify.Start(run, ignitify.WithInit(f))` |
| rust | `fn main() { ignitify_runtime::start(|| Ok(()), |payload: Value, ctx| { … }) }` |

The `ctx` object:

| Member (node/python/rust; Go uses capitals) | What it does |
| :-- | :-- |
| `ctx.secrets` | The run's secrets by name. Only names declared in `secrets:` are there. |
| `ctx.chunk(data)` | Sends a progress update before the result. It reaches the caller only with `interaction: continuous`. A new chunk replaces the last one; read it with `ignitify run:get <run-id> --full`. |
| `ctx.ready()` | Says "my inbound listener is up". Required for `network.type: bidirectional`. |
| `ctx.metric(name, value, type, attrs)` | Records a task metric (`counter` by default). The platform keeps 100 per run. |
| `ctx.callback` | This run's inbound callback (`url` and `verify(rawBody, signature)`), or none. `verify` returns a boolean. |

Console output goes to `ignitify run:logs`. In Node, print objects with `JSON.stringify`, or they show as `[object Object]`.

## task.yaml

Data only, never executed. File names in order: `task.yaml`, `task.yml`, `task.json`. An unknown key is refused, naming it.

```yaml
schema_version: 1          # required, only 1
slug: my-task              # required, equals the folder name; a-z, 0-9, inner hyphens, 1-63 chars
runtime: node              # required: node | python | go | rust
# entry: index.ts          # optional, default from the table above
secrets: [DB_PASSWORD]     # names only; values come from `ignitify secret:set`
execution: { … }           # the task nature, below
run:
  payload: {}              # default input for task:run
  preset: std.micro        # VM size
  timeout_sec: 120         # silence budget in seconds
build:
  allowed_hosts: [registry.example.com]  # extra hosts the BUILD may fetch from
  ship: [models/]                        # upload paths copied as they are into the image
  system_packages: [ffmpeg]              # Debian packages the task runs
```

### execution: the task nature

You declare what the task is. The platform derives how to run it. Every field is optional.

| Field | Values (default first) | Effect |
| :-- | :-- | :-- |
| `cardinality` | `one`, `many`, `continuous` | `one`: a new VM per run, torn down after. `many`: warm VM reused between runs. `continuous`: a resident VM. |
| `duration` | `short`, `long` | `long` sends heartbeats so the run can live past `timeout_sec`, up to a platform cap. `unbounded` is refused today. |
| `state` | `independent`, `across-runs` | `across-runs` keeps the process between runs (warning: no snapshot). Needs `many` or `continuous`. `across-crashes` is refused today. |
| `interaction` | `boundary-only`, `continuous` | `continuous` streams `ctx.chunk()` to the caller. |
| `storage_mib` | the preset default | Scratch disk in MiB, wiped at teardown. Less than the default is raised (a note says so). More than the plan limit is refused. |
| `residency` | `auto`, `pinned` | `pinned` keeps the VM until `vm:delete --force` or a delete of its deployment. A host restart loses the pin; the next run pins again. Needs `many` or `continuous` and a plan that allows pins. |
| `on_busy` | `queue`, `reject` | The default for `task:run --on-busy`: wait for room, or fail at once. Not part of the nature. |
| `network` | object, below | |

### execution.network

| Key | Needs `type` | Meaning |
| :-- | :-- | :-- |
| `type` | (required) | `none` (no NIC), `egress` (outbound only), `bidirectional` (outbound and inbound). Default `none`. |
| `egress_allow` | egress, bidirectional | Host allow list, max 32. Omit = any host. `[]` = no host. Only a left-most `*` matching one label (`*.a.com` matches `api.a.com`, not `a.com`). |
| `egress_tls_only` | egress, bidirectional | Drops plain port 80. On by default when `egress_allow` is set. |
| `egress_mbit` | egress, bidirectional | Bandwidth cap. You may only lower the plan ceiling. |
| `inbound_port` | bidirectional (required) | 1024-65535. The task listens here and calls `ctx.ready()`. A change forces a cold boot. |
| `inbound_routes` | bidirectional | Public path allow list: `- prefix: /api/` or `- path: /health`. Omit = no public path. Prefixes are case-sensitive. |
| `inbound_rps`, `inbound_burst` | bidirectional | You may only lower the plan ceilings. |
| `inbound_max_concurrent` | bidirectional | In-flight request cap. A value above the preset ceiling is lowered to it. |

A blocked outbound host shows in the task as a reset connection (`ECONNRESET`), not as a platform error. A bidirectional task runs one VM at a time. Inbound needs a plan that allows it (`ignitify whoami`).

### Refused combinations

`task:validate` and `task:deploy` refuse these:
- any network policy key with `type: none`; inbound keys without `bidirectional`; `bidirectional` without `inbound_port`;
- `cardinality: one` with `state: across-runs` or with `residency: pinned`;
- `duration: unbounded`, `state: across-crashes`;
- an unknown `run.preset`, an unknown key anywhere.

### run.preset

Names: `std.micro`, `std.small`, `std.medium`, `std.large`, `std.xlarge`, `mem.large`, `mem.xlarge`, `cpu.large`. Your plan sells only some of them: `ignitify whoami` lists `allowed_presets`. Sizes and limits: `ignitify-limits-and-cost`.

### build.system_packages

Bare Debian (bookworm, main) names: lower case, no version, no path, at most 64 names. Hard dependencies are installed; recommended packages are not. A tool that uses HTTPS also needs `ca-certificates`. A virtual name (`awk`) is refused with the real name to use (`mawk`).

## What the upload takes

- Every file under the task folder, except: `.git`, `.ignitify`, `node_modules`, `__pycache__`, `.venv`, `venv`, `.mypy_cache`, `.pytest_cache` (at any depth), `target` and `dist` (at the root), and `.env` / `.env.*` files (excluded with a warning: use secrets).
- Symlinks and special files are refused. A `.npmrc` or `.yarnrc.yml` with a registry token is refused.
- Files named `*.pem`, `*.key` or `id_rsa*` ARE uploaded and kept in the image, with only a warning. Never keep a real private key in the task folder.
- `.ignitifyignore` at the task root adds more exclusions.
- `ignitify task:pack <slug>` lists the files the next deploy would upload.

## Payload and result size

Both are small and the same on every plan. `ignitify whoami --json` gives the current numbers (`limits.max_payload_bytes`, `limits.max_result_bytes`). A result over the limit fails the run. For more data, write it to your own storage from the task and return a link.

## Check your work

1. `ignitify task:validate <slug>`: offline, no key. Fix every `✗` line.
2. `ignitify task:deploy <slug> --check`: every local check of a deploy, nothing uploaded.
3. Then follow `ignitify-deploy`.

## Common mistakes

- `slug` not equal to the folder name.
- No lockfile, or a Python `requirements.txt` without hashes.
- `egress_allow` set while `type` is still `none`.
- A secret value written in `task.yaml` or in code. Only names go in `secrets:`.
- A large file as payload. Pass a link.
- `ctx.chunk()` with `interaction: boundary-only`: the chunks never reach the caller.
- A bidirectional task that never calls `ctx.ready()`: the run fails.

Docs: https://ignitify.dev/docs/reference/task-yaml
