---
name: add-security-guard
description: Adds a security hook to a Claude Code project so that it fails closed, using guard-resolve. Use when someone says "add a guard", "block reads of .env", "stop force pushes", "protect the tests folder", "make this hook fail closed", "wire a security hook", or asks which hooks should block when they break. Sorts the hook into fail-closed or fail-open, writes the guard from a template that also fails closed inside, wires it behind guard-resolve.sh, and proves it both blocks and allows. Cheap to wire, expensive to discover a guard stopped running months ago.
---

# Add a security guard

A hook that can't run usually lets the tool call through. For a reminder that's fine. For
a security check it's the worst case, because a guard that silently stopped running looks
exactly like a guard with nothing to report.

`guard-resolve.sh` launches a guard and **blocks the call** if the guard's runtime or
script is missing. This skill decides which hooks need that, writes the guard so it also
fails closed inside, wires it in, and proves it works.

Files this skill uses are at the plugin's root, two folders up from this skill's folder:
`scripts/guard-resolve.sh` and `templates/guard-template.py`.

## Step 1 — Does this hook need to fail closed?

Ask one question: **if this hook silently stopped running, would anything bad get through?**

| Kind of hook | Fail closed? | Examples |
|---|---|---|
| Protects secrets and credentials | **Yes** | Block reading or writing `.env`, private keys, cloud credential files, token stores |
| Blocks destructive shell commands | **Yes** | `rm -rf` on broad paths, `curl … \| sh`, disk and partition tools, `chmod -R 777` |
| Blocks destructive version-control operations | **Yes** | Force push to a protected branch, `reset --hard`, `clean -fdx` |
| Protects paths Claude must not change | **Yes** | Tests, CI configuration, Claude's own settings and hooks, lockfiles, migrations |
| Stops data leaving the machine | **Yes** | Uploading files to unknown hosts, pasting secrets into web requests |
| Caps runaway activity | **Yes** | Limits on how many subagents can be spawned |
| Screens fetched content for injected instructions | **Usually** | Prompt-injection screening of web pages and tool output |
| Auto-approves safe commands | **No** | If it can't run, the normal permission prompt is already the safe fallback |
| Reminds, formats, lints or logs | **No** | Style reminders, code formatters, audit logs |

If the answer is no, wire the hook normally and stop here.

## Step 2 — Write the guard

Copy `templates/guard-template.py` to `.claude/hooks/guards/<guard-name>.py` and fill it in.
Keep its shape:

- **Exit 0 allows, exit 2 blocks**, and the stderr text is the reason Claude reads.
- **Any internal error blocks.** The template wraps the whole decision so that a payload it
  can't parse, or a bug, exits 2. guard-resolve only covers the guard failing to start; this
  covers it failing after it started.
- **Keep what it protects in an explicit list** at the top of the file.

A guard in another language works the same way, as long as it keeps that contract.

## Step 3 — Wire it

1. Copy `scripts/guard-resolve.sh` to `.claude/hooks/guard-resolve.sh` in the project.
2. Add a `PreToolUse` entry to `.claude/settings.json`. The command finds the launcher from
   the project root or any parent folder, and **blocks if the launcher itself is missing**:

```json
{
  "matcher": "Read|Edit|Write|MultiEdit",
  "hooks": [{
    "type": "command",
    "command": "g=.claude/hooks/guard-resolve.sh; t=.claude/hooks/guards/<guard-name>.py; [ -n \"$CLAUDE_PROJECT_DIR\" ] && [ -f \"$CLAUDE_PROJECT_DIR/$g\" ] && exec bash \"$CLAUDE_PROJECT_DIR/$g\" python3 \"$t\"; p=\"$PWD\"; while [ \"$p\" != \"/\" ]; do [ -f \"$p/$g\" ] && exec bash \"$p/$g\" python3 \"$t\"; p=$(dirname \"$p\"); done; echo \"GUARD BLOCKED: guard-resolve.sh not found from $PWD\" >&2; exit 2"
  }]
}
```

Set `matcher` to the tools the guard inspects (`Bash` for shell commands).

## Step 4 — Prove it blocks and allows

A guard you haven't seen block isn't a guard. Run all four, and keep them as a test file
beside the guard:

```bash
# blocks a bad call
echo '{"tool_name":"Read","tool_input":{"file_path":".env"}}' | bash .claude/hooks/guard-resolve.sh python3 .claude/hooks/guards/<guard-name>.py; echo "exit=$?"   # want 2
# allows a good call
echo '{"tool_name":"Read","tool_input":{"file_path":"README.md"}}' | bash .claude/hooks/guard-resolve.sh python3 .claude/hooks/guards/<guard-name>.py; echo "exit=$?"   # want 0
# blocks when the guard is missing
echo '{}' | bash .claude/hooks/guard-resolve.sh python3 .claude/hooks/guards/missing.py; echo "exit=$?"   # want 2
# blocks when the guard crashes on bad input
echo 'not json' | bash .claude/hooks/guard-resolve.sh python3 .claude/hooks/guards/<guard-name>.py; echo "exit=$?"   # want 2
```

Then trigger it once in a real session and confirm Claude sees the block message.

## Limits to tell the person

- guard-resolve covers the guard failing to start, and the template covers the guard
  failing while it runs. Nothing covers the hook entry being deleted from `settings.json`.
- Command hooks in a project's `.claude/settings.json` run in Claude Code. Other hosts load
  hooks differently, so check there before relying on the guard.
