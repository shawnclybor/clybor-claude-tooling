---
name: build-evaluate
description: Verify a completed build against the PRD's anchor case and success criteria. Runs the acceptance test and anchor-case check (serial across drivers sharing a write root), fans out 2-3 read-only cold-read agents (fresh-eyes, anti-scope-creep, drift-vs-mirror). On FAIL, auto-invokes five-whys for root-cause. On PASS with novel patterns, invokes insight-promotion to codify learnings. Read-only against the built artifact, idempotent — safe to re-run. Use after build-execute reports success. Triggers — "evaluate the build", "did it work", "verify the build", "acceptance test", "is it actually done". Outputs `.claude/PRPs/{slug}/evaluate.md` with a binary verdict.
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

## Phase 3+4: RUN ACCEPTANCE TEST + ANCHOR CASE

⚠ **SERIAL BY DEFAULT. Parallelize only where the write roots are certified disjoint.**
"Independent" does not mean "measures a different thing" — it means **no two concurrently-running
drivers WRITE the same tree**. A driver that invokes a generator and then reads back what it
generated is NOT independent of another driver doing the same: they interleave, and each asserts
against a tree the other is rewriting. The run still prints PASS/FAIL, so the damage is invisible —
the result is **UNMEASURED, not failed**, and unmeasured results that look green are how a build
ships on evidence it never had.

**Before launching anything**, resolve each driver the plan names to (a) the generator it invokes and
(b) the root that generator writes. Drivers sharing a root run ONE AT A TIME, in the order the plan
lists them. Only drivers over disjoint fixtures run together, in one message.

- Acceptance test from the plan — serial across drivers sharing a write root
- Anchor case check (run the artifact against the PRD's one concrete example, compare output to expected outcome)

⚠ **A killed generator can leave its tree half-written.** Prefer letting one finish over killing it.
Where the generator rebuilds from inputs held OUTSIDE the tree it writes, one full serial run is both
the repair and the measurement — no separate repair step is needed.

⚠ **If you must stop a job, verify it is GONE — a signal is not a stop.** A script whose
`trap cleanup ... TERM` handler does not call `exit` runs the handler and RESUMES; if that handler
deletes the scratch the run measures against, the run continues and keeps reporting rows it can no
longer have measured. Measured 2026-09-10 on `run-mutations.sh`. After any kill, `ps` for the
process; if it survived, SIGKILL is the honest signal where the script owns only disposable scratch.

Anchor case PASS = output matches the PRD's expected outcome (exact OR fuzzy per criteria the PRD specified — PRD is the contract).


## Where the rest lives (read the file for the phase you are in)

| Phase / topic | Read |
|---|---|
| Phase 5 cold-read fan-out (read-only rule, three named agents) and Phase 5.5 synthesize | `references/cold-read-and-synthesis.md` |
| Phase 6 report template, two verdicts, Phase 6.5 branch on PASS / FAIL | `references/report-and-verdict-branch.md` |
| Phase 7 user verdict gate and final Output block | `references/verdict-gate-and-output.md` |

## Guidelines

- This skill is the only one authorized to mark a build `complete`. Execute reports success; evaluate confirms it.
- The anchor case is non-negotiable. A build that passes generic criteria but fails the anchor case is FAIL.
- Idempotent — re-running is always safe and recommended after any change to the artifact.
- Do NOT edit the artifact under test. Only the report and the PRD's status.
