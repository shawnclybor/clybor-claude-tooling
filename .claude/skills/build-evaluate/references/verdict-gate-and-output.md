<!-- build-evaluate Phase 7 and Output, moved verbatim from SKILL.md -->

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
