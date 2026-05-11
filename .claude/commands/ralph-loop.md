---
description: Start a Ralph Loop — Stop-hook-driven autonomous iteration on a single prompt until the completion-promise is emitted or max-iterations is hit.
---

# /ralph-loop

Start a Ralph loop. Implements the Ralph Wiggum technique: a single prompt re-fed to Claude on every session exit via a Stop hook, until Claude emits an exact completion-promise string or max-iterations is reached.

## Usage

```
/ralph-loop "<prompt>" --completion-promise "<text>" --max-iterations <n>
```

**Options:**
- `--completion-promise <text>` — exact string Claude emits to signal done (default: `DONE`)
- `--max-iterations <n>` — hard cap (default: 50; required for safety)

## What happens

1. Write `.ralph-loop/state.json` with the prompt, completion-promise, and iteration budget
2. Start working on the prompt
3. When the session tries to exit, `.claude/hooks/ralph-stop.sh` fires
4. The hook checks the transcript for the completion-promise:
   - **Found** → state cleared, exit allowed
   - **Not found AND under budget** → state incremented, exit blocked, prompt re-fed
   - **Not found AND budget exhausted** → state cleared, exit allowed with halt message

## Cancel an active loop

Delete `.ralph-loop/state.json` to stop the loop on the next iteration:

```
rm .ralph-loop/state.json
```

## When to use

Well-defined tasks with automatic verification (tests, linters, build), greenfield projects you can walk away from, anything where iterative refinement against deterministic checks is the right pattern.

## When NOT to use

Tasks requiring human judgment, one-shot operations, unclear success criteria, production debugging (use `/five-whys` or the `debugger` agent instead).

## Prompt writing — see the skill

The `ralph-loop` skill documents the prompt-writing best practices (clear completion criteria, incremental goals, self-correction, escape hatches). Read it before launching a long-running loop.
