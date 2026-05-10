# KISS / YAGNI Principles

Always-on. Read on every non-trivial request.

## The Core

**KISS** — Keep It Simple, Stupid. Pick the simplest mechanism that solves the actual problem. Complexity earns its place by paying for itself in observed value, not hypothetical value.

**YAGNI** — You Aren't Gonna Need It. Don't build for futures that haven't arrived. Don't generalize until there's a second use case.

## Operational rules

### Reuse before you write

Before creating any new skill, command, agent, or migration, search existing assets for something that already does the job. Extend or compose rather than duplicate.

### Tool-audit gate

Before `npm install`, `pip install`, or writing generation code, ask: does a CLI tool already do this in one line?

- `pandoc` — markdown ↔ docx / pdf / html
- `ffmpeg` — audio / video transcoding
- `jq` — JSON transformation
- `convert` / ImageMagick — image manipulation
- `rsync` — file transfer
- `soffice` / LibreOffice — Office format conversion

If yes, use the CLI. Only reach for a library when the CLI genuinely can't express what you need.

### Pick the right default, don't add a config

"Make it a config option" is almost always the wrong answer. Pick the right default and ship it. Configs are technical debt — every option is a maintenance surface, a documentation burden, and a future support question.

### Agent prompts under 250 words

Over-specified prompts waste context and constrain the agent's judgment. Provide what's needed, not everything you know.

### Targeted reads over full-file reads

Never read an entire file > 100 lines without `offset` / `limit`. Use grep / search to find the section, then read with bounded ranges.

## Two Strikes Rule

Same op fails twice → STOP. Do NOT retry blindly a third time.

When triggered:
1. Stop the retry loop
2. Invoke the `five-whys` skill
3. Search the relevant rule file's Known Issues
4. Update governance with the failure mode and the fix

A blind third retry that "works" is worse than a clean failure — it masks the bug and corrupts the documented behavior.

## Blocker Protocol

Hit a blocker → stop and report. Do NOT silently work around it.

A blocker is:
- A required tool / API / credential is unavailable
- A required input is ambiguous or missing
- A pre-flight check failed and you don't know how to make it pass
- A retry budget is exhausted

When triggered:
1. Stop
2. Explain what was tried and what failed
3. Ask the user to confirm next steps before proceeding with any workaround

Silent workarounds (skipping a step, fabricating an input, picking a default) are how silent corruption ships.

## Cascade Re-Scope

When a fix produces a NEW error class (deeper layer than the one you were fixing), STOP. Treat it as a new incident, not a continuation. Re-read the user's original request before continuing — if scope has 10x'd, escalate or stop. Honor Two Strikes per layer, not per session.

## Honor-System Gates Fail — Codify as Scripts

When a rule has a deterministic check, write a script that exits non-zero on violation. Run it before the gating action. Treat the script as the enforcing gate; the prose rule is the pointer to the script. When a new honor-system gate fails twice in real session usage, write the script.
