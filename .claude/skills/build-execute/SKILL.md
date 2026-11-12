---
name: build-execute
description: Bounded execution loop for a validated build plan. Hard caps on iterations, edits, and (where applicable) spend prevent runaway loops. Each iteration runs a CONDITIONAL adversarial review (only when the change touches a contract, a pinned constant, a refusal limb, or an unmutated path), applies the edit, measures via parallel fixture runs, and auto-invokes five-whys on stagnation or regression. Calls writing-quality on prose edits. Stops on success, on cap hit, on stagnation, or on regression. Use after Stage 3 is dispositioned (PASS, SKIPPED or WAIVED - recorded either way), before build-evaluate. Triggers — "execute the build", "build it", "iterate the X", "implement the plan". Refuses to start if the probes mismatch, the plan-soundness gate fails, the Stage 3 disposition is unrecorded, or profile preconditions are unmet.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, Skill, AskUserQuestion, mcp__sequential-thinking__sequentialthinking
user-invocable: true
argument-hint: "<slug> [--max-iterations N] [--dry-run] [--autonomous]"
---

# Build Execute

Bounded execution loop. The scheduler and budgeter; per-iteration work is delegated.

## Hard preconditions (REFUSE if unmet)

- `.claude/PRPs/{slug}/prd.md` exists
- `.claude/PRPs/{slug}/plan.md` exists
- `bash .claude/PRPs/{slug}/probes/run.sh` re-run in THIS session: 0 MISMATCH, 0 source changed
- `check-plan-soundness.py {slug}/plan.md --prd {slug}/prd.md` exits 0
- **Stage 3 disposition is RECORDED in `state.json` as `validate_regime`** and is one of the three below
- Profile's hard preconditions (defined in the profile) are met
- No prior `.claude/PRPs/{slug}/state.json` is in `state: running` (refuse double-runs)

If any precondition fails: stop, list the failures, do nothing else.

### The three Stage 3 dispositions

Premises get reviewed **once** — confirmed, contradicted, or decided. None of those improves by re-reviewing, so "validate again until PASS" is not a thing. Record exactly one:

| `validate_regime` | When | Must also record |
|---|---|---|
| **PASS** | Panel ran, frame held | Date, which premises were contested |
| **SKIPPED** | Nothing contested — no new module, no schema change, no reversal of what a field MEANS. The common case on a running build | Suite green, **mutations FULL PASS**, driver written RED first |
| **WAIVED** | Panel ran, FAILED, owner overrode on the record | Who, when, why, substituted gate, and `what_is_NOT_claimed` |

⚠ SKIPPED needs a **mutation-proven** suite. Green but unmutated is unfalsifiable — that reverts the target to greenfield, which takes the panel. So does a schema change or a new module, whatever the surrounding suite proves.

⚠ Three FAILs on one target is a process defect (Hard Rule 9). Re-scope; don't convert a repeated FAIL into a waiver.

## Hard caps (defaults — overridable per invocation but not per iteration)

- **Max iterations**: 3 (override `--max-iterations N`)
- **Max edits per iteration**: defined by profile (e.g., skill = 1 file, plugin = N skills × 1 file each)
- **Max spend**: profile-defined. Skip if profile has no spend (most internal builds have none)
- **Stagnation**: 2 consecutive iterations with no measurable progress on the acceptance test → stop automatically

Caps are enforced BEFORE each new iteration. They cannot be raised inside the loop.

## Pre-iteration-1 gate (REVIEW GATE — skip with `--autonomous`)

After preconditions PASS but BEFORE iteration 1 starts, present the run plan and ask for confirmation:

```
Print:
  - Shape: {single-shot / iterative-bounded / pipeline / wrapper}
  - Max iterations: {N}
  - Max edits per iteration: {profile-defined}
  - Files that will be touched: {list from plan Step-by-step tasks}
  - Acceptance bar: {from PRD}
  - Estimated effort: {from plan}

AskUserQuestion:
  Question: "Plan ready to execute for {slug}. Begin iteration 1?"
  Options:
    - "Yes, begin" → start iteration 1
    - "Yes, but dry-run first" → re-invoke with --dry-run, present what would happen, ask again
    - "Adjust caps" → ask follow-up for new --max-iterations / --max-spend, then begin
    - "Stop" → exit cleanly, leave state.json with state: aborted-pre-iteration
```

Why: the first edit commits the direction. If the plan says "rewrite SKILL.md prose for clarity" but the user realizes the actual issue is the trigger phrasings, this is the cheapest moment to course-correct.

Skip this gate if `--autonomous` was passed (e.g., for scheduled/batch runs).


## Where the rest lives (read before running the matching phase)

| When you are about to... | Read |
|---|---|
| Run an iteration (Steps 1-7: read state, decide, baseline, adversarial review, writing pass, apply edit, measure, continue/stop) | `references/iteration-steps.md` |
| Write the iteration report (Step 8), update state, produce Output or the session report, run dry-run mode, or check the Guidelines | `references/report-state-output.md` |

The hard preconditions, hard caps and review gate above apply before and during every iteration. Do not start an iteration without reading `references/iteration-steps.md`.
