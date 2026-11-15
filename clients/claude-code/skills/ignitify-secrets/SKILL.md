---
name: ignitify-secrets
description: Use secrets in an Ignitify task - declare secret names in task.yaml, let the user store values with secret:set --stdin, read them as ctx.secrets in node, python, go or rust, list names with secret:list. Use it when a task needs an API key, token or password, or a run fails because a secret has no value.
license: Apache-2.0
---

# Secrets

Read `ignitify-getting-started` first. You handle secret NAMES. The user handles secret VALUES.

## The three steps

1. **Declare the name** in `task.yaml`. Capital letters, digits and underscores, starting with a letter:
   ```yaml
   secrets: [GITHUB_TOKEN]
   ```
2. **The user stores the value.** Give the user this command and let them run it. Never run it yourself and never ask for the value:
   ```sh
   ignitify secret:set GITHUB_TOKEN --stdin < token.txt
   ```
   A value on the command line is refused. The value can never be read back.
3. **Read it in the task:**

   | Runtime | Read |
   | :-- | :-- |
   | node | `ctx.secrets.GITHUB_TOKEN` |
   | python | `ctx.secrets["GITHUB_TOKEN"]` |
   | go | `ctx.Secrets["GITHUB_TOKEN"]` |
   | rust | `ctx.secrets.get("GITHUB_TOKEN")` |

   The run gets only the names that `task.yaml` declares. A secret is per tenant: every task that declares the name reads the same value.

## Check

- `ignitify secret:list` shows the names and update times. It is safe to run.
- A run fails if a declared name has no value. Compare `secrets:` in `task.yaml` with `ignitify secret:list`.
- `ignitify whoami` shows `max_secrets` for the plan.

## Rules

- Never write a value in `task.yaml`, in code, in a payload, in a commit, or in a `.env` file in the task folder. `.env` files are not uploaded.
- Never log a secret. `run:logs` keeps console output.
- Rotate a value: the user runs `secret:set` again with the new value.
- Remove: the user runs `ignitify secret:delete <NAME>` (it asks first).
- An integration adds the names it needs to `task.yaml`. The user still sets the values.

Docs: https://ignitify.dev/docs/guides/use-secrets
