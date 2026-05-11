---
name: five-whys
description: Root-cause analysis protocol for when something breaks unexpectedly. Use when a tool call fails twice, a service returns unexpected results, a workflow produces wrong output, or any situation where retrying blindly would waste time. Triggered by "why did that break", "what went wrong", "debug this", or the Two Strikes Rule. Use proactively — if you catch yourself about to retry the same failing call a third time, stop and invoke this instead. Do NOT use for routine errors with obvious fixes (typos, missing params, wrong file path).
---

# Five Whys — Root Cause Analysis

When something breaks and the cause isn't obvious, walk through this protocol **before** retrying or working around the problem.

Why this matters: blind retries are the #1 source of wasted time and compounding errors. A wrong guess can corrupt data, send to the wrong destination, or overwrite files with stale state. Five minutes of root-cause analysis now saves thirty minutes of cleanup later.

## When to invoke

- A tool call fails twice with the same or similar error (Two Strikes Rule)
- A service returns unexpected/wrong data (stale, empty, mis-routed)
- A workflow produces incorrect output despite correct-looking inputs
- The user reports something broke that previously worked
- You catch yourself about to retry something that already failed twice

## The Protocol

### Step 1 — State the problem

Write one sentence: what happened vs. what was expected. Be specific. Include the tool name, the exact input, and the actual output.

A vague problem statement ("the X thing broke") leads to a vague investigation. Specificity narrows the search space immediately.

### Step 2 — Ask "Why?" iteratively

Use Sequential Thinking for the chain. Each thought = one "Why?" iteration. Set `totalThoughts: 5` initially. Use `isRevision: true` if a later "Why?" invalidates an earlier assumption.

Each answer becomes the subject of the next "Why?" Stop when you reach a root cause you can act on — you don't always need all five levels.

```
Problem: Draft landed on wrong record
Why 1?  → The tool resolved the wrong target ID
Why 2?  → ID resolution uses fuzzy matching, not exact lookup
Why 3?  → We passed instructions text instead of an explicit ID
Why 4?  → We didn't search for the target first to get its ID
ROOT CAUSE: No find-first step before the write
```

Keep going past the surface-level "what" and into the structural "why." "The API returned an error" is a symptom. "We sent a property name with a missing trailing space" is a root cause.

### Step 3 — Check governance

Before proposing a fix, check whether this is a known issue or a skipped step:

1. Search the relevant rule file's **Known Issues** section
2. Check the **Pre-Flight Checklist** — did we skip a step?
3. If the issue IS documented and we missed it → the fix is process adherence, not a new rule. Note what went wrong in how we followed the process.
4. If the issue is NOT documented → proceed to Step 4

This step exists because many "new" bugs are actually known issues that got missed. Checking governance first avoids reinventing workarounds that already exist.

### Step 4 — Fix and document

1. **Immediate fix** — apply the smallest change that resolves the root cause
2. **Document** — add the issue to the relevant rule file's Known Issues with the date, what happened, and the resolution
3. **Prevent** — if a pre-flight check would have caught this, add one
4. **Codify** — if the rule is honor-system and easy to skip, write a script that exits non-zero on violation

Every Five Whys should leave the rule files better than it found them. The goal is to make this specific failure impossible to repeat silently.

### Step 5 — Report

Tell the user clearly:
- What broke (Step 1)
- Root cause (Step 2 — the deepest "why" you reached)
- Whether it was a known issue we missed or a new discovery (Step 3)
- What was fixed and what was documented (Step 4)
- Whether anything needs manual intervention

## Key principle

> The goal is never "make it work this time." The goal is "make it never break this way again." Every Five Whys should end with a governance update or a script that prevents recurrence.

## When to use debugger or error-coordinator instead

- **`debugger`** — if the failure has a reproducible trigger and you need to find a root cause rather than walk a protocol. Reproduction-first, evidence-driven. Use `debugger` first; fall back to five-whys if `debugger` cannot reproduce or cannot find a root cause.
- **`error-coordinator`** — if multiple parallel agents or tasks failed in the same run and the failures might share an upstream cause. Correlates symptoms; surfaces shared root causes.

Five-whys is the protocol for unexpected failures with no reproduction. `debugger` is the executor when reproduction exists. Both end in a governance update.
