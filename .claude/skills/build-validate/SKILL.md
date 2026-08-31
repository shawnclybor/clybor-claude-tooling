---
name: build-validate
description: Multi-agent validation gate for a build plan BEFORE any execution spend. Spawns 4-5 reviewer agents in parallel — adversarial reviewer (ambiguity), pattern auditor (mirror drift), completeness auditor (PRD criteria → plan tasks coverage), anti-pattern auditor (recurring failures from prior FAIL evaluations), and a profile-specific auditor where applicable. Read-only. Outputs a must-fix / should-fix / note table. PASS = zero must-fix. If ≥3 prior validate FAILs exist for similar slugs, auto-invokes five-whys before reporting. Use after build-plan, before build-execute. Triggers — "validate the plan", "review before executing", "is the plan good", "ready to execute".
allowed-tools: Read, Grep, Glob, Agent, Skill, AskUserQuestion, mcp__sequential-thinking__sequentialthinking
user-invocable: true
argument-hint: "<slug> matching an existing plan"
---

# Build Validate

Read-only validation gate. Spawns reviewers in parallel and synthesizes their findings.

## The rubric — read this BEFORE briefing any reviewer

**Gates catch breakage, not findings** (repo `CLAUDE.md` Hard Rule 9). This gate stops a plan that is
*broken*. It does not enumerate what a careful reader could improve.

**`must-fix` has exactly one definition:**

> it produces a **wrong result a human relies on**, or it lets the tool **claim something it has not
> verified**.

Everything else is a **note**, however well-measured. A finding can be perfectly true and still not worth
the build's time. **"True" is not "important"** — conflating them is how a review loop runs forever. Brief
every reviewer with this definition explicitly; without it they default to "anything I can justify."

**Never in scope as a finding:** calendar, effort, hours, or any estimate (Hard Rule 8). Schedule is the
human's call, per instance.

## When to use

- A plan exists at `.claude/PRPs/{slug}/plan.md` and you're about to invoke build-execute.
- Re-validating after a major plan revision.

## When NOT to use — the stage rule

- Mid-execute prompt tweaks — that's build-execute's per-iteration adversarial review step, not this skill.
- The plan is still drafting (PRD status ≠ `planning` or `approved`). Finish build-plan first.
- ⚠ **The system already runs and carries a live test suite.** This gate earns its cost on greenfield,
  where nothing runs and mistakes compound. Once the guardrails exist and the suite is green, **rapid
  build/test rounds catch more per hour than another reviewer panel** — the harness is the reviewer. Run
  the thing dozens of times instead. A clean git tree makes revert cheap, which is what licenses the speed.
- ⚠ **The work is hardening, not shipping.** "PASS = zero must-fix" against a large plan of optional
  polish is unpassable by construction: a careful reader always finds a success condition a hypothetical
  careless implementer could game. Use the consequence test above, or don't run this gate.

## ⚠ Stop rule — the SECOND FAIL is a process defect, not a target defect

**This is the `Two Strikes` hard rule in `CLAUDE.md` applied to review panels — CLAUDE.md holds the one
true copy; this section only says what "the same op" means here.** Do not restate Two Strikes' reasoning
below — a second copy drifts from the first, and a heading that disagrees with its own body sends a
skimmer one panel past the stop.

**The op is one panel run against one target. Two FAILs on the same target = Two Strikes = STOP.**
So after the **second** FAIL, do **not** run a third panel. Stop, report that the gate itself is suspect,
and put the scope to the human. Run `.claude/hooks/review-drift.py check <target>` first and **heed its
verdict rather than logging past it** — it catches ratchet, inflation, self-inflicted findings and
re-grades. That drift check is this domain's substitute for Two Strikes' "research before you report" step.

Distinguish two shapes before recommending anything, because the fixes are opposite:
- **Ratchet** — *new* complaints each pass. Fix: stop reviewing.
- **Persistent identical findings** — the same items surviving verbatim. Fix: go repair, or cut the scope.

