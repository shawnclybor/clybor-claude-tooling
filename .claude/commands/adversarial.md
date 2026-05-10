---
description: Run only the adversarial-reviewer (Opus) against a target. Challenges claims and assumptions; finds logical gaps.
---

# /adversarial

Single-lens review using just the adversarial-reviewer agent. Use when you specifically want the "is this the right thing?" lens and don't need simplification or robustness analysis.

## Usage

```
/adversarial <target>
```

## What happens

1. Spawn `adversarial-reviewer` (Opus) against the target
2. Return numbered findings grouped by Critical / High / Medium / Low

## When to use this instead of /quality-review

- The target is already known to be simple — you want the reasoning lens, not KISS
- You need the strongest reasoning model (Opus) and don't want it diluted by parallel synthesis
- The proposal has already passed simplifier review and you're stress-testing the logic
