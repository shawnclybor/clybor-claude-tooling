<!-- build-evaluate Phases 6-6.5, moved verbatim from SKILL.md -->

## Phase 6: REPORT

Write `.claude/PRPs/{slug}/evaluate.md`:

```markdown
## Evaluation: {slug}

### Acceptance test
**Command:** {what was run}
**Exit code:** {N}
**Output summary:** {brief}

### Per-criterion verdict

| Criterion (from PRD) | Result | Notes |
|----------------------|--------|-------|
| {criterion 1} | PASS / FAIL / SKIPPED / NOT MEASURED | |
| {criterion 2} | PASS / FAIL / SKIPPED / NOT MEASURED | |

⚠ **`NOT MEASURED` and `SKIPPED` are first-class results and are NEVER folded into PASS.** A criterion
whose check could not run (no real matter present, PHI absent on this machine) is `NOT MEASURED`; one
whose owning task is cut or parked is `SKIPPED` and must be recorded with its skip line, never omitted.
A skip that prints nothing is indistinguishable from a skip that passed. Neither counts toward
`{N}/{total}` — report them on their own line.

### Anchor case
**Input:** {from PRD}
**Expected:** {from PRD}
**Actual:** {what the artifact produced}
**Match:** PASS / FAIL

### Cold-read findings (if run)
{summary}

### Verdict — TWO verdicts where the PRD defines an operational criterion, and they are NEVER merged

**CRITERIA** (reproducible from the tree, synthetic fixtures)
**PASS** = all in-scope criteria PASS + anchor case PASS
**FAIL** = any in-scope criterion FAIL or anchor case FAIL
`SKIPPED` criteria are listed by name and do not count either way.

**OPERATIONAL** (a real matter, where the PRD defines one)
**PASS / FAIL / NOT MEASURED**, reported verbatim from the driver, with the matter and the date.

⚠ **Never inferred from a green CRITERIA verdict.** The two answer different questions: CRITERIA asks
whether the checker behaves, OPERATIONAL asks whether a real file yields a usable result. A build may
ship on a CRITERIA fail if OPERATIONAL passes and the failures are named; it may **never** ship on an
OPERATIONAL fail. **`NOT MEASURED` is not a pass** — it means the question was not asked.

{Final verdict lines — CRITERIA and OPERATIONAL on separate lines, never combined}
```

## Phase 6.5: BRANCH ON VERDICT

### If PASS — invoke insight-promotion (learn from success)

A passing build often surfaces novel patterns worth codifying. Invoke `insight-promotion` to check:

```
Skill(skill="insight-promotion", args="source=.claude/PRPs/{slug}/ evaluate=PASS check_for=novel_mirror,novel_validate_agent,novel_shape_combo,recurring_anti_pattern")
```

The skill decides whether anything is promotion-worthy (per its own criteria — pattern recurred ≥2 times, prevents a known failure, etc.). If yes, it surfaces the candidate; user decides whether to codify. The pipeline learns from itself.

**Optionally calibrate the estimator.** Effort and calendar are never gates (Hard Rule 8), and calibration is a ledger record, not a completion step — run it only when the user asks or when the next plan will actually want the rate. If run: count the build's actuals from evidence (iteration-report timestamps, tasks flipped in `state.json`, keyboard hours with overnight and meeting gaps excluded), write the record, and run:

```
python3 .claude/skills/build-estimate/estimate.py calibrate .claude/PRPs/{slug}/estimate/actuals-{YYYY-MM-DD}.json
```

then promote `.claude/skills/build-estimate` so the canonical ledger carries the record. See the `build-estimate` skill for the record shape.

### If FAIL — invoke five-whys (don't just report; diagnose)

```
Skill(skill="five-whys", args="trigger=evaluate_fail slug={slug} verdict=<which criteria failed>")
```

The root-cause output goes into `evaluate.md` under a `### Root cause (five-whys)` section. Phase 1 globs prior `evaluate.md` files, so a later build on a similar slug reads this root cause directly — `build-validate` does not carry it, having no anti-pattern auditor.
