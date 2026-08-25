# Hooks

Shell or Python scripts triggered by Claude Code events (PreToolUse, PostToolUse, Stop, SessionStart). Wired in `.claude/settings.json`.

## Bundled

- **availability-claim-validator.py** — PreToolUse on Write|Edit. Fires when text asserts something is blocked, unreachable, missing, or owed by someone else *without* probe evidence nearby. An unavailability claim is a finding and must carry the search that produced it. Ships `REPORT_ONLY = True`; flip it off once you have backtested the false-positive rate on your corpus. Override consciously with `<!-- probe-ok: reason -->` or by writing `NOT PROBED` beside the claim — which is the compliant form.
- **compact-recovery.sh** — Stop hook with `compact` matcher. Re-injects `ROADMAP.md` (if present) and recent git history after context-window compaction.
- **kiss-yagni-reminder.py** — PreToolUse on Write|Edit. Prints a one-line KISS / YAGNI checkpoint to stderr when writing code files. Reminds, does not block.
- **ralph-stop.sh** — Stop hook for the Ralph Loop. Reads `.ralph-loop/state.json`, scans the session transcript for the completion-promise, decides whether to allow exit or block + re-feed the prompt. Implements the canonical Ralph Wiggum technique.

## Adding hooks

A hook is a script that reads JSON from stdin (the tool call payload) and either:

- Exits 0 — allow / pass through
- Exits 2 — block (the tool call does not execute)
- Emits JSON `{"decision": "block", "reason": "..."}` on stdout to block with a message (used by Stop hooks like ralph-stop.sh)

Wire new hooks in `settings.json.template` so they ship with `init.sh`. Project-specific hooks belong in the project's own `.claude/settings.json` and `.claude/hooks/`, not here.
