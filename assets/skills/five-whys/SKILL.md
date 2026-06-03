---
name: five-whys
description: Root-cause analysis protocol for when something breaks or fails unexpectedly. Use when a tool call fails twice, an integration returns unexpected results, a workflow produces wrong output, or any situation where retrying blindly would waste time. Also use when the user says "why did that break", "what went wrong", "debug this", or "figure out why X isn't working." Use proactively — if you catch yourself about to retry the same failing call a third time, stop and invoke this skill instead. Do NOT use for routine errors with obvious fixes (typos, missing params, wrong file path). Use when the failure is surprising or the cause is unclear.
---

# Five Whys — Root Cause Analysis

When something breaks and the cause isn't obvious, walk through this protocol
**before** retrying or working around the problem.

The reason this matters: blind retries are the #1 source of wasted time and
compounding errors. A wrong guess can create duplicate records, send messages to
the wrong thread, or overwrite files with stale data. Five minutes of root-cause
analysis now saves thirty minutes of cleanup later.

## When to invoke

- A tool call fails twice with the same or similar error (Two Strikes Rule)
- An integration returns unexpected/wrong data (stale, empty, mis-threaded, etc.)
- A workflow produces incorrect output despite correct-looking inputs
- The user reports something broke that previously worked
- You catch yourself about to retry something that already failed twice

## The Protocol

### Step 1: State the problem

Write one sentence: what happened vs. what was expected. Be specific — include
the tool name, the input you gave it, and the output you got back.

**Example:**
> "The draft-reply tool threaded the reply onto an unrelated invoice thread
> (thread_id abc123) instead of the intended letter thread (thread_id def456)."

This matters because a vague problem statement ("the email thing broke") leads to
a vague investigation. Specificity narrows the search space immediately.

### Step 2: Ask "Why?" iteratively

Each answer becomes the subject of the next "Why?" Stop when you reach a root
cause you can act on — you don't always need all five levels.

```
Problem: Draft landed on wrong thread
Why 1?  → The tool resolved the wrong thread_id
Why 2?  → thread_id resolution uses fuzzy matching, not exact lookup
Why 3?  → We passed instructions text instead of an explicit thread_id
Why 4?  → We didn't search for the target message first to get its thread_id
ROOT CAUSE: No find-first step before reply creation
```

The key is to keep going past the surface-level "what" and into the structural
"why." "The API returned an error" is a symptom. "We're sending a property name
with a missing trailing space" is a root cause.

### Step 3: Check your governance

Before proposing a fix, check whether this is a known issue or a skipped step:

1. Search the relevant governance or rules file's **Known Issues** table
2. Check the **Pre-Flight Checklist** (if one exists) — did we skip a step?
3. If the issue IS documented and we missed it → the fix is process adherence,
   not a new rule. Note what went wrong in how we followed the process.
4. If the issue is NOT documented → proceed to Step 4

This step exists because many "new" bugs are actually known issues that got
missed. Checking documentation first avoids reinventing workarounds that already
exist.

### Step 4: Fix and document

1. **Immediate fix**: Apply the smallest change that resolves the root cause
2. **Document**: Add the issue to the relevant governance file's Known Issues
   table with the date, what happened, and the resolution
3. **Prevent**: If a pre-flight check would have caught this, add one. If the
   check is deterministic, write a script that exits non-zero on violation and
   treat the script as the enforcing gate — prose rules are pointers.

Every Five Whys should leave your documentation better than it found it.
The goal is to make this specific failure impossible to repeat silently.

### Step 5: Report

Tell the user clearly:
- What broke (Step 1)
- Root cause (Step 2 — the deepest "why" you reached)
- Whether it was a known issue we missed or a new discovery (Step 3)
- What was fixed and what was documented (Step 4)
- Whether anything needs manual intervention (e.g., a record relation that
  can only be fixed in the source tool's UI)

## Key principle

> The goal is never "make it work this time." The goal is "make it never break
> this way again." Every Five Whys should end with a documentation update,
> filed where the next session will actually find it ({{KNOWLEDGE_BASE}}).

## Adaptation points

- `{{KNOWLEDGE_BASE}}` — where your team files persistent findings (a wiki, a
  wiki database, a docs/ folder). Step 4's "document" lands there.
