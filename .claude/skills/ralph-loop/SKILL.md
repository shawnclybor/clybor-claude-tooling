---
name: ralph-loop
description: Run a Ralph Loop — Stop-hook-driven autonomous iteration on a single prompt. Same prompt re-fed each iteration via a Stop hook that blocks session exit. Claude emits an exact completion-promise string to signal done. Use for well-defined tasks with automatic verification that can run autonomously (overnight, walk-away). Triggers — "ralph this", "ralph loop on X", "autonomous loop on X", "let it iterate until done", "run until completion-promise". Monolithic by design — one task per loop.
---

# Ralph Loop

Implementation of the Ralph Wiggum technique: a single prompt re-fed to Claude on every session-exit attempt via a Stop hook, until Claude emits an exact completion-promise string or max-iterations is reached.

Based on Anthropic's official `ralph-loop` plugin and Geoffrey Huntley's original technique.

## Core concept

```
/ralph-loop "<prompt>" --completion-promise "DONE" --max-iterations 50

# Then Claude Code automatically:
# 1. Works on the task
# 2. Tries to exit
# 3. Stop hook (.claude/hooks/ralph-stop.sh) blocks exit
# 4. Hook checks transcript for completion-promise
# 5. If found → state cleared, exit allowed
# 6. If not + under budget → state incremented, exit blocked, prompt re-fed
# 7. If not + budget exhausted → state cleared, exit allowed with halt message
```

The loop is **self-referential**: the prompt never changes between iterations. Claude's previous work persists in files. Each iteration sees modified files and git history. The improvement comes from reading the result of the previous iteration.

## When to use

Good for:
- Well-defined tasks with automatic verification (tests, linters, build, type-check)
- Tasks requiring iteration to refine (getting tests to pass, fixing a flaky integration)
- Greenfield projects you can walk away from
- Overnight unattended runs

Not good for:
- Tasks requiring human judgment or design decisions (use `quality-review` instead)
- One-shot operations
- Tasks without a clear binary signal for completion
- Production debugging (use `/five-whys` and the `debugger` agent)

## State + safety

The Stop hook reads `.ralph-loop/state.json`:

```json
{
  "prompt": "<the original prompt>",
  "completion_promise": "DONE",
  "max_iterations": 50,
  "current_iteration": 3,
  "started_at": "<iso8601>",
  "last_continued_at": "<iso8601>"
}
```

`--max-iterations` is the primary safety mechanism. The completion-promise uses exact-string matching so it cannot encode multiple completion conditions (no "SUCCESS" vs "BLOCKED"); always rely on max-iterations as the hard ceiling.

To cancel mid-flight: `rm .ralph-loop/state.json` — the next exit attempt completes normally.

## Prompt-writing best practices

### 1. Clear binary completion criteria

Bad: *"Build a todo API and make it good."*

Good:
```
Build a REST API for todos.

When complete:
- All CRUD endpoints working
- Input validation in place
- Tests passing (coverage > 80%)
- README with API docs
- Output: <promise>COMPLETE</promise>
```

### 2. Incremental goals — phase-by-phase

Bad: *"Create a complete e-commerce platform."*

Good:
```
Phase 1: Authentication (JWT, tests)
Phase 2: Product catalog (list/search, tests)
Phase 3: Shopping cart (add/remove, tests)

Output <promise>COMPLETE</promise> when all phases done.
```

### 3. Self-correction loops inside the prompt

Bad: *"Write code for feature X."*

Good:
```
Implement feature X following TDD:
1. Write failing tests
2. Implement feature
3. Run tests
4. If any fail, debug and fix
5. Refactor if needed
6. Repeat until all green
7. Output: <promise>COMPLETE</promise>
```

### 4. Escape hatches

Always set `--max-iterations`. Include in the prompt what to do if stuck:

```
If not complete after 15 iterations:
- Document what is blocking progress
- List what was attempted
- Suggest alternative approaches
- Output: <promise>BLOCKED</promise>
```

Note: completion-promise is a single exact string. If you need to distinguish completion paths (success vs blocked), use the max-iterations limit + manual review of the final state.

## Monolithic by design

Ralph is intentionally single-process, single-repo, one-task-per-loop. The argument from Huntley:

> *Multi-agent systems are like microservices — distributed coordination overhead. LLMs are non-deterministic, so coordination overhead compounds: you can't reason about which agent did what, when state was passed, or where a race condition lives. For autonomous overnight runs you can't watch, predictability beats speed.*

This skill does NOT spawn parallel agents within the loop. For task-driven parallel work, use `ralph-implement` (which supports parallelizable groups via `task-distributor` and `multi-agent-coordinator`). For autonomous walk-away work, use this skill.

## Agents Claude can invoke inside the loop

The loop is monolithic at the orchestration level — one Claude process iterating — but Claude can invoke sub-agents within each iteration as needed. Useful ones:

- **`code-reviewer`** — review changes between iterations to catch regressions
- **`debugger`** — when a test fails repeatedly, narrow the cause before patching
- **`security-auditor`** — when a security-sensitive criterion is in scope
- **`evidence-auditor`** — when the task involves cited claims

Invoke these **inside** an iteration — not in parallel across iterations.

## Philosophy

- **Iteration > Perfection** — let the loop refine
- **Failures are data** — predictable failures are debuggable failures
- **Operator skill matters** — the prompt is the bottleneck, not the model
- **Persistence wins** — keep trying until the completion-promise or the budget gives out

## Relationship to other skills

- **`ralph-implement`** — sibling. Task-driven structured variant. Uses a task plan + per-task checks instead of a single prompt + completion-promise. Use when you have a `task-plan` output already.
- **`skill-validator`** — sibling. Specialized for validating SKILL.md files against pass criteria.
- **`five-whys`**, **`debugger`** — invoked inside the loop when iteration hits a wall.

## Anti-patterns

- **No `--max-iterations`** — loops without a hard cap are runaway loops. Always set it.
- **Vague completion-promise** — "DONE" works only if the prompt is specific about what "done" means. Pair the promise with a checklist inside the prompt.
- **Multiple completion paths via the promise** — you only get one exact string. Use max-iterations + final-state review for branch outcomes.
- **Parallelism inside the loop** — defeats the monolithic design. Use `ralph-implement` if you need parallel task groups.
- **Treating the hook as optional** — without the Stop hook wired in `settings.json`, this skill does not work. Verify hook installation before invoking `/ralph-loop`.
