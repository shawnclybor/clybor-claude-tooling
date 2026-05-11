---
name: dev-loop
description: Orchestrates a 7-stage development workflow — PRD → plan → validate → ralph loop → verify → evaluate → iterate. Use when starting a new feature or non-trivial change that warrants the full cycle. Triggers — "start a dev loop", "run the development loop", "new feature", "build X with the full loop", "ralph this through to done", "PRD then plan". Stops at any stage on a clear failure rather than masking it. Designed to be invoked as a single command and produce a final artifact only after all gates pass.
---

# Dev Loop — PRD → Plan → Validate → Ralph → Verify → Evaluate → Iterate

End-to-end development workflow that runs from a one-paragraph problem statement to a verified, evaluated deliverable. Each stage has explicit pass criteria. A stage that fails the criteria does not advance — the loop iterates that stage, escalates, or stops.

The loop is opinionated about order: PRD before plan, plan before code, validation before ralph, verification before evaluation. Skipping a stage is the most common way for the loop to ship the wrong thing.

## When to use

- A new feature with non-obvious design space (multiple valid approaches)
- A refactor that touches more than three files or crosses a module boundary
- An integration with an external system where the contract matters
- Any change where "ship it" without a quality gate would be a coin flip

## When NOT to use

- One-line fixes, typos, dependency bumps
- Spike work where the goal is to learn, not to ship
- Tasks where a single skill already does the job (use that skill directly)

## The seven stages

### Stage 1 — PRD

Define what is being built and why. Output: `docs/PRDs/<feature-slug>.md`.

Must include: problem statement, success criteria (binary), in-scope, out-of-scope, dependencies, risks. The success criteria become the verification gates in Stage 5.

If the user provides only a vague request, ask for the problem statement and success criteria first. Do not infer them.

### Stage 2 — Plan

Break the PRD into a sequenced task list. Output: `docs/PRDs/<feature-slug>-plan.md` with checkbox tasks.

Each task should be:
- Small enough to complete in one focused pass
- Independent where possible (so Stage 4 can parallelize)
- Tied to one or more PRD success criteria

### Stage 3 — Validate the plan

Run `quality-review` against the PRD + plan. Spawns the simplifier, adversarial-reviewer, and chaos-engineer in parallel.

Gate: at least one Critical or High finding must be addressed before Stage 4, OR all three agents explicitly say the plan is sound. If the gate fails, return to Stage 2 with the findings; do not advance.

### Stage 4 — Ralph loop (implementation)

Execute the plan task-by-task with the ralph-loop pattern: run, score, fix, re-run.

For each task:
1. Implement the smallest change that addresses the task
2. Run any task-level checks (lint, type, unit test)
3. If checks fail, iterate up to N times (default N=3)
4. If still failing after N, stop and escalate. Do not paper over.

Two-strike rule applies: the same failure mode twice in a row → stop and invoke `five-whys`. A blind third retry is worse than a clean failure.

### Stage 5 — Verify

Run the deterministic checks: full test suite, build, lint, type check, smoke test, any integration tests.

Gate: every PRD success criterion has a corresponding check that returns green. If any criterion lacks a check, write one before claiming verified.

### Stage 6 — Evaluate

Run `quality-review` against the implementation. Different lens than Stage 3 — Stage 3 reviewed the plan; Stage 6 reviews the result.

Gate: no Critical findings. High findings must be either addressed or explicitly accepted with rationale logged.

### Stage 7 — Iterate or close

If Stages 5 or 6 surfaced fixable issues, return to Stage 4 with a narrower task list. Each iteration must measurably reduce the open finding count or the loop stops.

If all gates pass, the loop closes. Write a short closure note to `docs/PRDs/<feature-slug>-closure.md`: what shipped, what was deferred, follow-up tasks if any.

## Inputs

- **`feature_slug`** — kebab-case identifier used to name PRD, plan, and closure files
- **`problem_statement`** — what is being built and why, one paragraph
- **`success_criteria`** — binary list, derived in Stage 1 if not provided
- **`budget`** — optional caps on iteration count per stage (defaults: Stage 4 = 3 retries per task, Stage 7 = 3 outer loops)

## Outputs

- `docs/PRDs/<feature_slug>.md` — the PRD
- `docs/PRDs/<feature_slug>-plan.md` — the plan with checkbox status
- `docs/PRDs/<feature_slug>-closure.md` — the closure note
- The actual code and test changes from Stage 4
- A short final report: what passed, what was deferred, follow-ups

## Stage-by-stage anti-patterns

| Stage | Anti-pattern |
|---|---|
| 1 — PRD | Inferring success criteria. Writing "improve performance" instead of "P95 latency < 200ms" |
| 2 — Plan | Tasks that span the whole feature ("implement auth"). Break to one-pass-completable tasks. |
| 3 — Validate | Treating quality-review findings as advisory. The gate is "addressed or explicitly accepted." |
| 4 — Ralph | Patching past two-strike. If the same failure recurs, stop and run five-whys. |
| 5 — Verify | Hand-waving a green check. Every PRD criterion needs a corresponding automated check. |
| 6 — Evaluate | Skipping the second review because Stage 3 passed. Plan-soundness ≠ implementation-soundness. |
| 7 — Iterate | Looping forever. Each outer iteration must measurably reduce the open finding count. |

## Logging

Every stage writes to `.dev-loop/<feature_slug>/stage-<N>.json`:
- Stage name, start/end timestamps
- Inputs consumed
- Outputs produced
- Pass/fail verdict with rationale
- Any escalations or stage-back transitions

The log is the audit trail. A loop with no log is not a verified loop.

## Pass / fail summary

The loop closes successfully when:
- Every PRD success criterion is verified in Stage 5
- Stage 6 surfaces no Critical findings
- Stage 7 either confirms close or runs at most `outer_budget` iterations

The loop fails (and stops without closing) when:
- A stage exhausts its retry budget without improvement
- A five-whys escalation reveals a scope mismatch that requires PRD changes
- The user explicitly halts the loop

A failed loop still produces useful artifacts: the PRD, the partial plan, the audit log. Treat these as the rationale for the next attempt.

## Relationship to other skills

- **quality-review** — invoked at Stage 3 and Stage 6. Same skill, different inputs.
- **skill-validator** — a specialization of this loop for skills. If validating a skill against a target repo, prefer `skill-validator` over this skill.
- **five-whys** — invoked on every two-strike inside Stage 4.
- **insight-crystallizer** — invoked at Stage 7 if the loop produced a non-obvious finding worth keeping.
- **insight-promotion** — invoked when a Stage 6 finding reveals a governance gap.
