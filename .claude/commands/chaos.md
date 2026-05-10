---
description: Run only the chaos-engineer (Sonnet) against a target. Finds edge cases, failure modes, malformed inputs, scale assumptions, and adversarial use.
---

# /chaos

Single-lens review using just the chaos-engineer agent. Use when you specifically want the "what breaks this?" lens.

## Usage

```
/chaos <target>
```

## What happens

1. Spawn `chaos-engineer` (Sonnet) against the target
2. Walk the four lenses: edge cases, failure modes, concurrency / scale, adversarial use
3. Return numbered findings with scenarios, failure modes, likelihoods, and mitigations

## When to use this instead of /quality-review

- The design is locked and you only need a robustness pass
- You're about to ship and want a final stress test
- The target is operational (a job, a hook, a queue, an integration) rather than conceptual
