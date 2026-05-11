---
name: dev-loop
description: Thin orchestrator for the 7-stage development workflow. Sequences PRD → plan → validate → ralph → verify → evaluate → iterate by invoking the per-stage skills in order, with explicit pass gates between stages. Use when starting a new feature or non-trivial change that warrants the full cycle. Triggers — "start a dev loop", "run the full development loop", "new feature with the full loop", "ralph this through to done", "PRD then plan then ship".
---

# Dev Loop (orchestrator)

Drives a feature from a one-paragraph problem statement to a verified, evaluated deliverable. This skill does NOT implement the stages — it sequences them by invoking the per-stage skills. Each stage has an explicit pass gate; a failure does not advance.

## Stages

| # | Stage | Skill invoked | Pass gate |
|---|---|---|---|
| 1 | PRD | `prd-writer` | PRD has binary success criteria, scope, dependencies, risks |
| 2 | Plan | `task-plan` | Every PRD criterion is covered by ≥1 task; tasks are one-pass completable |
| 3 | Validate | `quality-review` (on PRD + plan) | No Critical findings; High findings addressed or accepted |
| 4 | Implement | `ralph-implement` | Every task check returns green within retry budget |
| 5 | Verify | `verify` | Every PRD success criterion's check returns green |
| 6 | Evaluate | `quality-review` (on implementation) | No Critical findings; High findings addressed or accepted |
| 7 | Iterate or close | (self) | All gates pass → close with a short closure note; else return to Stage 4 with narrower scope |

## When to use

- A new feature with non-obvious design space (multiple valid approaches)
- A refactor that touches more than three files or crosses a module boundary
- Any change where shipping without a quality gate would be a coin flip

## When NOT to use

- One-line fixes, typos, dependency bumps
- Spike work where the goal is to learn, not ship
- Tasks where a single per-stage skill already does the job — invoke it directly

## Inputs

- **`feature_slug`** — kebab-case identifier
- **`problem_statement`** — one paragraph (passed to Stage 1)
- (optional) **`budget`** — caps per stage (default: Stage 4 = 3 retries / task; Stage 7 = 3 outer loops)

## Orchestration rules

1. **Stages run in order.** No skipping. If Stage N fails its gate, don't proceed to Stage N+1.
2. **Gate failures iterate the failing stage**, not earlier stages. If Stage 5 fails, return to Stage 4 with a narrower task list — don't rewrite the PRD unless the criterion itself was wrong.
3. **Stage 7 has a hard cap.** Default 3 outer loops. If 3 outer loops don't close, stop and report — the work is bigger than the PRD predicted; re-PRD or descope.
4. **Each invocation gets its own log.** Stage logs accumulate in `.dev-loop/<feature_slug>/stage-<N>.json`. The log is the audit trail.

## Stage-by-stage gates

**Stage 1 — PRD gate.** Criteria are binary (yes/no answerable, not vibes). Out-of-scope is explicit. Risks are specific failure modes, not generic phrases.

**Stage 2 — Plan gate.** Every PRD criterion appears in at least one task's `Verifies:` field. Every task is one-pass completable (≤2 hours of focused work). Parallelizable groups are marked.

**Stage 3 — Validate gate.** `quality-review` returns. No Critical findings. High findings either addressed in the plan or explicitly accepted with rationale logged.

**Stage 4 — Implement gate.** `ralph-implement` returns. Every task check returns green. No two-strike escalations left unresolved.

**Stage 5 — Verify gate.** `verify` returns PASS (not PARTIAL, not FAIL). Every PRD success criterion has a corresponding check that returned green.

**Stage 6 — Evaluate gate.** `quality-review` returns on the implementation. No Critical findings. High findings addressed or accepted.

**Stage 7 — Close.** Write `docs/PRDs/<feature_slug>-closure.md`: what shipped, what was deferred, follow-up tasks if any.

## Pre-flight checklist

Before invoking the orchestrator:

1. Is `feature_slug` set and kebab-cased?
2. Do I have at least a one-paragraph problem statement?
3. Is `docs/PRDs/` writable?
4. Is the workspace clean enough to start? (No unrelated WIP that ralph would clobber.)

## When to halt

- Stage 1 reveals the problem statement is malformed — fix it before continuing
- Stage 3 surfaces a Critical that says "this shouldn't be built" — halt and discuss
- Stage 4 hits a two-strike five-whys that reveals scope creep — halt and re-PRD
- Stage 5 PARTIAL because a criterion can't be checked — halt and decide: write the check, reword the criterion, or strike it
- Outer iteration budget exhausted — halt and report

## Relationship to other skills

- **prd-writer**, **task-plan**, **ralph-implement**, **verify** — the four per-stage skills this orchestrator drives
- **quality-review** — invoked at Stage 3 (against plan) and Stage 6 (against implementation)
- **skill-validator** — specialization of ralph-implement for skills work; if the work is a skill, use skill-validator at Stage 4 instead of ralph-implement
- **five-whys** — invoked automatically inside `ralph-implement` on two-strikes; orchestrator never directly invokes it
- **insight-crystallizer** — optional at Stage 7 if the loop produced a non-obvious finding
- **insight-promotion** — invoke when a Stage 6 finding reveals a governance gap worth codifying

## Anti-patterns

- **Skipping stages "just this once."** Plan-soundness ≠ implementation-soundness; verify ≠ evaluate. Each stage exists because the previous one missed a real failure mode.
- **Treating findings as advisory.** Each gate is binary. If a gate fails, the stage iterates.
- **Looping forever in Stage 7.** Each outer iteration must measurably reduce open findings; if it doesn't, stop and re-PRD.
- **Inline implementation.** This orchestrator does not write code, run commands, or write files outside `.dev-loop/`. It invokes other skills that do.
