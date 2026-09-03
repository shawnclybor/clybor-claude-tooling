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

## The two agents the loop calls

The loop above names these at the two points that matter. Both are gates, not commentary.

### `code-reviewer` — on every task whose check just passed, before it is marked done

A Critical finding sends the task back into the loop with the findings as input. The task check is a gate; it is not the only gate.

```
Agent(
  subagent_type="code-reviewer",
  description="Review task {N} before marking done",
  prompt="Review the changed files at <paths> — diff scope only, not the whole repo. Task: <task title and its one-line scope>. Its check command already passed: <command>. Do NOT re-report what the check covers. Report correctness bugs, type-safety gaps, blast-radius misses beyond the changed files, and structural debt, each with file and line, marked Critical / High / Medium / Low. Read-only, no edits."
)
```

### `debugger` — on the FIRST same-failure-mode repeat, not after the third

Earlier than the two-strike halt on purpose: the point is to investigate before a blind retry, not after one.

```
Agent(
  subagent_type="debugger",
  description="Reproduce and narrow the repeated failure on task {N}",
  prompt="Task: <task title>. Check command: <command>. It has now failed twice with the same failure mode. Attempt 1 output: <paste>. Attempt 2 output: <paste>. Changes made between them: <paste diff>. Reproduce the failure first, then narrow to a root cause with evidence — a log line, a code path, or a test output. Return the root cause and the SMALLEST fix, or state plainly that you cannot reproduce it. Do not implement the fix."
)
```

If `debugger` returns a root cause, apply the minimal fix and retry once. If it cannot reproduce or cannot find a root cause, invoke `five-whys` and halt the task — a blind third retry is worse than a clean failure.

### Also referenced by this skill

- **`five-whys`** — the protocol path when `debugger` comes back empty. Halts the task.
- **`error-coordinator`** — when 2+ parallel tasks fail in the same run, correlates symptoms to a shared cause (upstream dependency, shared config, environment) before the group is stopped.
- **`multi-agent-coordinator`** — reads the plan's "Parallelizable groups" section and runs those tasks concurrently with partial-failure handling.

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
- **quality-review** — runs at Stage 6 against the built implementation; not invoked inside this skill
- **skill-validator** — sibling skill, specialized for validating skills

## Anti-patterns

- **Patching past the first same-failure repeat without `debugger`.** The classic ralph failure.
- **Implementing past the task scope.** Each task does one thing.
- **Skipping the `code-reviewer` pass.** The task check is a gate, not the only gate.
- **Hand-rolled parallel spawning.** Use `multi-agent-coordinator`; the partial-failure handling matters.
- **Silent escalation.** Escalations go to the user explicitly.
