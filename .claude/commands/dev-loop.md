---
description: Run the 7-stage development loop — PRD → plan → validate → ralph → verify → evaluate → iterate — against a new feature or non-trivial change.
---

# /dev-loop

Invoke the `dev-loop` skill. Drives a feature from a one-paragraph problem statement to a verified, evaluated deliverable.

## Usage

```
/dev-loop <feature-slug> [problem statement]
```

If `problem statement` is omitted, the loop asks for it in Stage 1.

## What happens

1. **PRD** — write `docs/PRDs/<slug>.md` with problem, success criteria, scope, risks
2. **Plan** — break PRD into a sequenced checkbox task list
3. **Validate** — run `/quality-review` against the plan (simplifier + adversarial + chaos)
4. **Ralph** — execute task-by-task with iterate-on-failure (two-strike rule)
5. **Verify** — run the full test/build/lint suite; every success criterion must have a corresponding check
6. **Evaluate** — run `/quality-review` against the implementation
7. **Iterate / close** — fix anything Stage 5 or 6 surfaced, or close with a short closure note

A stage that fails its gate does not advance. The loop iterates that stage, escalates, or stops cleanly.

## When to skip

- One-line fixes, typos, dependency bumps
- Spike work where the goal is to learn, not to ship
- Tasks where a single skill already does the job (use that skill directly)
