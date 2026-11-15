---
description: Review an Ignitify task.yaml for mistakes, risks and cost.
argument-hint: <slug>
allowed-tools:
  - Bash(ignitify task:validate *)
  - Bash(ignitify task:pack *)
  - Bash(ignitify task:get *)
  - Bash(ignitify whoami *)
  - Bash(ignitify secret:list)
---
Review the `task.yaml` of the Ignitify task `$ARGUMENTS`. Use the `ignitify-task-authoring` and `ignitify-limits-and-cost` skills.

Run these first. All are read-only:

1. `ignitify task:validate $ARGUMENTS`
2. `ignitify task:pack $ARGUMENTS` (the files the upload would take)
3. `ignitify whoami` (what the plan allows)
4. `ignitify secret:list` (names only; compare with `secrets:`)

Then read `task.yaml` and the entry file, and check:
- the slug equals the folder name, and the lockfile exists;
- the network is the smallest that works: `none`, or `egress` with an exact `egress_allow`; inbound only when the task serves requests, with `inbound_routes`;
- each declared secret is used, and each used secret is declared and has a value;
- `ctx.chunk()` is used only with `interaction: continuous`; `ctx.ready()` is called for `bidirectional`;
- the preset, `storage_mib`, `timeout_sec` and residency fit the work and the plan; flag `residency: pinned` and large disks as cost;
- no secret, `.env` or credential file would be uploaded; flag any `*.pem`, `*.key` or `id_rsa*` file in the `task:pack` list (it is uploaded and kept in the image).

Report the findings as a short list, most serious first, each with the fix. Change no file unless the user asks.
