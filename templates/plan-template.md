# {{FEATURE_TITLE}} — Plan

**PRD:** [`{{FEATURE_SLUG}}.md`](./{{FEATURE_SLUG}}.md)

## Tasks

- [ ] **1.** [Task title]
  - **Touches:** [file paths or modules]
  - **Verifies:** [which PRD success criteria this advances]
  - **Check:** [the command or test that confirms this task is done]
  - **Notes:** [key constraints, dependencies on other tasks]

- [ ] **2.** [Task title]
  - **Touches:**
  - **Verifies:**
  - **Check:**
  - **Notes:**

## Parallelizable groups

Identify groups that can run concurrently without contended writes or output dependencies. The `task-distributor` agent produces this analysis; the `ralph-implement` skill consumes it.

- **Group A (parallel):** tasks 1, 3, 5
- **Group B (parallel, after A):** tasks 2, 4
- **Serial-only:** tasks 6, 7

## Risks per task

| Task | Risk | Mitigation |
|---|---|---|
| [N] | [Specific failure mode] | [How it is prevented or handled] |

## Estimated effort

Produced by the `build-estimate` skill, never typed. Write the spec (tasks by kind and status, fixed
gates, process profile, calendar with real holidays, target date), run
`python3 .claude/skills/build-estimate/estimate.py project <spec>`, and paste the full output here —
including the `rate per task unit … [MEASURED|ASSUMED]` line and the *assumptions carried* block.
Re-run and replace whenever tasks land or the target moves; date each paste. After the build passes
evaluation, `estimate.py calibrate` with the measured actuals and promote the ledger.

{estimate.py output, dated}

---

**How to use:** copy this file to `docs/PRDs/<feature-slug>-plan.md` and fill it in. The `task-plan` skill produces this from a PRD; `ralph-implement` consumes it at Stage 4 of the dev loop.
