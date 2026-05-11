# Hooks

Shell or Python scripts triggered by Claude Code events (PreToolUse, PostToolUse, Stop, SessionStart). Wired up in `.claude/settings.json`.

## Bundled

- **compact-recovery.sh** — Stop hook with `compact` matcher. Re-injects `ROADMAP.md` (if present) and recent git history after context-window compaction, so the next thread has continuity.
- **kiss-yagni-reminder.py** — PreToolUse hook on Write|Edit. Prints a one-line KISS / YAGNI checkpoint to stderr when writing code files. Reminds — does not block.

## Adding hooks

A hook is a script that reads JSON from stdin (the tool call payload) and exits with one of:

- **0** — allow / pass through
- **2** — block (the tool call does not execute)

Wire new hooks in `settings.json.template` so they ship with `init.sh`. Project-specific hooks should be added to the project's own `.claude/settings.json` and `.claude/hooks/`, not here — this template stays universal.
