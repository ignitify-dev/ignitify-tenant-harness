---
name: ignitify-integrations
description: Add an Ignitify integration package (@ignitify-integrations/<name>) to a Node task with integration:add, read its plan, use --dry-run, and keep task.yaml in step with it. Use it when the user wants a Node task to use a supported service (for example storage or streaming) or task:validate reports that task.yaml no longer covers an integration.
license: Apache-2.0
---

# Integrations

Read `ignitify-getting-started` first.

## What an integration is

One npm package, `@ignitify-integrations/<name>`, for one service. It lists the settings a task needs: secret names, egress hosts, the network type, system packages, the smallest preset. Some also have code to import. They work with **Node** tasks only.

- `task.yaml` stays the one truth. The platform enforces only `task.yaml`.
- `package.json` records which integrations the task has.
- You can always write the same settings by hand.

The list of integrations is in the integration catalog: https://ignitify.dev/integrations/catalog

## Add one

First show the plan. It changes nothing:

```sh
ignitify integration:add <name> --task <slug> --dry-run
```

The plan shows each `task.yaml` change, then a "you add" part: secret values and hosts that differ per user. Show it to the user. Then, with the user's consent, the user runs (or approves) the same command without `--dry-run`; it asks `Apply? [y/N]`.

After a yes it runs `npm install` of that exact version (no install scripts), then writes `task.yaml`. Comments and key order stay. If the install fails, `task.yaml` is not written.

Rules of the plan:
- A conflict with `task.yaml` is refused, never overwritten. The user fixes the value by hand.
- Settings only go up: the network type and the preset rise, lists are joined.
- An integration cannot ask for a wildcard host.
- The task folder needs a `package.json`.
- Without a terminal, the command needs `--yes` or `--dry-run`. Do not add `--yes` yourself.

## After you add one

1. Add the "you add" hosts to `execution.network.egress_allow`.
2. The user sets the secret values (`ignitify-secrets`).
3. `ignitify task:validate <slug>`: it checks that `task.yaml` still covers every integration in `package.json`. If a listed package is not in `node_modules`, run `npm install` first.
4. Deploy (`ignitify-deploy`).

## Upgrade or remove

- Upgrade: run `integration:add` again. It shows only the new settings.
- Remove: `npm uninstall @ignitify-integrations/<name>` in the task folder. The settings it wrote stay in `task.yaml`; delete the ones you no longer need.

Docs: https://ignitify.dev/docs/guides/integrations
