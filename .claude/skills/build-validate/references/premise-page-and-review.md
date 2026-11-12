<!-- build-validate Phases 1-3, moved verbatim from SKILL.md -->

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
