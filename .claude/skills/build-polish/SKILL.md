---
name: build-polish
description: "The final stage of a whole build, and the stage that owns done. Once the build's planned versions and increments are finished, build-polish runs the real thing rapidly until it matches its goldens, then marks the deliverable complete; build-evaluate is not run again. Phase 0 is a preflight gate: it writes the definition of done (the release standard, a named golden set with numeric floors, two independent witnesses, the end-user journey) and nothing runs until the owner confirms it. Then up to three rounds: one serialized run of the core function into a frozen snapshot; comparison against the goldens; parallel read-only subagents that check it and walk the user journey; an evidence-gated sequential-thinking checklist deciding whether each anomaly is really a problem; the smallest fix, under a KISS/YAGNI veto and code review. The end check stays small: real results, plus single mutation rows or sets whose output drives a fix. Triggers - polish the build, final polish, get it to done, is it done, /build polish."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, Skill, AskUserQuestion, mcp__sequential-thinking__sequentialthinking
user-invocable: true
argument-hint: "<slug>"
---

# Build Polish

**Get to done.** While a build is being built, each version or increment gets its own
build-evaluate verdict — and none of those verdicts is the deliverable being done. The Yellow
Sheet went through 1.0 to 1.4 that way, evaluated many times and never done. Polish is the end of
the build: the owner defines done once, the real thing runs until it matches, and polish marks the
deliverable complete.

Three measured facts shape it.

- **45% of all must-fix findings** across 21 review rounds sat in text the previous round's repair
  wrote (`mem:gate_philosophy`). Polish reviews by rule and by harness, not by panel.
- **Exit codes and counts have called builds done that were not** — a green renderer over an empty
  tab, "workbook written" over 0 of 70 money cells, a floor 40 below its count. The done check
  reads the artifact, never the exit code.
- **Two drivers on one shared tree cost a whole measurement round** on 2026-09-10 — the reason for
  the one-run cap below.

## Where it sits

```text
while the build is being built, per version or increment:
    prd → probe → validate → plan → estimate → execute → evaluate
at the end of the build, once:
    POLISH → the deliverable is done
```

Polish replaces any further evaluate. It never runs the full suite or the full mutation table:
those did their job while the versions were built. It checks the finished thing against real
examples, and uses single mutation rows, or small sets of them, where their output drives a fix.

## Preconditions — REFUSE if unmet

- The owner has called the build at its end: no planned version or increment is left to execute.
- Polish runs on the last version's slug: `.claude/PRPs/{slug}/prd.md` and `state.json` exist, and
  the last increment's build-execute reported `success`.
- If `probes/run.sh` exists, it was re-run this session with 0 MISMATCH.
- The build names a core-function command and at least one golden with an oracle. With no golden
  there is nothing to polish against; that is build work — stop and say so.

## Fixed caps

Three rounds. Stagnation — two rounds in which no ledger row left OPEN — runs `five-whys`, then
stops. Three FAILs on one target stop the loop as a process defect (Hard Rule 9). No clock, ever
(Hard Rule 8). One run of the core function at a time.

## What the owner sees

| When | The owner sees | The owner is asked |
|---|---|---|
| Start | The done definition, pre-filled from the release standard, the last PRD, state and every version's evaluate | Once: Confirm / Adjust / Stop |
| Rounds | Nothing. No status reports at round boundaries | Only for a target change, a scope call, or a fact only a human holds — after the repo was searched for it (Hard Rules 4 and 11) |
| End | The deliverable marked complete, or stopped, and the report (§ Close) | Only the questions the ledger could not settle |


## Where the rest lives (read before running the matching phase)

| When you are about to... | Read |
|---|---|
| Define DONE (Phase 0 preflight gate), load known state (Phase 1), or run a round | `references/phases-0-1-round.md` |
| Use the gated checklist (triage, done) or dispatch reviewers | `references/checklist-and-reviewers.md` |
| Write the ledger or audit, use the Journey walker / Golden reader prompts, the worked example, or the Guidelines | `references/ledger-prompts-example.md` |

Phase 0 is mandatory before any round. Do not start without reading `references/phases-0-1-round.md`.
