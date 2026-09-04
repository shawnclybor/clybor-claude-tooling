---
name: verify
description: Run the deterministic verification gate against a PRD's success criteria. Every criterion must map to a check that returns a green/red signal. Use after ralph-implement completes and before the quality-review evaluation stage. Triggers — "verify against the PRD", "run the verification", "check success criteria", "did we hit all the gates", "verify [feature]". Hand-waving green checks is the most common way to ship the wrong thing.
---

# Verify

Bridge between "code is written" and "feature is done." Every PRD success criterion must have a corresponding automated or scripted check that returns green. If a criterion can't be verified by a check, either the criterion is wrong (move to open questions) or a check needs to be written.

## When to use

- After `ralph-implement` completes its loop
- Before `quality-review` runs the Stage 6 evaluation
- Any time you need to answer "are the PRD criteria actually met?"

## When NOT to use

- Mid-implementation (run task-level checks via `ralph-implement` instead)
- For non-deterministic criteria — those belong in the evaluation stage, not verification

## Inputs

- **`prd_path`** — path to the PRD with the success criteria
- **`check_map`** — mapping of criterion to verification command. Format: `<criterion_text>: <command>`. Example: `P95 latency < 200ms: pytest tests/perf/test_latency.py -k p95`.
- (optional) **`evidence_dir`** — where to write per-criterion evidence (default `.verify/<feature_slug>/`)

## Output

`docs/PRDs/<feature_slug>-verification.md`:

```markdown
# <Feature title> — Verification

**PRD:** [<feature_slug>](./<feature_slug>.md)
**Run at:** <iso8601>
**Verdict:** PASS | FAIL | PARTIAL

## Criteria

| # | Criterion | Check | Result | Evidence |
|---|---|---|---|---|
| 1 | P95 latency < 200ms | `pytest tests/perf/test_latency.py -k p95` | PASS | [run-001.log](../.verify/<slug>/run-001.log) |
| 2 | Returns 400 on invalid email | `pytest tests/api/test_validation.py::test_invalid_email` | PASS | [run-002.log](../.verify/<slug>/run-002.log) |
| 3 | Cyclomatic complexity ≤ 8 in auth/ | `radon cc auth/ -a -nc` | FAIL | [run-003.log](../.verify/<slug>/run-003.log) |

## Failures (if any)

### Criterion 3 — Cyclomatic complexity ≤ 8 in auth/

`auth/token.py:refresh_token` has complexity 11. Top offender: nested conditional in `if not token.valid and not token.expired:`.

**Recommendation:** Extract token validity check into a single boolean predicate.
```

## The mapping rule (most important)

Every PRD success criterion → at least one check command. If a criterion has no check, do ONE of:

1. **Write the check** — usually the right answer. If the criterion is binary, a check exists.
2. **Reword the criterion** — if the original was vibes-shaped, the rewrite makes it checkable.
3. **Move the criterion to evaluation** — if it genuinely requires human judgment (UX feel, copy quality, design soundness), it doesn't belong in verification. Evaluation handles judgment.
4. **Strike the criterion** — only if the PRD was wrong and the user agrees.

Do NOT silently call a criterion "verified" without a check that returned green.

## Evidence per criterion

Each check's full output (stdout + stderr + exit code + timestamp) lands in `.verify/<feature_slug>/run-NNN.log`. The verification doc links to the evidence — anyone can re-run the check and reproduce.

This matters because Stage 6 quality-review reads the verification doc. If the evidence is missing, the reviewer can't tell whether "PASS" means "actually checked" or "self-graded as fine."

## Pre-flight checklist

Before running:

1. Has every PRD criterion been mapped to a check command?
2. Are check commands deterministic? (No flakes — if it flakes, fix the flake first.)
3. Is the workspace at the state ralph-implement left it? (Verify against the committed state, not a half-edited working tree.)
4. Does the evidence directory exist? (Create if not.)
5. Will I write the evidence files BEFORE updating the verification doc? (Order matters — doc references evidence.)

## Failure handling

A failed criterion does not auto-fix anything. Report the failure with:
- Which check command failed
- Where the evidence lives
- The smallest hint at the root cause (don't guess — cite the actual output)

Then stop and surface to the user. The next step is either return to `ralph-implement` with a narrower task list or update the PRD if the criterion was wrong.

## Agent passes — conditional, after the checks

Run these only once every deterministic check has been run and its evidence written. They are gates, not commentary: a **Critical** finding from any of them is treated exactly as a failed check, and the verdict is FAIL. Spawn whichever apply in one message.

Each condition is a real trigger, not a suggestion — if the condition holds and the pass did not run, the verification is PARTIAL, not PASS.

### Always, once the checks are green — `code-reviewer`

Catches what a green check does not: type-safety gaps, naming, structural debt in the code the checks just passed.

```
Agent(
  subagent_type="code-reviewer",
  description="Final read-only pass over verified implementation",
  prompt="Review the implementation files at <paths>. PRD criteria and their check results: <paste table>. The deterministic checks are already green — do NOT re-run or re-report them. Report correctness bugs, type-safety gaps, blast-radius misses, naming and structural debt, ranked, each with file and line. Mark each finding Critical / High / Medium / Low. Read-only, no edits."
)
```

### When the PRD carries a security-shaped criterion — `security-auditor`

Input validation, auth, secrets, injection, dependency surface. A deterministic check does not satisfy a security criterion on its own; this agent is the gate for it.

```
Agent(
  subagent_type="security-auditor",
  description="Audit the security-shaped PRD criteria",
  prompt="Security-shaped criteria from the PRD: <paste>. Code surface: <paths>. For EACH criterion, say whether the code actually satisfies it and name the file and line that decides it. Then report any vulnerability in that surface the criteria did not anticipate. Mark each finding Critical / High / Medium / Low. Read-only, no edits."
)
```

### When a criterion is cross-file or structural — `code-analyzer`

For example *"no module in `api/` imports from `db/` directly"* or *"all routes in `handlers/` register through the central router"*. A grep catches the obvious violations; this agent confirms the criterion holds at the structural level rather than the textual one.

```
Agent(
  subagent_type="code-analyzer",
  description="Trace cross-file criteria to confirm they hold structurally",
  prompt="Structural criteria: <paste>. Repo paths in scope: <paths>. For EACH criterion, trace the actual call and import paths and report HOLDS / VIOLATED with the file and line that decides it. A criterion satisfied textually but violated through an indirect path is VIOLATED — name the indirection. Read-only, no edits."
)
```

A `VIOLATED` verdict fails that criterion, whatever its grep-based check returned.

## Pass / fail summary

- **PASS** — every check returned green, and every applicable agent pass ran with no Critical finding
- **FAIL** — at least one check returned red, or an agent pass returned a Critical finding
- **PARTIAL** — some criteria pass and some have no check, or an applicable agent pass did not run (the verification is incomplete; either write the missing checks and run the pass, or document why they can't be)

Treat PARTIAL the same as FAIL — do not advance to Stage 6 with unmapped criteria.

## Anti-patterns

- **Self-grading** — "looks good" is not a verification result. Run the check.
- **Cherry-picking checks** — picking the easy criteria and skipping the hard ones. If a criterion can't be checked, surface it; don't hide it.
- **Stale runs** — running checks against an old build. Re-run after every implementation change.
- **Flaky checks counted as PASS** — a check that passes 80% of the time is not a check. Fix the flake or strike the check.

