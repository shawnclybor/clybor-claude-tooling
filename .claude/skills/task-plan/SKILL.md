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

`docs/PRDs/<feature_slug>-plan.md` with this shape:

```markdown
# <Feature title> — Plan

**PRD:** [<feature_slug>](./<feature_slug>.md)

## Tasks

- [ ] **1.** [Task title]
  - **Touches:** [file paths or modules]
  - **Verifies:** [which PRD success criteria this advances]
  - **Notes:** [key constraints, dependencies on other tasks]

- [ ] **2.** ...

## Parallelizable groups

Tasks 1, 3, 5 are independent — can run in parallel.
Task 7 depends on Task 4 — must run after.

## Risks per task

| Task | Risk | Mitigation |
|---|---|---|
| 4 | DB migration is online — if locking pattern is wrong, blocks writes | Test in staging first; run during low-traffic window |
```

## Sizing rules

Each task should pass these checks:

1. **One-pass completable** — a focused contributor can finish it in one sitting (≤ 2 hours of real work)
2. **Single responsibility** — it advances one concern; doesn't bundle unrelated changes
3. **Independent where possible** — if it can run in parallel with another task, it should
4. **Tied to a criterion** — every task advances at least one PRD success criterion; if it doesn't, ask why it's in the plan
5. **Testable in isolation** — there's a check (unit test, integration test, manual smoke) that confirms this task alone is done

If a task fails any of these, split it.

## Common decomposition patterns

| PRD shape | Plan shape |
|---|---|
| New feature | Schema → API → client → tests → docs |
| Refactor | Add new path → migrate callers in batches → remove old path |
| Integration | Contract / types → happy path → error paths → retries → observability |
| Bug fix | Reproduce → narrow → fix → regression test |
| Migration | Backup → write new state alongside old → verify equivalence → switch reads → drop old |

These are starting points, not formulas. The plan must match the actual work.

## Parallelizable groups

Mark groups of tasks that can run concurrently. The downstream `ralph-implement` skill uses this to spawn parallel work where safe.

A task is parallelizable with another if:
- Neither writes to the same file
- Neither depends on the output of the other
- They don't share a contended resource (DB row, external API rate limit)

## Pre-flight checklist

Before writing the plan:

1. Have I read the full PRD, not just the title?
2. Does every PRD success criterion appear as at least one task's `Verifies:` field?
3. Is every task one-pass completable?
4. Have I marked parallelizable groups explicitly?
5. Have I flagged task-level risks separately from PRD-level risks?
6. If a task is large, have I split it before adding to the plan?

## Anti-patterns

- One-line tasks ("write tests") that hide a day of work — split
- Mega-tasks ("implement auth") that span the whole feature — split
- Tasks that don't tie to any PRD criterion — either find the criterion or remove the task
- Sequential ordering when parallel would work — group parallelizable tasks
- Plans that re-state the PRD — the plan is a decomposition, not a restatement
