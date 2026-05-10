---
name: skill-validator
description: Ralph-loop skill validator. Iteratively runs a target skill against representative inputs in a target repo, scores output against pass criteria, applies fixes, and re-runs until pass or budget exhausted. Use when you need to validate that a skill works as advertised on a real codebase rather than just reviewing the SKILL.md by eye. Triggers — "validate this skill against [repo]", "ralph loop on [skill]", "does this skill work on naf-mentor-dashboard", "run the skill-validator". Read-only against the target repo by default.
---

# Skill Validator — Ralph Loop

A continuous-iteration eval loop for skills. Geoffrey Huntley-style: run the skill, evaluate, fix, re-run until pass criteria are met or the budget is spent. The loop fails closed, not open — if the budget exhausts before pass, the skill is reported as failing with a numbered list of unmet criteria.

## When to use

- After authoring a new skill, before promoting it for general use
- After editing an existing skill's prompt or pre-flight checklist
- When a skill behaves correctly in chat but fails in scripted runs (or vice versa)
- When promoting a skill from one project to another (e.g., lifting a life-crm skill into a fresh repo)
- When validating that a skill works against a specific target repo (e.g., `naf-mentor-dashboard-frontend`, `naf-mentor-dashboard-backend`)

## When NOT to use

- The skill is purely conversational with no measurable output — there's nothing to score
- The target repo is unavailable or empty — there's nothing to run against
- The skill is already covered by deterministic unit tests — those are cheaper and stricter

## Inputs

- **`SKILL_PATH`** — path to the skill being validated (e.g., `.claude/skills/quality-review/SKILL.md`)
- **`TARGET_REPO`** — path to the repo the skill will run against (e.g., `~/gits/naf-mentor-dashboard-frontend`)
- **`PASS_CRITERIA`** — file or inline list of required behaviors. Each criterion is a yes/no the loop can score. Format: `<id>: <description>` (one per line)
- **`BUDGET`** — max iterations (default 5) and max minutes (default 30). Hard cap; the loop fails if either is hit.

## The Loop

```
iteration = 0
while iteration < BUDGET.max_iterations:
    iteration += 1

    # 1. Run skill on representative input from TARGET_REPO
    output = run_skill(SKILL_PATH, sample_input(TARGET_REPO))

    # 2. Score output against PASS_CRITERIA
    results = score(output, PASS_CRITERIA)
    if all(results.values()):
        return PASS(iteration)

    # 3. Identify which criteria failed and why
    failures = [(id, why) for id, ok in results.items() if not ok]

    # 4. Generate a targeted fix to SKILL.md
    patch = propose_fix(SKILL_PATH, failures)
    apply(patch)
    log(iteration, failures, patch)

return FAIL(iteration, last_failures)
```

## Phase 1 — Setup (one-shot, before the loop)

1. Read `SKILL_PATH` end-to-end. Note the skill's stated triggers, inputs, and outputs.
2. Read `TARGET_REPO/CLAUDE.md` (if present) to understand project conventions.
3. Pick 2–3 **representative inputs** from the target repo:
   - For a code-review skill: 2–3 files representative of the codebase (one per language / layer)
   - For a docs skill: 2–3 documents of the type the skill targets
   - For an analysis skill: 2–3 inputs spanning easy / moderate / hard
4. Read `PASS_CRITERIA` and confirm every criterion is binary (yes/no), not vibes-based.
5. Take a baseline measurement: run the skill once against each input, record outputs, score them. This is iteration 0.

If iteration 0 passes everything, the skill is valid as-shipped. Report and exit.

## Phase 2 — Iterate

Each iteration:

1. **Run** the skill against each representative input (2–3 runs, parallel if independent)
2. **Score** outputs against PASS_CRITERIA. Each criterion: PASS / FAIL / DEGRADED
3. **Diff** results against the previous iteration. Did the last fix introduce a regression?
4. **Diagnose** the highest-priority failure. Is it a prompt gap, a missing pre-flight check, an under-specified output format, or a fundamental mismatch with the target repo?
5. **Patch** the SKILL.md with the smallest change that addresses the diagnosis. Append the rationale to the audit log, NOT just the diff.
6. **Log** to `.skill-validator/<skill-name>/iteration-<N>.json`:
   - `inputs` (paths or hashes)
   - `outputs` (verbatim or path)
   - `scores` (criterion-by-criterion)
   - `diagnosis`
   - `patch` (unified diff applied to SKILL.md)
7. **Check budget** — iterations remaining, minutes remaining. If exhausted, exit FAIL.

## Phase 3 — Exit

**PASS** — every criterion green for two consecutive iterations against every representative input. Two consecutive is the stability check; one good run could be a fluke.

**FAIL (budget exhausted)** — emit:
- Final SKILL.md state (with all patches applied)
- A diff vs. the original
- A numbered list of criteria that never passed, with the last failure mode for each
- A recommendation: human review, scope reduction, or skill rewrite

**FAIL (regression detected)** — if a patch makes a previously-passing criterion fail, revert the patch, log the regression, and continue with the next-highest-priority unaddressed failure. If no clean patch path remains, exit FAIL.

## Pass criteria — examples by skill type

- `quality-review` — produces 3 numbered findings tables (one per agent), at least one Critical or High finding when reviewing intentionally-flawed input, no fabricated file references
- `five-whys` — reaches a structural root cause within 5 iterations on the seeded test failure; ends with an explicit governance update recommendation
- `writing-quality` — flags 100% of seeded P0 AI-isms in detect mode; rewrites pass a re-detect with zero P0 hits in rewrite mode

## Rules and constraints

- **Read-only against TARGET_REPO** by default. Never modify files in the target repo unless `--write-target` is passed and the user has explicitly approved it. The validator's job is to fix the SKILL, not the target.
- **Audit every iteration.** No silent passes. The log file is the artifact, not just the final result.
- **Bound the budget.** A loop with no budget is not a loop, it's a runaway. Default 5 iterations / 30 minutes is generous; lower it for cheap skills.
- **Two-strike rule on patches.** If two consecutive iterations apply patches and neither moves the score, stop and ask the user. Continued patching is bias-confirmation.
- **Don't optimize for the criteria.** The criteria are the proxy, not the goal. If the skill passes the criteria but obviously gets the wrong answer, the criteria need rewriting, not the skill.
- **Failure is the success signal for the validator.** A validator that always passes is not measuring anything.

## Outputs

- `.skill-validator/<skill-name>/iteration-<N>.json` — per-iteration audit log
- `.skill-validator/<skill-name>/SUMMARY.md` — final pass/fail report
- A diff of `SKILL.md` showing what changed across the loop
