---
name: build-evaluate
description: Verify a completed build against the PRD's anchor case and success criteria. Runs the acceptance test and anchor-case check in parallel, fans out 2-3 cold-read agents (fresh-eyes, anti-scope-creep, drift-vs-mirror). On FAIL, auto-invokes five-whys for root-cause. On PASS with novel patterns, invokes insight-promotion to codify learnings. Read-only against the built artifact, idempotent — safe to re-run. Use after build-execute reports success. Triggers — "evaluate the build", "did it work", "verify the build", "acceptance test", "is it actually done". Outputs `.claude/PRPs/{slug}/evaluate.md` with a binary verdict.
allowed-tools: Read, Bash, Grep, Glob, Agent, Skill, AskUserQuestion, mcp__sequential-thinking__sequentialthinking
user-invocable: true
argument-hint: "<slug>"
---

# Build Evaluate

Verify a build against its own definition of "done."

## Phase 1: PARSE + PARALLEL LOAD

**Batch in one message** — independent reads:
- `Read` `.claude/PRPs/{slug}/prd.md`, `plan.md`, `state.json`
- `Read` `.claude/PRPs/_profiles/{type}.md` (from PRD frontmatter)
- `Glob` `.claude/PRPs/*/evaluate.md` — for insight-promotion later, find prior similar builds for pattern matching

Verify:
- `state.json` `state` is `success` or `stopped` (not `running`) — refuse to evaluate a build still iterating
- PRD has a concrete anchor case
- Plan has an acceptance test defined

If anchor case or acceptance test is missing: refuse and tell the user to update the PRD/plan first.

## Phase 2: LOAD PROFILE

The profile may define:
- A canonical acceptance-test invocation (e.g., `python3 scripts/validate-plugin.py path/to/plugin`)
- A fixture set the build must run against
- A specific reviewer agent to run as a final cold-read pass

## Phase 3+4: RUN ACCEPTANCE TEST + ANCHOR CASE (parallelized)

**Run in parallel** in one message — these are independent measurements:
- Acceptance test from the plan (across all profile fixtures, themselves parallelized via concurrent Bash calls)
- Anchor case check (run the artifact against the PRD's one concrete example, compare output to expected outcome)

Anchor case PASS = output matches the PRD's expected outcome (exact OR fuzzy per criteria the PRD specified — PRD is the contract).

## Phase 5: COLD-READ FAN-OUT (2-3 agents in parallel)

Spawn cold-readers **in one message**. Each has NOT seen the iteration history; each looks from a different angle. This catches "we iterated ourselves into a corner" cases the cold-read agent in build-execute can't see.

Each cold-reader is a **named agent**, not `general-purpose` — the three angles below are three agents' standing lenses, and a generic reader invents its own. Every prompt is findings-only: this skill does not edit the artifact under test.

### Cold-reader 1 — Fresh-eyes (profile-defined if present, else `adversarial-reviewer`)

If the profile defines `evaluate_cold_read_agent`, use it. Otherwise:

```
Agent(
  subagent_type="adversarial-reviewer",
  description="Fresh-eyes cold-read of finished artifact",
  prompt="Read the artifact at <path> for the first time. Do NOT read iteration history. PRD: <paste>. Answer: (1) what does this artifact actually do, in your words? (2) match/drift/mismatch vs PRD 'What this is'? (3) obvious gaps or undefined references? The question is whether the artifact supports the claim the PRD makes about it — not whether the PRD is a good idea. Findings only — no edits."
)
```

### Cold-reader 2 — Anti-scope-creep (`simplifier`)

Growth past the stated scope is the KISS/YAGNI lens, which is this agent's whole charter.

```
Agent(
  subagent_type="simplifier",
  description="Audit artifact against PRD out-of-scope list",
  prompt="Read the artifact at <path>. PRD out-of-scope list: <paste>. For each out-of-scope item, scan the artifact for accidental inclusion and flag matches with the specific artifact line/section. Then flag anything the artifact does that no PRD criterion asked for. Do not propose removing in-scope features — scope creep only. Findings only."
)
```

### Cold-reader 3 — Drift-vs-mirror (`code-analyzer`)

Structural divergence across two files is a tracing job. Applies to code and to structured prose alike — the check is the shape, not the language.

```
Agent(
  subagent_type="code-analyzer",
  description="Audit artifact against mirror target structure",
  prompt="Read the artifact at <path> and the mirror target at <mirror path>. Find places the artifact diverges from the mirror's pattern without justification, citing file and line on both sides. Drift may be intentional (note it) or accidental (must-fix). Do not grade the mirror itself. Findings only."
)
```

## Phase 5.5: SYNTHESIZE (sequential thinking)

Use `mcp__sequential-thinking__sequentialthinking` to combine the three cold-read outputs with the acceptance-test and anchor-case results. Compute the binary verdict.

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

## Phase 7: USER VERDICT GATE (REVIEW GATE — skip with `--autonomous`)

Don't silently flip PRD status. The verdict is computed; the disposition is the user's call.

### If verdict is PASS — confirm before marking complete

Print the full evaluate.md summary (per-criterion table, anchor case result, cold-read findings, insight-promotion candidate if any). Then:

```
AskUserQuestion:
  Question: "Build PASS for {slug}. All criteria pass + anchor case pass. Mark PRD status `complete`?"
  Options:
    - "Yes, mark complete" → flip PRD status, add evaluated_at
    - "Re-run evaluate" → loop back to Phase 3 (acceptance test was flaky or env changed)
    - "Keep as planning (more work to do)" → leave PRD at planning, do NOT mark complete
    - "Promote candidate first" (if insight-promotion surfaced one) → dispatch insight-promotion, then re-prompt
```

### If verdict is FAIL — surface next-action choices

Print the full evaluate.md summary including the five-whys root-cause section. Then:

```
AskUserQuestion:
  Question: "Build FAIL for {slug}. Root cause (five-whys): {summary}. Next action?"
  Options:
    - "Plan revision" → print build-plan invocation hint with the failed criteria as input
    - "Targeted fix iteration" → offer to dispatch Skill(skill="build-execute", args="{slug} --max-iterations 1")
    - "Accept partial — this is good enough" → keep PRD at planning, exit cleanly
    - "Investigate further (debug session)" → print pointers to iteration reports + five-whys output, exit
```

Skip both gates if `--autonomous` was passed — PASS auto-marks complete; FAIL leaves PRD at planning and exits.

## Output

```
## Evaluation Complete: {slug}

**Verdict:** PASS / FAIL
**Anchor case:** PASS / FAIL
**Criteria passed:** {N}/{total}
**Report:** .claude/PRPs/{slug}/evaluate.md

### Next step
{If PASS}: Build is done. If insight-promotion surfaced a candidate, decide whether to codify. Otherwise — promote to plugin / ship / close the Notion task.
{If FAIL}: Review evaluate.md including the root-cause section. Decide — plan revision (`build-plan {slug}`) or targeted fix (`build-execute {slug} --max-iterations 1`).
```

## Guidelines

- This skill is the only one authorized to mark a build `complete`. Execute reports success; evaluate confirms it.
- The anchor case is non-negotiable. A build that passes generic criteria but fails the anchor case is FAIL.
- Idempotent — re-running is always safe and recommended after any change to the artifact.
- Do NOT edit the artifact under test. Only the report and the PRD's status.
