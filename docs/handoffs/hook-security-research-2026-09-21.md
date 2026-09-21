---
type: handoff
title: "clybor-claude-tooling — hook security exposures, research brief"
resource: "clybor-claude-tooling@20cd780"
updated: 2026-09-21
status: current
output_type: Infra-health
schema: okf-adapted-v0.1
---

# Hook security exposures — research brief

Not a task handoff. There are no AA Tasks behind this and no canonical Notion
Project, which is why `infra-health-handoff` was not used to produce it — that
skill refuses both conditions by design. This is a research brief: four open
questions, the evidence already gathered, and the dead ends not worth re-walking.

## Paste this into a fresh session

---

Research four security exposures in the hook system at `~/gits/clybor-claude-tooling`.
For each: establish how serious it actually is, with evidence, then propose a fix.
Do not implement anything. Report and stop.

Read first: `.claude/hooks/README.md` and `.claude/hooks/vendor/README.md` — they
carry the measurements behind everything below. Commits `ea77f59`, `8a0388d`,
`86c260d`, `04d3ad5`, `20cd780` are the full history.

Context: five hooks were vendored 2026-09-21 (guard-pack, smart-approve,
prompt-injection-defender, dead-rules-audit, format-code). **None is armed
anywhere yet** — this is a template change only, so nothing is currently exposed.
The point is to decide what to fix BEFORE arming.

**1. Untrusted content in, warn-only scanner.**
`vendor/prompt-injection-defender/` is PostToolUse and can only warn — by the time
it runs, the tool already executed. This workflow ingests a lot of untrusted text:
scraped pages, meeting transcripts, client email and matter files, web fetches. Is
warn-only adequate, and what would a blocking control look like given PostToolUse
cannot un-run a tool? Consider whether the defensible control gates the *next*
call rather than the current one. Quantify how much untrusted content actually
reaches these sessions before recommending a build.

**2. Guards fail open — three independent paths.**
`guard-pack.js` catches a throwing guard, logs it, and emits `{}` (allow); its
top-level catch does the same; and `timeout: 5` on both guard entries means a
timed-out hook is treated as failed, which Claude Code allows. That timeout is not
optional — `vendor/guard-pack/lib/protect-secrets.js` backtracks catastrophically
on long commands. Bisected on a real 4,159-char heredoc: 2,000 chars 60 ms, 2,500
chars 3,036 ms, 3,000 chars no return in 15 s. How often would this fire in
practice? Is the ReDoS worth an upstream PR or a local fork? Is there a
fail-closed design that does not risk freezing sessions?

**3. Python is allow-listed.**
`Bash(python3:*)` means arbitrary code execution with no prompt and no guard.
Accepted deliberately (commit `20cd780`) because `Bash(python3 -)` was already in
`~/.claude/settings.json` from an old "always allow" click, making a gate on `-c`
alone decoration. What is the real severity given the threat model is prompt
injection rather than Claude erring, and what control would actually reduce it?
Rank it against 1, 2 and 4 rather than treating it alone.

**4. Configuration drift.**
"Always allow" writes a permanent rule to a settings file with no record of when or
why, and `smart_approve` merges global, project and project-local layers. Live
instance: `Bash(python3 -)` sat in the global file and silently determined the
outcome of item 3 months later. Can this be made auditable — a diff, a gate, a
periodic review? Does the same drift affect `deny` rules and
`.claude/settings.local.json`?

**Two dead ends already walked. Do not re-walk them.**

- **Do not propose extracting interpreter payloads and re-scanning them.** Tested:
  patterns anchor at command start, so `import os; os.system('rm -rf ~')` passes
  even after extraction, and the next wrapper defeats whatever is added —
  `shutil.rmtree` carries no shell string, then `exec()`, then base64. A regex
  guard over an interpreter is unwinnable. `HOOK_SAFETY_LEVEL=strict` changes
  nothing; it is structural, not a tuning knob.
- **Do not conclude a slow replay is a hang without instrumenting it.** A
  full-corpus run was killed twice as "pathological" when the guards measure ~10 ms
  per call. The instrumented version found the real defect in 40 seconds.

Measurement corpus if you need it: 546 session transcripts over 30 days yield
27,992 real Bash commands, extracted from `~/.claude/projects/**/*.jsonl` by
pulling `tool_use` entries where `name == "Bash"`. Rebuild the harness rather than
trusting `/tmp/replay/`, which does not survive.

The severity ranking is the deliverable, not a formality. Say which of the four you
would fix first and what you would leave alone — and be willing to conclude that
one of them does not need fixing.

---

## Provenance

Produced by the session that vendored the hooks, 2026-09-21. Every figure above was
measured in that session against the 27,992-command corpus, not estimated. The
`resource:` field points at the final commit rather than a Notion Project because
no canonical Project exists for this work; per `okf-profile`, omitting is honest
and a display name in that field would be silently wrong.
