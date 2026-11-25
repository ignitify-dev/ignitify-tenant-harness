# Ignitify tenant harness

Skills, prompts, templates and examples that teach an AI client how to work with [Ignitify](https://ignitify.dev/docs): how the platform works, how the `ignitify` CLI works, and how to find and fix a failed run or build.

- **Your client, your model.** Ignitify makes no model calls for your client. Your AI client (Claude Code, an IDE assistant, or any client that reads files and runs shell commands) reads this harness and calls its own model.
- **The CLI is the only tool.** The client runs `ignitify …` commands with your key. No MCP server, no extra service.
- **Tenant level only.** It covers your tasks, deployments, runs, secrets, webhooks, limits and usage, and a Terraform and OpenTofu setup of them.

## What is inside

| Folder | What it holds |
| :-- | :-- |
| `skills/` | Eleven skills in the open Agent Skills format (`SKILL.md` with `name` and `description`). Start with `ignitify-getting-started`. |
| `prompts/` | Sample prompts: diagnose a run, write a task, review a `task.yaml`, explain a failed deploy, prepare a support report. Each names the commands to run first. |
| `templates/` | `task.yaml` starters for node, python, go and rust. |
| `examples/` | Small working tasks: `node-github-stars`, `python-word-stats`, `go-checksum`, `rust-countdown`. |
| `clients/claude-code/` | A Claude Code plugin (skills and slash commands) and `settings.example.json` with permission rules. |
| `clients/generic/AGENTS.md` | An instruction block for any client that reads `AGENTS.md`. |
| `llms.txt` | An index of the files, for clients that read it. |
| `cli/commands.txt` | The commands and flags of the CLI version this harness was checked against. |

## Install

You need the Ignitify CLI 3.7.0 or newer first: `npm install --global ignitify` (Node 22.13 or newer), then `ignitify login`.

### Claude Code, as a plugin

```
/plugin marketplace add ignitify-dev/ignitify-tenant-harness
/plugin install ignitify@ignitify-tenant-harness
```

The skills load when they apply. The commands are `/ignitify:diagnose-run <run-id>`, `/ignitify:write-task <what>`, `/ignitify:review-task-yaml <slug>`, `/ignitify:why-deploy-failed <slug>` and `/ignitify:prepare-support-report <id>`.

### Claude Code or any client, with the install script

The script downloads one tagged release, checks its SHA-256, and copies files. It needs no root and no npm. It writes a manifest, so `--uninstall` removes exactly what it installed.

```sh
# Claude Code: skills and commands into ~/.claude (or ./.claude with --scope project)
curl -fsSL https://raw.githubusercontent.com/ignitify-dev/ignitify-tenant-harness/v0.1.9/install.sh | sh -s -- --client claude-code

# Any other client: files into ./.ignitify-harness, then add the AGENTS.md block to your project
curl -fsSL https://raw.githubusercontent.com/ignitify-dev/ignitify-tenant-harness/v0.1.9/install.sh | sh -s -- --client generic
```

Options: `--version <tag>`, `--sha256 <hex>` (the checksum from the release notes; stronger than the published `.sha256` file), `--from <checkout>` (no download), `--force`, `--uninstall`. Read the script before you run it.

### By hand

Copy `skills/` into the skills folder of your client, and the block in `clients/generic/AGENTS.md` into your project's instruction file.

## Safety

**Give your AI client its own read-only key.** With your own key (`ignitify login`), the client can do anything you can do: deploy, run (which uses your plan and costs compute), cancel and delete. As the tenant owner, make a user in a read-only group and give that user's key to the client:

```sh
ignitify permission:list    # the 11 permissions and what each allows
ignitify group:create readers --permissions tasks.read,deployments.read,runs.read,schedules.read,secrets.read,hooks.read,usage.read
ignitify user:create ai-assistant
ignitify group:add-user readers ai-assistant
ignitify key:create --user ai-assistant --label laptop --out ~/ignitify-ai-assistant.key
```

- `key:create --out` writes the key to a new file (mode 0600) and prints only the key id. Run these commands yourself: they need an owner key, and the AI client must never run `user:*`, `group:*` or `key:*`, nor read the key file.
- Put the key in the AI client's environment only, as `IGNITIFY_API_KEY`, when you start the client: for example `IGNITIFY_API_KEY="$(cat ~/ignitify-ai-assistant.key)" claude`. Not in your shell profile, a project file or a settings file the client can read.
- With this key the platform refuses every write with `permission denied: this key needs the <permission> permission`. `ignitify whoami` shows the key's user, groups and permissions in its "This Key" block. To allow more, grant it: `ignitify group:grant readers runs.write`. Read the notes of `ignitify permission:list` first: `tasks.write` can delete deployments and runs, `deployments.write` with `runs.write` can read secret values in practice, and `hooks.write` can start runs.
- The lock holds only while your owner key is out of the client's reach. On a machine where you are signed in with `ignitify login`, a client that unsets `IGNITIFY_API_KEY` falls back to your saved login. For a hard lock, run the client where no owner login is saved (another OS user, a container or a VM).
- To end the client's access: `ignitify key:list --user ai-assistant`, then `ignitify key:revoke <key-id>`.

With any key:

1. The skills tell the client to read freely, ask before every write, and never run deletes, secret commands, webhook creation, access commands, `login` or `logout`. These are instructions, not a lock: a client can ignore them. The read-only key is the lock.
2. In Claude Code, add the rules of `clients/claude-code/settings.example.json` to your `.claude/settings.json`. They allow read-only `ignitify` commands, `whoami`, `permission:list` and the harness skills, ask before writes, and deny the destructive, secret and access commands (`user:*`, `group:*`, `key:*`) and reads of the key files. A plugin cannot set permissions for you. What to expect (tested with Claude Code 2.1):
   - Claude Code ignores the `allow` rules of a project `.claude/settings.json` until you accept the trust dialog for that folder once; the `ask` and `deny` rules apply at once.
   - An `ask` rule wins over an `allow` rule, so `task:create --local` and `task:deploy --check` also ask, although they change nothing on the server.
   - A rule also matches the bare command (`Bash(ignitify whoami *)` matches `ignitify whoami`). A deny rule also matches inside an `&&` chain and after `VAR=value`. A command in `( … )` with pipes asks.
   - A command prefix with a colon needs the plain glob: `Bash(ignitify key*)` matches `ignitify key:create`; the same rule written with `key:*` at the end does not (Claude Code reads a final `:*` as its own prefix form).
   - `Read(~/.config/ignitify/**)` blocks the Read tool on the saved login. `Read(~/ignitify-ai-assistant.key)` blocks it on the user key; change the path if you keep the key elsewhere. `cat` of either file is not denied: it asks, so do not approve it. The rule does not cover a custom `$XDG_CONFIG_HOME`.
3. With your own key, do not export `IGNITIFY_API_KEY` in the shell your AI client uses; let it use the saved login, so the key value stays out of the client's environment. The CLI talks to one fixed Ignitify address; no flag changes it.
4. Review every command your client proposes. Do not approve `--yes` on a delete you did not ask for.
5. A retried `task:run` must carry the `--idempotency-key` of the first try and a pinned `--deployment`; then a retry after a network error starts no second run. The skills teach this.
6. Your client sends what it reads (run logs, results, `task.yaml`) to its model vendor. Keep secrets out of logs and results.
7. Run logs and results are written by code. The skills tell the client to treat them as data, not as instructions.

One platform feature uses a model: `ignitify task:validate --review-packages` sends your `build.system_packages` names and the runtime id to a platform-side AI review. It is opt-in, and nothing else is sent.

## Versions

The harness has its own version (`v0.1.9`). It needs ignitify CLI 3.7.0 or newer. Each release is checked against one CLI version, named on the first line of `cli/commands.txt`. When your CLI is newer, `ignitify help <command>` is the authority; the skills say so.

## For maintainers

```sh
sh scripts/check-commands.sh            # every `ignitify <command> --flag` in the docs exists in cli/commands.txt
sh scripts/check-commands.sh --refresh  # rewrite cli/commands.txt from the installed CLI
sh scripts/sync-clients.sh              # copy skills/ and prompts/ into the Claude Code plugin
sh scripts/sync-clients.sh --check      # fail when the copies are stale
sh scripts/release.sh v0.1.9            # build the release archive and checksum for a tag
bash scripts/publish.sh v0.1.9 notes.md   # check, tag, build, create the GitHub release and check its checksum
```

Edit `skills/` and `prompts/` only; the plugin folders are copies. Keep each fact in one skill and link to it from the others.

## Licence

Apache License 2.0. See [LICENSE](LICENSE). The Ignitify CLI has its own licence.