Worked example — note this is the rule being **violated**, which is how it was found; the stop should have
come after the second FAIL. `build-a-yellow-sheet` rounds 7–9 (2026-08-30): three FAILs, 17 → 17 → 24 must-fix, on a
build already running end to end on two real client matters with a green 475-assertion suite. **Not one of
the 24 changed a figure, a flag, or anything a reader of the sheet sees.** Resolution was neither "stop
reviewing" nor "go repair" — it was **cut the scope**, seven tasks to two. Full account:
`mem:gate_philosophy`.

## Phase 1: PARSE + PARALLEL LOAD + PRIOR-FAIL DISCOVERY

**Batch in one message** — independent reads:
- `Read` `.claude/PRPs/{slug}/plan.md`, the linked PRD (`prd_ref`), the mirror target, and the profile
- `Glob` `.claude/PRPs/*/evaluate.md` to find prior FAIL verdicts on similar target types
- Spawn `Agent(subagent_type="Explore", description="Find prior validate FAILs for similar builds", prompt="Search .claude/PRPs/*/validate.md and *.md for FAIL verdicts on builds whose target_type matches {type}. Return the top 5 recurring must-fix categories.")` — runs in parallel with the reads since it has no dependency on them

If any required file is missing, stop and report.

## Phase 2: META-CHECK (recurring failures)

If the Explore agent returns ≥3 recurring must-fix categories: **invoke `five-whys`** BEFORE running the parallel reviewers. Recurring failures across builds suggest a process gap, not a one-off plan bug.

```
Skill(skill="five-whys", args="recurring_must_fix_categories=<list from Explore output>")
```

The five-whys output becomes additional input for the reviewers below (they should know what patterns to flag).

## Phase 3: PARALLEL REVIEW (4-5 agents in one message)

Spawn ALL reviewers in a SINGLE message. Per CLAUDE.md routing, when spawning multiple subagents, load `subagent-governance` first if you don't have it loaded.

### Agent 1 — Adversarial reviewer (general-purpose)

```
Agent(
  subagent_type="general-purpose",
  description="Adversarial review of build plan",
  prompt="""You are an adversarial reviewer for a build plan.

PRD: <paste full PRD>
Plan: <paste full plan>
Mirror target excerpt: <paste relevant sections of the mirror>

Find every place where:
1. The plan is ambiguous — a careful reader could implement two different things from the same sentence.
2. The acceptance test in the plan doesn't actually verify the PRD's anchor case.
3. A step says "improve X" or "finalize Y" or "polish Z" without a binary DONE check.
4. The plan invents new structure where the mirror target has an existing pattern that fits.
5. The plan promises something the PRD did not require (scope creep) OR misses something the PRD did require.

Output: numbered findings, each tagged must-fix / should-fix / note.
End with one-line verdict: counts + PASS or FAIL recommendation.
DO NOT propose edits. Findings only."""
)
```

### Agent 2 — Pattern auditor (general-purpose)

```
Agent(
  subagent_type="general-purpose",
  description="Audit plan against mirror target pattern",
  prompt="""You are auditing whether a build plan correctly mirrors an existing pattern.

Mirror target: <path>
Mirror sections to inspect: <list from plan>
Plan: <paste full plan>

Cross-check:
1. Every section of the mirror target the plan claims to copy IS represented in the plan.
2. Any section the plan adds beyond the mirror has a justification in the plan body.
3. Naming conventions (frontmatter keys, file paths, function names) match the mirror.
4. Anti-patterns called out in the mirror's own comments/docs are not reintroduced.

Output: numbered findings, each tagged must-fix / should-fix / note.
End with one-line verdict."""
)
```

### Agent 3 — Completeness auditor (general-purpose)

```
Agent(
  subagent_type="general-purpose",
  description="PRD-criteria → plan-tasks coverage check",
  prompt="""You are checking whether every PRD criterion has a corresponding plan task and acceptance check.

PRD success criteria: <paste from PRD>
PRD anchor case: <paste from PRD>
PRD out-of-scope: <paste from PRD>
Plan step-by-step tasks: <paste>
Plan acceptance test: <paste>

For each PRD criterion: name the plan task(s) that address it AND the acceptance check that verifies it. Flag missing coverage as must-fix.

For the anchor case: confirm the acceptance test exercises it explicitly. If not, must-fix.

For each out-of-scope item: scan the plan for accidental inclusions. Must-fix if any task implements something explicitly out-of-scope.

Output: numbered findings, each tagged must-fix / should-fix / note. End with one-line verdict."""
)
```

