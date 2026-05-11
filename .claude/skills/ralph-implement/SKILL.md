---
name: ralph-implement
description: Implement a task list with the ralph-loop pattern — run, score, fix, re-run. Generic code-implementation loop (separate from skill-validator which targets skills). Use when executing a plan from task-plan. Triggers — "implement the plan", "ralph the implementation", "work the task list", "iterate on [feature]", "run the implementation loop". Two-strike rule on retries; escalates to `debugger` and `five-whys` on repeated failure rather than masking with a third blind retry.
---

# Ralph Implement

Continuous-iteration implementation loop. For each task in a plan, implement the smallest change that addresses it, run the task-level checks, and iterate on failure. Stop cleanly when the budget is exhausted.

## When to use

- Executing a task list produced by `task-plan`
- Migrating a refactor through a sequence of small changes
- Driving any code work where each step has a deterministic pass/fail check

## When NOT to use

- Validating a skill against a target repo — use `skill-validator`
- Pure exploration where no task-level checks are defined
- Tasks already in a CI pipeline that handles iteration

## Inputs

- **`plan_path`** — path to the task plan (e.g., `docs/PRDs/<slug>-plan.md`)
- **`task_checks`** — per-task command(s) that verify the task is done. Format: `<task_id>: <command>`.
- **`budget`** — max retries per task (default 3) and max minutes per task (default 30). Hard cap.

## The loop (per task)

```
for task in plan.unchecked_tasks():
    retries = 0
    while retries < BUDGET.max_retries:
        implement(task)               # smallest change that addresses the task
        result = run(task_checks[task.id])
        if result.passed:
            invoke `code-reviewer` against the changed files
            if code-reviewer returns no Critical: mark_complete(task)
            else: log and retry with code-reviewer findings as input
            break
        retries += 1
        if same_failure_mode_as_last_retry(result):
            invoke `debugger` for reproduction-first investigation
            if debugger surfaces a root cause: apply the minimal fix and retry once
            else: invoke `five-whys` and stop_task()
    else:
        stop_task() and escalate(task)
```

## Agent integration

- **`code-reviewer`** — runs on every completed task before marking done. Catches issues the task check itself does not (correctness, type safety, security, structure). A Critical finding sends the task back into the loop.
- **`debugger`** — invoked on the first same-failure-mode repeat (not after two strikes — earlier). Reproduction-first, evidence-driven hypothesis narrowing. Sister skill to `five-whys`.
- **`five-whys`** — invoked only if `debugger` cannot surface a root cause. The protocol path; halts the task.
- **`error-coordinator`** — invoked when 2+ parallel tasks fail in the same run. Correlates symptoms to find a shared cause (upstream dependency, shared config, environmental issue).
- **`multi-agent-coordinator`** — orchestrates parallel task spawns. Reads the plan's "Parallelizable groups" section and coordinates the concurrent runs with partial-failure handling.

## Parallel task groups

If the plan marks a group of tasks as parallelizable, `multi-agent-coordinator` spawns them concurrently. Each parallel task gets its own scope and own retry budget. A failure in one parallel task does NOT auto-stop the others — `error-coordinator` correlates failures to a shared cause before stopping the group.

## Two-strike rule (mandatory)

If a task fails twice with the **same failure mode**:

1. Invoke `debugger` for reproduction-first investigation
2. If `debugger` returns a root cause and minimal fix — apply and retry once
3. If `debugger` cannot reproduce or cannot find a root cause — invoke `five-whys`, surface to the user, halt the task

A blind third retry without `debugger` intervention is worse than a clean failure.

## Per-task logging

Each task run writes `.ralph-implement/<feature_slug>/task-<N>.json`:

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
  "code_reviewer_findings": "<summary or path>",
  "debugger_invoked": <bool>,
  "five_whys_invoked": <bool>,
  "escalated": <bool>
}
```

The log file is the audit trail.

## Pre-flight checklist

Before starting the loop:

1. Does the plan exist and have unchecked tasks?
2. Does every task have a corresponding check command in `task_checks`?
3. Does the plan have a "Parallelizable groups" section (run `task-distributor` first if not)?
4. Is the workspace clean?
5. Have I read the PRD success criteria and confirmed the plan covers them?
6. Is the budget set?

## Pass / fail summary

The loop closes when every plan task is checked complete and every check returned pass on the final retry.

The loop stops without closing when any task exhausts its retry budget, two-strike triggers and `debugger` + `five-whys` halt the task, or the user explicitly stops.

## Relationship to other skills

- **task-plan** — input
- **debugger** — invoked at the first same-failure-mode repeat
- **five-whys** — invoked if `debugger` cannot surface a root cause
- **code-reviewer** — invoked after every task check passes, before marking done
- **multi-agent-coordinator** — orchestrates parallel spawns
- **error-coordinator** — correlates failures across parallel tasks
- **quality-review** — runs at the end of the parent `dev-loop` (Stage 6); not invoked inside this skill
- **skill-validator** — sibling skill, specialized for validating skills

## Anti-patterns

- **Patching past the first same-failure repeat without `debugger`.** The classic ralph failure.
- **Implementing past the task scope.** Each task does one thing.
- **Skipping the `code-reviewer` pass.** The task check is a gate, not the only gate.
- **Hand-rolled parallel spawning.** Use `multi-agent-coordinator`; the partial-failure handling matters.
- **Silent escalation.** Escalations go to the user explicitly.
