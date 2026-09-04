# Review rubric — fixed before any agent runs

This file is the constant. It is written down so that severity is a property of the **finding**,
not of the round it was found in, the agent that found it, or how hard someone was looking that
day. If it changes, that is a deliberate edit with a reason, not a drift.

## must-fix

> **A defect that would produce a false pass, a wrong deliverable, or wasted days.**

A finding is must-fix only if you can name which of the three, concretely:

| Class | Test | Example |
|---|---|---|
| **False pass** | a gate reports green on something wrong | a `diff` comparing two empty sets and exiting 0 |
| **Wrong deliverable** | the artifact ships and is materially incorrect | a checker that renders a sheet whose figures the tool got wrong |
| **Wasted days** | the work as specified cannot be built, or must be rebuilt | a golden that the pinned renderer cannot produce |

If you cannot name one, it is **not** must-fix. Write it as a note and move on.

## should-fix

Real, worth doing, does not meet the bar above. It makes the thing better; it does not stop it
being correct. **should-fix never blocks.**

## note

Everything else: hygiene, stale line numbers, wording, off-by-one counts, "this could be clearer."
Notes are recorded once and never re-litigated in a later round.

## Explicitly NOT must-fix

These were all miscategorised in a real run and cost a day:

- **Cosmetic drift.** A citation says line 342, the file has 341 lines. Note.
- **Restating a known open question.** If the target already records something as undecided *and
  says who decides it and when*, that is a tracked decision, not a defect. Q9 output format on the
  yellow-sheet build was flagged as a risk for hours when it was an active discovery workstream.
- **A finding the reviewer or fixer introduced in the previous round.** Real, must be fixed, but
  it is **self-inflicted** and is counted separately (see drift). Reporting it in the same total as
  pre-existing defects makes the target look like it is degrading when it is not.
- **A re-grade.** The same artifact, unchanged, judged against a stricter standard than last round.
  That is a rubric change and belongs in this file, not in a findings list.
- **Preference.** "I would have structured this differently" with no failure named.

## The three lenses — non-overlapping by construction

Each agent gets exactly one question. Overlap produces three copies of one finding and inflates
every count.

| Agent | Owns | Does NOT own |
|---|---|---|
| `adversarial-reviewer` | **Is it true?** Claims unsupported by evidence, reasoning that does not follow, a conclusion the cited source does not carry, ambiguity where two readings give different builds. | Edge cases. Complexity. |
| `chaos-engineer` | **What breaks it?** Failure modes, malformed input, empty and boundary states, ordering hazards, fail-open shapes, what happens when a dependency is missing. | Whether the design is too big. Whether a claim is sourced. |
| `simplifier` | **Is it more than it needs to be?** Over-engineering, premature abstraction, scope beyond the stated requirement, two mechanisms where one would do. | Correctness. Failure modes. |

A finding that does not fit its agent's column is out of scope for that agent — it says so and
drops it rather than reporting it.

## What the mechanical checker owns

Where a machine can decide it, a machine decides it, and **no agent spends budget on it**.
`check-plan-soundness.py` owns these classes for plans:

- a DONE check that greps a string its own task body wrote
- an artifact used by the acceptance test that no task authors
- a DONE depending on a later task's output
- criterion wording disagreeing across documents
- dependency cycles, unknown task references, duplicate task numbers

**Run the checker first. If it fails, fix that before spending a panel** — those defects cost
seconds to find mechanically and an hour to find with agents. Tell every agent these classes are
already clean and must not be re-reported.

The checker does not drift: same input, same answer, every run. That is the point of it.

## Stop condition

Review is **done** — and further rounds are waste — when all three hold:

1. the mechanical checker passes
2. zero must-fix under the definition above
3. the last round produced **no new must-fix classes** — only instances of ones already known

Rounds are capped at **three** per target. A fourth round is not permitted without a written reason
naming what changed about the target or the rubric. Absent that, a fourth round is drift.

**Review does not converge by looking harder.** After the cap, remaining doubt is resolved by
building the thing and watching it run, not by re-reading it.