### Agent 4 — Anti-pattern auditor (general-purpose, parallel)

```
Agent(
  subagent_type="general-purpose",
  description="Anti-pattern check against recurring failures",
  prompt="""You are auditing a plan against known anti-patterns.

Plan: <paste>
Profile anti-patterns: <paste from profile 'Anti-patterns to avoid' section>
Recurring failure categories from prior builds: <paste from Phase 1 Explore output>
Five-whys output (if Phase 2 ran): <paste or N/A>

For each anti-pattern: scan the plan for accidental reintroduction. Flag matches as must-fix with the specific plan line.

Output: numbered findings tagged must-fix / should-fix / note. End with one-line verdict."""
)
```

### Agent 5 — Profile-specific auditor (if profile defines one)

Skip if profile has no `validate_agent_3` (preserving the original naming) reviewer definition.

## Phase 4: SYNTHESIZE (sequential thinking)

Use `mcp__sequential-thinking__sequentialthinking` to:
- Deduplicate overlapping findings across the 4-5 agents
- Note contradictions explicitly (rare — flag them)
- Categorize each unique finding by severity
- Cross-reference with the five-whys output (if Phase 2 ran) — recurring-failure findings get extra weight

## Phase 5: REPORT

Write `.claude/PRPs/{slug}/validate.md`:

```markdown
## Validation: {slug}

### Must-Fix ({N})
| # | Issue | Source | Where in plan |
|---|-------|--------|---------------|

### Should-Fix ({N})
| # | Issue | Source | Where |

### Note ({N})
| # | Issue | Source | Where |

### Verdict
{PASS / FAIL}

PASS = zero must-fix **under the consequence test at the top of this skill** — a wrong result a human
relies on, or the tool claiming something it has not verified. Findings that fail that test are notes and
do **not** block. FAIL = ≥1 must-fix that meets it; do not proceed to execute until addressed.

⚠ If the must-fix list is long and none of its items changes a figure, a flag, or anything a user sees,
the verdict is **PASS with notes** and the finding to report is that **the scope is too large for the
value** — not that the plan is broken.

### Per-agent verdicts
- Adversarial: {N} must-fix
- Pattern auditor: {N} must-fix
- Completeness auditor: {N} must-fix
- Anti-pattern auditor: {N} must-fix
- Profile auditor: {N} must-fix or N/A

### Meta-check (Phase 2)
Five-whys invoked: yes (recurring failures: {list}) / no
```

## Output

If FAIL: present findings, recommend revising the plan via build-plan or direct edit. Do NOT auto-edit the plan.

If PASS: **explicit user gate before dispatching execute** (unless `--autonomous` was passed).

Print the validation summary (must-fix=0, should-fix={N}, notes={N}) and use `AskUserQuestion`:

```
Question: Validation PASSED for {slug}. Proceed to build-execute now?
Options:
- "Yes, execute now" → dispatch via Skill(skill="build-execute", args="{slug}")
- "Yes, but adjust caps first" → ask follow-up for --max-iterations N, then dispatch
- "No, let me review validate.md first" → print the path, stop
- "No, revise the plan" → print path to build-plan invocation hint, stop
```

Why: execute applies real edits and (where applicable) burns API spend. A PASS verdict means "internally consistent," NOT "Shawn endorses this plan." The user reads validate.md, weighs the should-fix and notes, and decides.

Skip this gate if invocation included `--autonomous` — in that case auto-dispatch with default caps.

## Guidelines

- This skill is READ-ONLY. It does not edit the plan, the PRD, or any artifact.
- All reviewer agents run in parallel in a single message. Sequential calls violate the parallel-agent norm.
- The user decides what to do with should-fix and notes. Don't pre-empt.
- A PASS verdict means the plan is internally consistent — NOT that the build will succeed. Execute still runs the acceptance test.
