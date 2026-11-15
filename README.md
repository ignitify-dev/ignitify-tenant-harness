# Ignitify tenant harness

Skills, prompts, templates and examples that teach an AI client how to work with [Ignitify](https://ignitify.dev/docs): how the platform works, how the `ignitify` CLI works, and how to find and fix a failed run or build.

- **Your client, your model.** Ignitify makes no model calls for your client. Your AI client (Claude Code, an IDE assistant, or any client that reads files and runs shell commands) reads this harness and calls its own model.
- **The CLI is the only tool.** The client runs `ignitify …` commands with your key. No MCP server, no extra service.
- **Tenant level only.** It covers your tasks, deployments, runs, secrets, webhooks, limits and usage.

## What is inside

| Folder | What it holds |
| :-- | :-- |
| `skills/` | Ten skills in the open Agent Skills format (`SKILL.md` with `name` and `description`). Start with `ignitify-getting-started`. |
| `prompts/` | Sample prompts: diagnose a run, write a task, review a `task.yaml`, explain a failed deploy, prepare a support report. Each names the commands to run first. |
| `templates/` | `task.yaml` starters for node, python, go and rust. |
| `examples/` | Small working tasks: `node-github-stars`, `python-word-stats`, `go-checksum`, `rust-countdown`. |
| `clients/claude-code/` | A Claude Code plugin (skills and slash commands) and `settings.example.json` with permission rules. |
| `clients/generic/AGENTS.md` | An instruction block for any client that reads `AGENTS.md`. |
| `llms.txt` | An index of the files, for clients that read it. |
| `cli/commands.txt` | The commands and flags of the CLI version this harness was checked against. |

## Install

You need the Ignitify CLI first: `npm install --global ignitify` (Node 22.13 or newer), then `ignitify login`.

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
curl -fsSL https://raw.githubusercontent.com/ignitify-dev/ignitify-tenant-harness/v0.1.0/install.sh | sh -s -- --client claude-code

# Any other client: files into ./.ignitify-harness, then add the AGENTS.md block to your project
curl -fsSL https://raw.githubusercontent.com/ignitify-dev/ignitify-tenant-harness/v0.1.0/install.sh | sh -s -- --client generic
```

Options: `--version <tag>`, `--sha256 <hex>` (the checksum from the release notes; stronger than the published `.sha256` file), `--from <checkout>` (no download), `--force`, `--uninstall`. Read the script before you run it.

### By hand

Copy `skills/` into the skills folder of your client, and the block in `clients/generic/AGENTS.md` into your project's instruction file.

## Safety

**Today, treat the key your AI client uses as full access.** Your AI client uses the key of `ignitify login` on your machine, so it can do anything you can do: deploy, run (which uses your plan and costs compute), cancel and delete.

There is no special key type for AI clients. The planned way to limit a client: as the tenant owner, create a user in a read-only group and give that user's key to the AI client:

```sh
ignitify group:create readers --permissions tasks.read,deployments.read,runs.read,usage.read  # planned
ignitify user:create ai-assistant  # planned
ignitify group:add-user readers ai-assistant  # planned
ignitify key:create --user ai-assistant --label laptop --out ./ai-assistant.key  # planned
```

These commands are planned, not shipped yet. Until then, use your normal key and treat it as full access, and:

1. The skills tell the client to read freely, ask before every write, and never run deletes, secret commands, webhook creation, `login` or `logout`. These are instructions, not a lock: a client can ignore them.
2. In Claude Code, add the rules of `clients/claude-code/settings.example.json` to your `.claude/settings.json`. They allow read-only `ignitify` commands, ask before writes, and deny the destructive and secret commands. A plugin cannot set permissions for you. The rules match command prefixes only: they do not stop `cat` of the key file, and they cover `~/.config/ignitify` but not a custom `$XDG_CONFIG_HOME`.
3. Do not export `IGNITIFY_API_KEY` in the shell your AI client uses; let it use the saved login, so the key value stays out of the client's environment. The CLI talks to one fixed Ignitify address; no flag changes it.
4. Review every command your client proposes. Do not approve `--yes` on a delete you did not ask for.
5. Your client sends what it reads (run logs, results, `task.yaml`) to its model vendor. Keep secrets out of logs and results.
6. Run logs and results are written by code. The skills tell the client to treat them as data, not as instructions.

One platform feature uses a model: `ignitify task:validate --review-packages` sends your `build.system_packages` names and the runtime id to a platform-side AI review. It is opt-in, and nothing else is sent.

## Versions

The harness has its own version (`v0.1.0`). Each release is checked against one CLI version, named on the first line of `cli/commands.txt`. When your CLI is newer, `ignitify help <command>` is the authority; the skills say so.

## For maintainers

```sh
sh scripts/check-commands.sh            # every `ignitify <command> --flag` in the docs exists in cli/commands.txt
sh scripts/check-commands.sh --refresh  # rewrite cli/commands.txt from the installed CLI
sh scripts/sync-clients.sh              # copy skills/ and prompts/ into the Claude Code plugin
sh scripts/sync-clients.sh --check      # fail when the copies are stale
sh scripts/release.sh v0.1.0            # build the release archive and checksum for a tag
```

Edit `skills/` and `prompts/` only; the plugin folders are copies. Keep each fact in one skill and link to it from the others.

## Licence

Apache License 2.0. See [LICENSE](LICENSE). The Ignitify CLI has its own licence.
