# guard-resolve

guard-resolve makes your Claude Code security hooks fail closed.

When a command hook can't run because its script was moved or deleted, or its runtime isn't
installed, Claude Code usually lets the tool call through. For a reminder or a formatter
that's fine. For a security check it's the worst case: a guard that silently stopped running
looks exactly like a guard with nothing to report.

`guard-resolve.sh` launches a guard and **blocks the tool call, with a reason**, if the
guard's runtime or script is missing. You find out the first time it happens, not months
later.

## What's in it

| File | What it's for |
|---|---|
| `scripts/guard-resolve.sh` | The launcher. Finds the guard from `CLAUDE_PROJECT_DIR` or by searching up from the working folder, and exits 2 (block) if it can't run it. |
| `templates/guard-template.py` | A guard that also fails closed inside: a payload it can't parse, or a bug, blocks. |
| `skills/add-security-guard` | Walks Claude through deciding whether a hook needs to fail closed, writing the guard, wiring it, and proving it blocks and allows. |
| `scripts/test-guard-resolve.sh` | Ten cases covering both directions, plus `--mutate`, which breaks the launcher four ways and requires every break to be caught. |

## Which hooks need it

Ask one question: **if this hook silently stopped running, would anything bad get
through?**

- **Fails closed:** guards that protect secrets, block destructive shell or version-control
  commands, protect paths Claude must not change, stop data leaving the machine, or cap
  runaway activity.
- **Can fail open:** reminders, formatters, linters, loggers, and auto-approvers. If an
  auto-approver can't run, Claude Code's normal permission prompt is already the safe
  fallback.

The `add-security-guard` skill carries the full table.

## Use it

Ask Claude to "add a guard that blocks reads of .env" and the skill does the rest. To wire
one by hand, copy `scripts/guard-resolve.sh` to `.claude/hooks/` in your project and follow
Step 3 of the skill. Its wiring blocks even if the launcher itself has gone missing.

## Limits

- guard-resolve covers a guard that fails to start, and the template covers a guard that
  fails while running. Nothing covers the hook entry being deleted from `settings.json`.
- Command hooks in a project's `.claude/settings.json` run in Claude Code. Other hosts load
  hooks differently, so check there before relying on a guard.

## What it runs

Only what you point it at. The launcher runs `command -v` to find the runtime, then
replaces itself with `<runtime> <your guard> [args]`. It makes no network requests and
writes no files.

## Verify it

```bash
bash scripts/test-guard-resolve.sh --mutate
```
