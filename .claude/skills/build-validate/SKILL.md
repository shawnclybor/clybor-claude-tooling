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

## Phase 1: WRITE THE PREMISE PAGE

One page. `.claude/PRPs/{slug}/premises.md`. Three to five entries, each in this shape:

```markdown
### P1. {The premise, as a claim about the world — one sentence}
**If this is wrong:** {what in the build becomes incoherent}
**Evidence:** {a probe id, a document, a person who said it — or "none, this is an assumption"}
**Who can settle it:** {a probe / the user / a named person at the client}
```

A premise is load-bearing: if it is false, some part of the design stops making sense. *"The account
numbers we bind on are printed on the bills"* is a premise. *"Task 4 should come before Task 5"* is
not — that is the plan's business.

Carry every `UNPROVABLE` from `probe.md` in as a premise. That list is this stage's agenda.

**If a premise can be settled by asking the user, ask the user.** One question, five seconds,
and you are done. Measured: on one build, three frame errors all reduced to a single question the
owner could have answered instantly — five agents spent 45 minutes discovering the question existed.
Discovering the question is this stage's value; answering it usually is not.

## Phase 2: DECLARE THE PASS CONDITION

Write it into `validate.md` **before** spawning anything. A bar set after seeing the findings is not
a bar.

```markdown
### Pass condition (declared {ISO}, before agents ran)
- Scope: the premises in premises.md. Nothing else is in scope, including the plan.
- PASS if: every premise is settled — confirmed by evidence, or decided by the owner.
- FAIL if: any premise is contradicted by the evidence, or any load-bearing premise is
  unstated and only surfaced by review.
```

## Phase 3: REVIEW (2-3 agents, one message)

Spawn in a single message. Every reviewer gets the pass condition from Phase 2, the scope line, and
`premises.md` with the probe run's `UNPROVABLE` entries already carried in.

Each reviewer is a **named agent**, not `general-purpose`. Each of the three questions below is one
agent's standing lens, and this stage runs exactly once — there is no later round to correct a
reviewer that improvised its own frame.

### Agent 1 — Premise auditor (`adversarial-reviewer`, Opus)

Finds the unstated frame, which is the failure mode that matters.

```
Agent(
  subagent_type="adversarial-reviewer",
  description="Surface unstated premises in {slug}",
  prompt="Scope: premises only. The plan, its task list and its ordering are OUT of scope. Design: <paste PRD 'What this is' + anchor case>. Stated premises: <paste premises.md>. Which premises is this design relying on that are NOT stated? For each, write it as a one-sentence claim about the world and say what in the build becomes incoherent if it is false. Do not report numbers, counts, filenames or line references — build-probe owns those. Findings only, no edits."
)
```

### Agent 2 — Falsifier (`evidence-auditor`)

Its output contract is already CONTRADICTED / SUPPORTED / NO EVIDENCE against a source.

```
Agent(
  subagent_type="evidence-auditor",
  description="Falsify each stated premise against the sources",
  prompt="Scope: the stated premises only. Premises with their Evidence lines: <paste premises.md>. Sources to read: <paste paths — documents, code, probe output>. For EACH premise report exactly one of CONTRADICTED / SUPPORTED / NO EVIDENCE, naming the file and line that decides it. NO EVIDENCE is a valid and useful verdict — do not upgrade it to SUPPORTED because the premise sounds reasonable. Findings only, no edits."
)
```

### Agent 3 — Oracle auditor (`chaos-engineer`)

Only when the build produces a value a human will act on. This is the frame problem's home: a
criterion satisfiable by a module that behaves honestly while the deliverable stays useless.

```
Agent(
  subagent_type="chaos-engineer",
  description="Audit the correctness oracle for {slug}",
  prompt="Scope: the correctness oracle, not the code and not the plan. Design: <paste PRD 'What this is' + anchor case>. Premises: <paste premises.md>. What makes this output right, and how would we know if it were subtly wrong? Is the correctness check a property of the module, or of the thing a person reads? Name one concrete case where every stated criterion passes and the output is still wrong for its reader. Findings only, no edits."
)
```

No pattern auditor, no completeness auditor, no anti-pattern auditor — mechanical checks own those
now. No fact-checker; `build-probe` owns facts. Adding a fourth lens re-opens the spiral this stage
was scoped to avoid.

## Phase 4: RECORD AND REPORT

```bash
python3 .claude/hooks/review-drift.py record <premises path> --must N --should N --note N \
  --self-inflicted 0 --round-note "premise review"
```

Write `validate.md`: the pass condition, each premise with its verdict, and the decisions the owner
made. **A premise the owner settled is settled** — record it and never re-open it.

## The stop rule

**One round.** There is no round 2 on premises: a premise is confirmed, contradicted, or decided, and
none of those states improves by reviewing again. If new premises appear later, that is a new frame
and a new single round, not a second pass at this one.

If you find yourself wanting another round, the thing you actually want is either a probe (write it)
or a decision from the owner (ask for it).

## Output

```
## Premises: {slug}

**Reviewed:** N premises ({N} carried from probe.md as UNPROVABLE)
**Settled:** {N} by evidence · {N} by the owner
**Unstated premises surfaced:** {N}
**Verdict:** PASS / FAIL

### Next step
PASS → `build-plan {slug}` — capped at ONE runnable increment.
FAIL → the frame is wrong. Fix the PRD, re-probe, and run this once more.
```

## Guidelines

- This skill is READ-ONLY on the build. It writes `premises.md` and `validate.md` and nothing else.
- If a premise review produces a finding about a task, you are in the wrong stage. Drop it.
- A build with no contested premises should skip this entirely. Record the skip; do not manufacture
  premises to justify a run.
- PASS means the frame is sound. It does not mean the build will work — that is the acceptance
  driver's job, and the driver is written red before any of this is worth anything.
