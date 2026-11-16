---
description: Write a new Ignitify task from a plain description of what it must do.
argument-hint: <what the task must do>
allowed-tools:
  - Bash(ignitify task:validate *)
  - Bash(ignitify task:pack *)
  - Bash(ignitify whoami *)
  - Bash(ignitify help *)
---
Write an Ignitify task that does this: $ARGUMENTS

Use the `ignitify-task-authoring` skill.

Run these first:

1. `ignitify whoami` (the allowed presets, the scratch limit, and whether the plan allows inbound network and pins).
2. Agree the runtime (node, python, go or rust) and the slug with the user.
3. `ignitify task:create <slug> --lang <runtime> --local` (no server call; the slug is not reserved).

Then:
- write the code in the entry file: `run(payload, ctx)`, small JSON in and out;
- set `execution` to the smallest nature that fits; `network.type: none` unless the task must call out, then list each host in `egress_allow`;
- declare secret NAMES only; tell the user which values to set with `ignitify secret:set <NAME> --stdin`;
- add dependencies with the runtime's own tool so that the lockfile is right;
- run `ignitify task:validate <slug>` and `ignitify task:deploy <slug> --check` until both pass.

Stop there. Show the user the files and the commands to register the slug once (`ignitify task:create <slug> --no-scaffold`; the slug is then registered on the server), deploy and run. For a run that a script may retry, show `ignitify task:run <slug> --deployment <deployment-id> --idempotency-key <key> --wait` (see `ignitify-runs`). Do not run `task:create` without `--local`, `task:deploy` or `task:run` unless the user says so.
