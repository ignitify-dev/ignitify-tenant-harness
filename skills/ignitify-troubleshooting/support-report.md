# Ignitify support report

> Remove every API key, token, password, secret value and personal data before you send this.
> Never attach `~/.config/ignitify/credentials.json` or a `.env` file.

## Summary

- What I tried to do:
- What happened instead:
- When it started (UTC):
- How often (once / sometimes / every time):

## Versions

```
<output of: ignitify --version>
```

## The failing command

```
<the exact command>
<the full Error: line>
server trace id: <copy exactly>
```

## The run (if a run failed)

- Run id:
- Correlation id (`correlation_id` in `ignitify run:get <run-id> --json`; support traces the run by it):
- Status and failure class (from `ignitify run:timeline <run-id>`):

```
<output of: ignitify run:get <run-id> --json>
```

```
<output of: ignitify run:timeline <run-id>>
```

## The deployment (if a build failed)

- Deployment id:

```
<output of: ignitify deployment:get <deployment-id>>
```

## task.yaml

```yaml
<task.yaml: it holds secret names only, never values>
```

## What I already checked

- [ ] `ignitify task:validate <slug>` passes
- [ ] The error is in the troubleshooting skill or https://ignitify.dev/docs/reference/errors, and its fix did not help
- [ ] `ignitify quota` shows no limit reached
