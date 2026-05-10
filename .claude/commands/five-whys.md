---
description: Walk the five-whys root-cause analysis protocol when something broke unexpectedly.
---

# /five-whys

Invoke the `five-whys` skill. Use when a tool failed twice, output is wrong despite correct-looking inputs, or you catch yourself about to retry blindly.

## Usage

```
/five-whys
```

The skill prompts you for the problem statement and walks the protocol.

## When to skip

- Routine errors with obvious fixes (typo, missing param, wrong path)
- Single-failure cases that obviously won't recur

## When to invoke proactively

- About to retry the same call a third time
- A workflow produced wrong output and you don't know why
- An MCP returned unexpected data
