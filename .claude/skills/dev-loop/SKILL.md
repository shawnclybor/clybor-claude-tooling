---
name: dev-loop
description: Thin orchestrator for the 7-stage development workflow. Sequences PRD → plan → validate → ralph → verify → evaluate → iterate by invoking the per-stage skills in order, with explicit pass gates between stages. Use when starting a new feature or non-trivial change that warrants the full cycle. Triggers — "start a dev loop", "run the full development loop", "new feature with the full loop", "ralph this through to done", "PRD then plan then ship".
---

# Dev Loop (orchestrator)

Drives a feature from a one-paragraph problem statement to a verified, evaluated deliverable. This skill does NOT implement the stages — it sequences them by invoking the per-stage skills. Each stage has an explicit pass gate; a failure does not advance.

## Stages

| # | Stage | Skill invoked | Agents invoked (where applicable) | Pass gate |
|---|---|---|---|---|
| 1 | PRD | `prd-writer` | `research-analyst`, `search-specialist` (for source-bound questions) | PRD has binary success criteria, scope, dependencies, risks |
| 2 | Plan | `task-plan` | `task-distributor` (for parallelizable-group analysis) | Every PRD criterion is covered by ≥1 task; tasks are one-pass completable |
| 3 | Validate | `quality-review` (on PRD + plan) | `simplifier`, `adversarial-reviewer`, `chaos-engineer` (parallel via `multi-agent-coordinator`); `knowledge-synthesizer` for Round 2 | No Critical findings; High findings addressed or accepted |
| 4 | Implement | `ralph-implement` | `multi-agent-coordinator` (parallel task groups), `debugger` (two-strike investigation), `error-coordinator` (correlated failures), `code-reviewer` (per-task quality gate) | Every task check returns green within retry budget |
| 5 | Verify | `verify` | `code-reviewer` (final pre-evaluation pass) | Every PRD success criterion's check returns green |
| 6 | Evaluate | `quality-review` (on implementation) | `simplifier`, `adversarial-reviewer`, `chaos-engineer`, `code-reviewer`, `security-auditor`; `knowledge-synthesizer` combines findings | No Critical findings; High findings addressed or accepted |
| 7 | Iterate or close | (self) | `performance-monitor` (if N outer loops have run) | All gates pass → close with a short closure note; else return to Stage 4 |

## Stage agents — who runs and why

**Coordination layer.** `workflow-orchestrator` owns stage sequencing and gate enforcement. `multi-agent-coordinator` owns parallel spawns inside stages (Stage 3, Stage 4 parallel groups, Stage 6). `error-coordinator` handles correlated failures across parallel agents. `knowledge-synthesizer` combines outputs at Stage 3 and Stage 6 instead of hand-rolled synthesis.

**Reasoning layer.** Stages 3 and 6 invoke the full quality team (`simplifier`, `adversarial-reviewer`, `chaos-engineer`). Stage 6 additionally invokes `code-reviewer` and `security-auditor` because the artifact is now implementation, not a plan.

**Diagnostic layer.** `debugger` is invoked inside Stage 4 when `ralph-implement` hits a two-strike. `five-whys` is the protocol; `debugger` is the executor.

**Source layer.** Stage 1 can invoke `research-analyst` for source-bound questions in the problem statement and `search-specialist` for quick precision lookups. `evidence-auditor` runs on the PRD draft if it cites external claims.

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

1. **Stages run in order.** No skipping. If Stage N fails its gate, do not proceed to Stage N+1.
2. **Gate failures iterate the failing stage**, not earlier stages. If Stage 5 fails, return to Stage 4 with a narrower task list.
3. **Stage 7 has a hard cap.** Default 3 outer loops. If 3 outer loops do not close, stop and report — the work is bigger than the PRD predicted; re-PRD or descope.
4. **Each invocation gets its own log.** Stage logs accumulate in `.dev-loop/<feature_slug>/stage-<N>.json`. The log is the audit trail.

## Stage-by-stage gates

**Stage 1 — PRD gate.** Criteria are binary (yes/no answerable, not vibes). Out-of-scope is explicit. Risks are specific failure modes, not generic phrases.

**Stage 2 — Plan gate.** Every PRD criterion appears in at least one task's `Verifies:` field. Every task is one-pass completable. Parallelizable groups are marked (by `task-distributor`).

**Stage 3 — Validate gate.** `quality-review` returns. No Critical findings. High findings either addressed in the plan or explicitly accepted with rationale logged.

**Stage 4 — Implement gate.** `ralph-implement` returns. Every task check returns green. No two-strike escalations left unresolved (`debugger` investigated; `error-coordinator` correlated where applicable).

**Stage 5 — Verify gate.** `verify` returns PASS (not PARTIAL, not FAIL). Every PRD success criterion has a corresponding check that returned green.

**Stage 6 — Evaluate gate.** `quality-review` returns on the implementation. No Critical findings. High findings addressed or accepted.

**Stage 7 — Close.** Write `docs/PRDs/<feature_slug>-closure.md`: what shipped, what was deferred, follow-up tasks if any.

## Templates

PRD and plan templates ship at `templates/prd-template.md` and `templates/plan-template.md`. The `prd-writer` and `task-plan` skills copy from those.

## Pre-flight checklist

Before invoking the orchestrator:

1. Is `feature_slug` set and kebab-cased?
2. Do I have at least a one-paragraph problem statement?
3. Is `docs/PRDs/` writable?
4. Is the workspace clean enough to start? (No unrelated WIP that ralph would clobber.)

## When to halt

- Stage 1 reveals the problem statement is malformed
- Stage 3 surfaces a Critical that says "this should not be built" — halt and discuss
- Stage 4 hits a two-strike that reveals scope creep — halt and re-PRD
- Stage 5 PARTIAL because a criterion cannot be checked — halt and decide
- Outer iteration budget exhausted — halt and report
- `performance-monitor` flags that the loop is repeatedly hitting the same hotspot — halt and tune

## Anti-patterns

- **Skipping stages.** Each gate exists because the previous stage missed a real failure mode.
- **Treating findings as advisory.** Each gate is binary.
- **Looping forever in Stage 7.** Each outer iteration must measurably reduce open findings; if it does not, stop.
- **Inline implementation.** This orchestrator does not write code or files outside `.dev-loop/`. It invokes other skills and agents.
