---
name: ignitify-terraform
description: Set up an existing Ignitify tenant as code with Terraform or OpenTofu - the Ignitify provider, the owner key versus user key split (two root modules), the resources (user, group, api_key, secret, task, deployment, hook, schedule), write-only secret values, import, what Terraform does not do, and when to use the ignitify CLI instead. Use it when the user asks for Terraform, OpenTofu, infrastructure as code or CI-managed tasks, secrets, hooks, recurring schedules or access.
license: Apache-2.0
---

# Terraform and OpenTofu

Read `ignitify-getting-started` first. You write the configuration. The user runs `plan` and `apply`, and holds the keys.

## Status and requirements

- The provider is `ignitify-dev/ignitify` on the Terraform Registry (v0.3.2 or newer; `ignitify_schedule` needs v0.4.0 or newer, and its `pause_detail` attribute v0.4.1 or newer). It is not in the OpenTofu Registry: with OpenTofu, the `source` must be the full address `registry.terraform.io/ignitify-dev/ignitify`. Do not invent another source.
- Terraform 1.11 or newer, or OpenTofu 1.11 or newer. Older versions have no write-only arguments, which `ignitify_secret` needs.
- It manages an existing tenant. See "What Terraform does not do".

```hcl
terraform {
  required_version = ">= 1.11"
  required_providers {
    ignitify = { source = "ignitify-dev/ignitify" }
  }
}

provider "ignitify" {}
```

The key comes from `IGNITIFY_API_KEY` (the argument `api_key` also exists; never write a key in a file). The address defaults to `https://api.ignitify.dev` (`IGNITIFY_API_URL` or `endpoint` change it; it must be `https`). The provider does not read the CLI's saved login.

## Two root modules: owner key and user key

| Module | Key | Manages |
| :-- | :-- | :-- |
| access | **owner key**, applied by the tenant owner by hand, rarely | `ignitify_user`, `ignitify_group`, `ignitify_api_key` |
| app | **user key** of a group with the needed permissions, applied by CI | `ignitify_secret`, `ignitify_task`, `ignitify_deployment`, `ignitify_hook`, `ignitify_schedule` |

- Keep them in two folders with two states. A user key on an access resource fails with HTTP 403, reason `owner-required` ("only an owner key manages users, groups and keys").
- The access module outputs the user's `raw_key` (sensitive). The owner puts it in the CI secret store; the app module reads it from `IGNITIFY_API_KEY`.
- Check the key in the access module: `data "ignitify_whoami" "me" {}` and a `check` block that asserts `is_owner_key`.
- A user key with `deployments.write` can read secret values through the code it deploys. Give it only to who may read them.
- Permissions for the app key: `tasks.read`, `tasks.write`, `deployments.read`, `deployments.write`, `secrets.read`, `secrets.write`, `hooks.read`, `hooks.write` (and `runs.read` to look at runs; `runs.read` and `runs.write` for `ignitify_schedule`; `runs.write` also lets the key start runs with `task:run`).
- Examples: `examples/access` and `examples/app` in the provider repository.

## Resources

| Resource | Needs | Main arguments | Import id |
| :-- | :-- | :-- | :-- |
| `ignitify_user` | owner key | `name` | the user name |
| `ignitify_group` | owner key | `name`, `permissions` (set), `members` (set of user names) | the group name |
| `ignitify_api_key` | owner key | `user`, `label`; read-only `raw_key` | the key's `resource_id` |
| `ignitify_secret` | `secrets.read`, `secrets.write` | `name`, `value_wo`, `value_wo_version` | the secret name |
| `ignitify_task` | `tasks.read`, `tasks.write` | `slug` | the task slug |
| `ignitify_deployment` | `tasks.read`, `deployments.*` | `task`, `source_dir`, `timeouts`; optional `notify_url`, `notify_secret_wo`, `notify_secret_wo_version` | the task slug, or `<task slug>/<deployment id>` |
| `ignitify_hook` | `hooks.read`, `hooks.write`, a plan with webhooks | `task`; read-only `url`, `secret` | `<task slug>/<hook resource_id>` |
| `ignitify_schedule` | `runs.read`, `runs.write` (`tasks.read` to import) | `task`, `cron`, `payload` (JSON, `jsonencode`); optional `timezone` (default `UTC`), `preset`, `timeout_sec`, `deadline_sec`, `execution` (JSON), `overlap` (`skip` or `allow`), `paused`; read-only `schedule_id`, `status`, `pause_reason`, `payload_sha256` | `<task slug>/<schedule_id>` |

Data source `ignitify_whoami` works with any key: tenant, tier, `is_owner_key`, permissions, limits.

Points to get right:

