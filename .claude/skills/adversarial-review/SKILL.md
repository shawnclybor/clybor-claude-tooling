---
name: adversarial-review
description: Coordinated three-lens adversarial review of any target — a PRD, a build plan, a validation report, code, or a freeform proposal. Spawns chaos-engineer, simplifier and adversarial-reviewer in parallel against non-overlapping questions, grades every finding against a rubric fixed BEFORE the agents run, defers the machine-decidable classes to a mechanical checker, and tracks the review process's own drift across runs so it cannot ratchet indefinitely. Use when a proposal, plan or document needs adversarial scrutiny before it is committed to. Triggers — "adversarial review", "review this plan", "tear this apart", "what's wrong with this", "review before I commit", "/adversarial-review". Do NOT use for a routine code diff (use code-review) or a build plan's pre-execution gate (use build-validate, which this complements rather than replaces).
---

# Adversarial Review

Three lenses, one fixed rubric, a machine doing the machine-decidable part, and a check on whether
the review itself is still measuring anything.

## Why this exists

A review process with no written rubric and no stop condition does not converge. It ratchets. The
failure is documented: one build plan reviewed four times in a day, each round clearing ~30 findings
and introducing 2-3, the must-fix count rising 9 → 46 while the plan grew 47 → 60 tasks and zero
product code was written. The findings were mostly real. The *process* was broken — four different
hunting instructions reported as one running total, no severity threshold, self-inflicted defects
counted as pre-existing, and no definition of done.

This skill exists to make that visible while it is happening rather than in a post-mortem.

## Phase 0: LOAD THE RUBRIC — before anything else

Read `rubric.md` in this skill's directory. It defines must-fix, the three lens boundaries, what the
mechanical checker owns, and the stop condition. **It is loaded before the target is read**, so
severity is a property of the finding rather than of the mood of the round.

Do not restate the rubric in agent prompts from memory — paste it. A paraphrased rubric is a
different rubric.

## Phase 1: CLASSIFY THE TARGET + RUN THE MECHANICAL GATE

Identify the target type. It sets the lens emphasis, and the emphasis is **fixed per type** — the
same type gets the same questions every run.

| Target type | Detect by | Lens emphasis |
|---|---|---|
| **build plan** | `.claude/PRPs/*/plan.md`, or a task list with DONE checks | chaos: sequencing + fail-open · simplifier: task count vs requirement · adversarial: DONE falsifiability |
| **PRD** | `.claude/PRPs/*/prd*.md`, or success criteria + anchor case | chaos: criteria that cannot fail · simplifier: scope beyond the ask · adversarial: unsourced claims, criteria that measure the wrong thing |
| **validation report** | `validate.md`, `evaluate.md`, a findings list | chaos: findings that cannot be acted on · simplifier: duplicate findings · adversarial: severity inflation, re-grades |
| **code** | a source file or diff | chaos: inputs, boundaries, error paths · simplifier: over-abstraction · adversarial: does it do what it claims |
| **freeform** | anything else | the three base questions unmodified |

Then run the mechanical checker if one applies. For a build plan:

```bash
python3 .claude/hooks/check-plan-soundness.py <plan> --prd <prd>
```

**If it fails, stop and fix that first.** Those defects cost seconds mechanically and an hour with
agents. Do not spend a panel on them.

## Phase 2: DRIFT PRE-CHECK

```bash
python3 .claude/hooks/review-drift.py check <target>
```

If it reports drift, **surface that to the user before running the panel** and ask whether to
proceed. A fourth round on an unchanged target usually should not happen; the answer is to build
the thing, not to look harder. Running the panel anyway is a decision the user makes knowingly.

## Phase 3: THREE LENSES, PARALLEL, ONE MESSAGE

Spawn all three in a single message. Each gets: the full rubric text, the target, its own column
from the lens table, and the exclusions.

Every agent prompt must carry these four constraints verbatim:

1. **Your lens only.** A finding outside your column is not yours — drop it, do not report it.
   Three agents reporting one finding is three counts of one problem.
2. **Name the class.** Every must-fix names which of false-pass / wrong-deliverable / wasted-days
   it causes, concretely. If you cannot, it is a note.
3. **These classes are already machine-checked and clean — do not re-report them:** <paste the
   checker's class list from rubric.md>.
4. **A tracked open question is not a defect.** If the target records something as undecided *and*
   names who decides it and when, that is a plan, not a gap.

Give each agent the **previous round's findings** where a history exists, with: *"Findings already
accepted and fixed. Do not re-report. If you believe one was fixed wrongly, say so explicitly as a
regression — that is different from finding it again."*

## Phase 4: SYNTHESIS — dedup, classify, count honestly

- Deduplicate across lenses. One defect = one finding, whichever lens found it first.
- Re-grade every claimed must-fix against the rubric yourself. Agents inflate. The synthesis step
  is where the rubric is actually enforced, not the agent prompts.
- **Count self-inflicted findings separately.** A defect introduced by the previous round's fixes
  is real and must be fixed, but it is not the target degrading, and folding it into one total is
  how a report says "46" when it means something else.
- Note contradictions between lenses rather than resolving them silently.

## Phase 5: RECORD + VERDICT

```bash
python3 .claude/hooks/review-drift.py record <target> \
  --must N --should N --note N --self-inflicted N
python3 .claude/hooks/review-drift.py check <target>
```

Report:

```
## Adversarial review: {target}   (round N)

Rubric: rubric.md (unchanged since {date} | CHANGED this run — see below)
Mechanical gate: PASS/FAIL
Drift: none / {signals}

### Must-fix (N)     — each names false-pass / wrong-deliverable / wasted-days
### Should-fix (N)   — does not block
### Note (N)         — recorded once, not re-litigated
### Self-inflicted (N of the must-fix, introduced by the previous round)

### Verdict
{PASS — zero must-fix} / {FAIL — N must-fix} / {STOP — cap reached, build instead}
```

## Stop condition

Review is done when the checker passes, must-fix is zero, and the last round produced no *new*
must-fix classes. Cap: **three rounds**. A fourth needs a written reason naming what changed about
the target or the rubric — pass it as `--round-note`. Absent that, the honest verdict is STOP:
remaining doubt gets resolved by building and running, not by re-reading.

## Guidelines

- **Read-only.** This skill never edits the target. It reports; the human decides.
- **Do not edit the target while the panel runs.** Findings against a moving file arrive already
  cured or already stale — observed, twice.
- **Changing the rubric is allowed and must be explicit.** Edit `rubric.md`, say so in the report,
  and expect the count to move for that reason alone. A silent standard change is the drift.
- **Complements build-validate, does not replace it.** build-validate is the pre-execution gate for
  a plan with a profile and a mirror. This is the general-purpose lens set, usable on anything, and
  the one to reach for outside the build pipeline.
