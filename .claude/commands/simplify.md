---
description: Run only the simplifier (Sonnet) against a target. Finds over-engineering, premature abstraction, and unnecessary indirection.
---

# /simplify

Single-lens review using just the simplifier agent. Use when you want the KISS / YAGNI lens applied without challenging the underlying claims.

## Usage

```
/simplify <target>
```

## What happens

1. Spawn `simplifier` (Sonnet) against the target
2. Return numbered findings with simpler alternatives and risk-of-simplification notes

## When to use this instead of /quality-review

- You already trust the design's correctness — you only want it slimmer
- You're reviewing existing code (not a proposal) and want refactor candidates
- The target is purely structural (config, file layout, abstraction depth)
