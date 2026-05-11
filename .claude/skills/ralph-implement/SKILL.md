---
name: ralph-implement
description: Implement a task list with the ralph-loop pattern — run, score, fix, re-run. Generic code-implementation loop (separate from skill-validator which targets skills). Use when executing a plan from task-plan. Triggers — "implement the plan", "ralph the implementation", "work the task list", "iterate on [feature]", "run the implementation loop". Two-strike rule on retries; escalates to five-whys on repeated failure rather than masking with a third blind retry.
---

# Ralph Implement

Continuous-iteration implementation loop. For each task in a plan, implement the smallest change that addresses it, run the task-level checks, and iterate on failure. Stop cleanly when the budget is exhausted — do not paper over.

## When to use

- Executing a task list produced by `task-plan`
- Migrating a refactor through a sequence of small changes
- Driving any code work where each step has a deterministic pass/fail check

## When NOT to use

- Validating a skill against a target repo — use `skill-validator` (skills-specific ralph)
- Pure exploration where you don't have task-level checks defined
- Tasks already in a CI pipeline that handles iteration

## Inputs

- **`plan_path`** — path to the task plan (e.g., `docs/PRDs/<slug>-plan.md`)
- **`task_checks`** — per-task command(s) that verify the task is done. Format: `<task_id>: <command>`. Examples: `pytest tests/auth/`, `tsc --noEmit`, `npm run lint -- --max-warnings 0`.
- **`budget`** — max retries per task (default 3) and max minutes per task (default 30). Hard cap.

## The loop (per task)

```
for task in plan.unchecked_tasks():
    retries = 0
    while retries < BUDGET.max_retries:
        implement(task)               # smallest change that addresses the task
        result = run(task_checks[task.id])
        if result.passed:
            mark_complete(task)
            log(task, result)
            break
        retries += 1
        diagnose(result)              # what specifically failed?
        if same_failure_mode_as_last_retry(result):
            invoke five-whys
            stop_task()
            escalate(task)
    else:
        stop_task()
        escalate(task)
```

## Two-strike rule (mandatory)

If a task fails twice with the **same failure mode** (same error class, same root cause signal), STOP. Do not retry blindly a third time.

Instead:
1. Invoke the `five-whys` skill
2. Surface the root cause to the user
3. Wait for direction — fix governance, adjust the plan, or accept the failure

A blind third retry that "works" is worse than a clean failure — it masks the bug and corrupts the documented behavior.

## Parallelizable tasks

If the plan marks a group of tasks as parallelizable, run them concurrently — spawn separate Agent invocations, each with its own scope. Collect results. A failure in one parallel task does NOT auto-stop the others, but it gates the next plan section.

## Per-task logging

Each task run writes to `.ralph-implement/<feature_slug>/task-<N>.json`:

```json
{
  "task_id": "<N>",
  "title": "<task title>",
  "started_at": "<iso8601>",
  "ended_at": "<iso8601>",
  "retries": <int>,
  "passed": <bool>,
  "final_check": "<command>",
  "final_result": "<stdout/stderr summary>",
  "failure_modes": ["<deduped error class>", ...],
  "escalated": <bool>
}
```

The log file IS the audit trail. A loop with no log is not a verified loop.

## Pre-flight checklist

Before starting the loop:

1. Does the plan exist and have unchecked tasks?
2. Does every task have a corresponding check command in `task_checks`?
3. Is the workspace clean (no uncommitted unrelated changes)?
4. Have I read the PRD success criteria and confirmed the plan covers them?
5. Is the budget set? (Default 3 retries × 30 min is fine for most tasks.)

## Pass / fail summary

The loop closes when:
- Every plan task is checked complete
- Every task's check command returned pass on the final retry

The loop stops without closing when:
- Any task exhausts its retry budget
- Two-strike triggers and the user halts after `five-whys`
- The user explicitly stops

A stopped loop still produces useful output: the partial completion log + the failing task report.

## Relationship to other skills

- **task-plan** — the loop's input
- **five-whys** — invoked on every two-strike
- **quality-review** — runs at the end of the parent dev-loop (Stage 6) against the implementation; not invoked inside ralph-implement itself
- **skill-validator** — sibling skill; specialized version of this loop for validating skills

## Anti-patterns

- **Patching past two-strike** — the most common failure of ralph loops. If the same error recurs, the next retry will almost always produce the same error in a slightly different form. Stop and diagnose.
- **Implementing past the task scope** — each task does one thing. If you find yourself touching files outside the task's `Touches:` list, you're either splitting wrong or scope-creeping; stop and update the plan.
- **Skipping the check** — if a task says "complete" without the check passing, it's not complete. The check is the gate.
- **Silent escalation** — escalations go to the user explicitly. Never quietly skip a task and continue.