- **Names.** A change of a user name, group name, key user or label, secret name, task slug or hook task replaces the object. A replaced key has a new `raw_key`.
- **Group.** It owns its permissions and members: a grant or member added outside Terraform shows as drift. `members` defaults to none. Deleting a user revokes all its keys.
- **Task and deployment.** `ignitify_task.slug` must equal the `slug` in the task folder's `task.yaml`. `source_dir` is that task folder. A change of its files uploads them and waits for the build (set `timeouts`, default 30 minutes). When the new deployment is `READY`, the old one is deleted: this ends its running runs and deletes their history. An unchanged folder reuses the same deployment. A failed build keeps the old deployment and reports the build's reason. Never use `create_before_destroy` on `ignitify_deployment`. A task destroy deletes the task with its deployments, runs, hooks and schedules.
- **Hook.** It belongs to the task, so a code update keeps the URL and the secret. `secret` is shown once and kept in the state. To rotate: `terraform apply -replace=ignitify_hook.<name>`. How a caller signs the request: `ignitify-runs`.
- **Schedule.** A recurring run of the task's newest ready deployment; a code update keeps it. **Never put a secret in `payload`**: it is stored in the state in plain text. The task reads secrets through `ignitify_secret` and `ctx.secrets`. Write `task = ignitify_deployment.<name>.task`, so the schedule is created after the first build is `READY`; destroying only the deployment makes the slots miss, and the platform then pauses the schedule. Write the canonical zone (`Europe/Berlin`). The server checks the cron expression and the zone at apply. A payload, zone or pause changed outside Terraform shows as a change, and the apply sets it back. A schedule the platform paused (`status = "auto_paused"`) is no change: the plan warns, and the user fixes the cause, then runs `ignitify schedule:resume <schedule_id>`. If the plan does not include recurring schedules (`pause_reason = "plan-limit"`, `pause_detail = "max_schedules"`), the resume is refused: the user changes plan first. The plan's schedule limit counts paused schedules; a create over it fails with `schedule-quota`. A one-time run at a set time (`task:run --at`) is not a resource: use the CLI.
- **Notify.** `notify_url` (https) needs `notify_secret_wo` (32 characters or more). Raise `notify_secret_wo_version` to send a new secret.

## Secret values never enter the plan or the state

`value_wo` and `notify_secret_wo` are write-only: Terraform does not store them and cannot see a change.

```hcl
variable "db_password" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "db_password_version" {
  type    = number
  default = 1
}

resource "ignitify_secret" "db_password" {
  name             = "DB_PASSWORD"
  value_wo         = var.db_password
  value_wo_version = var.db_password_version
}
```

- To send a new value, the user raises `value_wo_version`.
- The value comes from the user (an environment variable `TF_VAR_db_password`, or a secrets manager). Never write a value in a `.tf` or `.tfvars` file, never ask for it, never print it.
- A create refuses a secret name that already exists. Import it first.
- Declare the secret name in `task.yaml` too (`secrets:`); see `ignitify-secrets`. Terraform stores the value; the task still reads only declared names.
- The state still holds `raw_key` and the hook `secret`. Tell the user to use an encrypted, access-controlled state backend.

## Import

For an object that already exists, the user runs `terraform import <address> <import id>` (or an `import` block). The ids are in the table. After an import:

- `raw_key` and the hook `secret` are empty (the server shows them once).
- A deployment has no `source_dir`: the first apply uploads the folder (the same code reuses the same deployment).
- A schedule has no `payload` (the server never shows it): the first apply sends the configured payload.
- A secret has no `value_wo_version`: if the configuration sets one, the first apply sends the value once.
- The task slug imports a deployment only when the task has exactly one live deployment.

## What Terraform does not do

- It never creates a tenant, a plan or a purchase, and never creates an owner key. The tenant must exist, and the user supplies the key.
- It does not start runs. Runs start from a hook, from `ignitify task:run`, or from the API. A `ignitify_hook` only makes the URL.
- It does not manage one-time schedules (`task:run --at`), run cancels, usage or logs. Recurring schedules are `ignitify_schedule`.

## When to use the CLI instead

| Need | Use |
| :-- | :-- |
| Write and check a task before you deploy it | `ignitify task:validate`, `task:pack`, `task:deploy --check` |
| Run a task, pass a payload, wait for the result | `ignitify task:run` (`ignitify-runs`) |
| Read runs, logs, usage, quota | `ignitify-observe`, `ignitify-limits-and-cost` |
| A one-time change, a quick look, a rollback | the CLI: `ignitify deployment:list`, `deployment:delete` (the user runs a delete) |
| A failed apply that names a deployment to delete | `ignitify deployment:delete <id>` (the user runs it) |

The CLI is also how you find the facts the configuration needs: `ignitify whoami`, `ignitify task:list`, `ignitify secret:list`.

## Rules for you

- Write `.tf` files freely. Run `terraform plan` or `tofu plan` only when the user asks; a plan reads the tenant with the user's key. Never run `apply`, `destroy` or `import` without the user's consent, and show the exact command.
- Never run the access module, and never read or print `IGNITIFY_API_KEY`, a state file or a `.tfvars` file.
- Read the plan before the user applies. Say clearly when it replaces a key, a user, a deployment or a schedule, or deletes a task.

Docs: https://ignitify.dev/docs
