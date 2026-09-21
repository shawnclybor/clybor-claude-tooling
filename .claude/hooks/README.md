# Hooks

Shell or Python scripts triggered by Claude Code events (PreToolUse, PostToolUse, Stop, SessionStart). Wired in `.claude/settings.json`.

## Two classes of hook, two fail postures

**Quality hooks** (this directory, hand-maintained) resolve their script and, if
it is missing, print a note and `exit 0` — "fails open by design". Right for a
style reminder: a missing KISS nudge should never block work.

**Guards** (`vendor/`, upstream copies) launch through `guard-resolve.sh`, which
`exit 2`s — blocking the tool call — when the runtime or the script is missing.
A security hook that silently stops running is worse than no security hook,
because the absence is not self-announcing.

That posture applies to the *launch*. It does not extend inside `guard-pack.js`,
which catches a throwing guard, logs it, skips to the next, and emits `{}`
(= allow) from its top-level catch. That is upstream's design and the file is
byte-pinned against upstream tests. Per CLAUDE.md Hard Rule 18, a hook is a
backstop, never the sole gate.

## Bundled

- **guard-resolve.sh** — fail-closed launcher for the `vendor/` guards. Takes
  `<runtime> <repo-relative-script>`, resolves via `CLAUDE_PROJECT_DIR` or a
  parent walk, and exits 2 with a `GUARD BLOCKED:` reason if either is missing.
- **availability-claim-validator.py** — PreToolUse on Write|Edit. Fires when text asserts something is blocked, unreachable, missing, or owed by someone else *without* probe evidence nearby. An unavailability claim is a finding and must carry the search that produced it. Ships `REPORT_ONLY = True`; flip it off once you have backtested the false-positive rate on your corpus. Override consciously with `<!-- probe-ok: reason -->` or by writing `NOT PROBED` beside the claim — which is the compliant form.
- **compact-recovery.sh** — Stop hook with `compact` matcher. Re-injects `ROADMAP.md` (if present) and recent git history after context-window compaction.
- **kiss-yagni-reminder.py** — PreToolUse on Write|Edit. Prints a one-line KISS / YAGNI checkpoint to stderr when writing code files. Reminds, does not block.
- **ralph-stop.sh** — Stop hook for the Ralph Loop. Reads `.ralph-loop/state.json`, scans the session transcript for the completion-promise, decides whether to allow exit or block + re-feed the prompt. Implements the canonical Ralph Wiggum technique.

## Vendored (see `vendor/README.md` for provenance, licenses, config)

- **vendor/guard-pack/** — PreToolUse guard: dangerous commands, secrets, git safety, test tampering, case-collision `rm`, subagent spawn cap. config-guard is disabled via `CONFIG_GUARD_ALLOW=true`.
- **vendor/smart-approve/** — PreToolUse on Bash. Decomposes compound commands so `permissions.allow` cannot be bypassed with `&&`.
- **vendor/prompt-injection-defender/** — PostToolUse scan of Read/WebFetch/Bash/Grep/Task output for indirect prompt injection. Warn-only, so it fails open.
- **vendor/dead-rules-audit/** — tallies which CLAUDE.md rules are followed vs ignored.
- **vendor/format-code/** — ruff + prettier after Write/Edit. Inert until `ruff` and `prettier` are installed.

## Smoke tests

Run from the repo root after any change to `vendor/` or the hook wiring:

```bash
export HOOK_SAFETY_LEVEL=high CONFIG_GUARD_ALLOW=true
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf ~"}}' \
  | node .claude/hooks/vendor/guard-pack/guard-pack.js          # expect: deny
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
  | node .claude/hooks/vendor/guard-pack/guard-pack.js          # expect: {}
echo '{}' | bash .claude/hooks/guard-resolve.sh node .claude/hooks/vendor/nope.js
                                                                # expect: exit 2
```

A guard that throws is swallowed and logged, never surfaced. Since that is the
one failure mode the fail-closed launcher cannot catch, check for it directly:

```bash
grep -h '"level":"ERROR"' ~/.claude/hooks-logs/*.jsonl | tail -20
```

Empty is the expected result. Anything there is a guard that silently stopped
guarding — treat a hit as a live incident, not a log entry.

`scripts/check_hook_wiring.py` currently reports every hook in this repo as
UNVERIFIED — its path parser knows `"$R"/path` and `"$CLAUDE_PROJECT_DIR"/path`
but not the `h=path; …; exec` idiom every command here uses. It refuses to pass
what it cannot see, which is correct; it just means the smoke tests above are
the real verification until the parser learns that shape.

## Adding hooks

A hook is a script that reads JSON from stdin (the tool call payload) and either:

- Exits 0 — allow / pass through
- Exits 2 — block (the tool call does not execute)
- Emits JSON `{"decision": "block", "reason": "..."}` on stdout to block with a message (used by Stop hooks like ralph-stop.sh)

Wire new hooks in `settings.json.template` so they ship with `init.sh`. Project-specific hooks belong in the project's own `.claude/settings.json` and `.claude/hooks/`, not here.
