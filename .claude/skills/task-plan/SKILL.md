---
name: task-plan
description: Decompose a PRD into a sequenced checkbox task list. Each task is small enough to complete in one focused pass and tied to one or more PRD success criteria. Use after the PRD is accepted and before implementation begins. Triggers — "plan from the PRD", "break this into tasks", "task list for [feature]", "decompose [PRD]", "give me a plan".
---

# Task Plan

Turn an accepted PRD into a flat, sequenced task list with checkboxes. The plan is the contract between the PRD and the implementation. Tasks too big = invisible progress; tasks too small = ceremonial overhead. Aim for one-focused-pass per task.

## When to use

- Right after a PRD is written and accepted
- When picking up an existing PRD that lacks a plan
- When re-planning after a Stage 6 evaluation surfaces structural issues

## Input

- **`prd_path`** — path to the PRD (e.g., `docs/PRDs/oauth-token-refresh.md`)

## Output

`docs/PRDs/<feature_slug>-plan.md`, copied from `templates/plan-template.md` and filled in. Sections:

1. **Tasks** — checkbox list with `Touches`, `Verifies`, `Check`, `Notes` per task
2. **Parallelizable groups** — which tasks can run concurrently
3. **Risks per task**

## Sizing rules

Each task should pass these checks:

1. **One-pass completable** — ≤ 2 hours of focused work
2. **Single responsibility** — advances one concern; does not bundle unrelated changes
3. **Independent where possible** — runs in parallel with siblings when safe
4. **Tied to a criterion** — advances at least one PRD success criterion
5. **Testable in isolation** — there is a check (unit test, integration test, smoke) that confirms this task alone is done

If a task fails any of these, split it.

## Parallelizable-group analysis

After the flat task list is drafted, invoke `task-distributor` to produce the parallelizable-group section. It applies the safety rules:

- No shared write target between parallel tasks
- No read-after-write dependencies between parallel tasks
- No contended shared resources (DB row, rate limit, file lock)

Take the `task-distributor` output verbatim into the plan's "Parallelizable groups" section. The `ralph-implement` skill at Stage 4 reads this section to spawn parallel work.

## Common decomposition patterns

| PRD shape | Plan shape |
|---|---|
| New feature | Schema → API → client → tests → docs |
| Refactor | Add new path → migrate callers in batches → remove old path |
| Integration | Contract / types → happy path → error paths → retries → observability |
| Bug fix | Reproduce → narrow → fix → regression test |
| Migration | Backup → write new state alongside old → verify equivalence → switch reads → drop old |

Starting points, not formulas. The plan must match the actual work.

## Stage-pipeline plans

When the work is a fixed sequence of steps with a human review gate between each (research → draft → final; data → eval → report), the plan scaffolds the execution structure instead of only listing tasks:

- Copy `templates/stage-pipeline/` from the master tooling repo to where the work lives; rename/renumber stages (`01-`, `02-` — zero-padded prefixes encode execution order; reordering = renaming folders).
- Each stage folder carries a `CONTEXT.md` contract — Inputs (source / where / why), Process (numbered steps), Outputs (artifact / location / format) — under 80 lines, plus an `output/` folder for the handoff artifact.
- A stage reads ONLY its declared Inputs (previous stage's `output/` + named references). Everything else is do-not-load.
- Tasks then map 1:1 to stages; each stage's DONE check = its Outputs exist and satisfy the contract. The human inspects `output/` before the next stage runs — every output is an edit surface.

## Pre-flight checklist

Before writing the plan:

1. Have I read the full PRD, not just the title?
2. Does every PRD success criterion appear as at least one task's `Verifies:` field?
3. Is every task one-pass completable?
4. Has `task-distributor` run on the flat task list to produce parallelizable groups?
5. Have I flagged task-level risks separately from PRD-level risks?
6. If a task is large, have I split it before adding to the plan?

## Anti-patterns

- One-line tasks ("write tests") that hide a day of work — split
- Mega-tasks ("implement auth") that span the whole feature — split
- Tasks that do not tie to any PRD criterion — either find the criterion or remove the task
- Hand-rolled parallel grouping — let `task-distributor` do it; the safety rules are easy to skip when humans estimate
- Plans that re-state the PRD — the plan is a decomposition, not a restatement
