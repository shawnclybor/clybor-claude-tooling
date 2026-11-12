---
name: build-validate
description: >
  Review a build's PREMISES — the three-to-five things that must be true about the world for the
  design to be right — once, after build-probe and before build-plan. Not a plan review. Not a
  per-round gate. Spawns 2-3 reviewers against the premise page and the probe run's UNPROVABLE
  list, and asks one question: is the frame right. Use when a build's frame is new or contested —
  a new module whose oracle is not obvious, a schema change that alters what a field MEANS, or a
  reversal like "we check their sheet" becoming "we produce it". Triggers — "validate the
  premises", "is the frame right", "check my assumptions before I plan", "/build validate".
  Do NOT use on a plan, on a repair round, or on a running system.
---

# Build Validate — the premise check

**One question: is the frame right?**

Not "is the plan complete", not "is this number correct", not "could a careless implementer game
this criterion". Those have cheaper detectors and this stage must not spend itself on them.

## Why this is scoped so narrowly — the measurement

Twenty-one recorded rounds across seven slugs under the old design, which reviewed *plans*:

```
round-1 must-fix:  8, 13, 14, 15, 12, 12, 9      mean 11.9, every time
total must-fix:    175
self-inflicted:     78  = 45%      (a finding in text the PREVIOUS round's repair wrote)
```

Three things follow, and the design is built on them.

**A freshly-written plan carries ~12 must-fix regardless of care.** Seven independent first rounds,
range 8–15. That is not a quality signal; it is what happens when prose asserts things about code
nobody has run.

**Later rounds mostly grade their own damage.** Repair rewrites the document, the panel re-reads
fresh surface, forever. One slug reached *zero* must-fix at round 6, took on new scope, and was back
to 12 at round 7 — with `review-drift.py` scoring 12 of 12 self-inflicted.

**Sorting one real round by cheapest detector, only 3 of 15 findings needed judgment.** Seven were
checkable facts (a probe settles those in seconds). Five were plan incoherence
(`check-plan-soundness.py` settles those in under a second). Three were frame errors — and those
three were worth the whole exercise, because nothing else finds them.

So: probe the facts, gate the structure mechanically, and spend this stage only on the frame.
Premises do not change when you fix a typo, which is precisely why reviewing them cannot spiral.

## When to use

Run once, when a build's frame is **new or contested**:

- a new module whose oracle is not obvious — *what makes this output right?*
- a schema change that alters what an existing field **means**
- a reversal of direction — "we audit their sheet" becoming "we generate it"
- any `UNPROVABLE` entry that `build-probe` carried forward

If you can state every premise in one line and none is in dispute, **skip this stage and say so in
`state.json`.** Skipping a premise check on settled ground is correct, not a shortcut.

## When NOT to use — each of these has a cheaper detector

| Not this | Use instead |
|---|---|
| A plan's task list | `check-plan-soundness.py` — 8 mechanical classes, under a second |
| A number, count, filename or line reference | `build-probe` |
| A repair round after findings were fixed | Nothing. Re-run the probes and the mechanical gate |
| A running system with a mutation-backed suite | The suite. Run the thing |
| A per-iteration code change | `build-execute`'s conditional review — and it is conditional |


## Where the rest lives (read the file for the phase you are in)

| Phase / topic | Read |
|---|---|
| Phase 1 premise page, Phase 2 pass condition, Phase 3 review agents | `references/premise-page-and-review.md` |
| Phase 4 record and report, the stop rule, Output, Guidelines | `references/record-stop-rule-and-output.md` |
