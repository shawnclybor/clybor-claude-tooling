---
name: build-execute
description: Bounded execution loop for a validated build plan. Hard caps on iterations, edits, and (where applicable) spend prevent runaway loops. Each iteration runs a CONDITIONAL adversarial review (only when the change touches a contract, a pinned constant, a refusal limb, or an unmutated path), applies the edit, measures via parallel fixture runs, and auto-invokes five-whys on stagnation or regression. Calls writing-quality on prose edits. Stops on success, on cap hit, on stagnation, or on regression. Use after build-validate PASSes, before build-evaluate. Triggers — "execute the build", "build it", "iterate the X", "implement the plan". Refuses to start if validate has not PASSed or if hard preconditions from the profile are unmet.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, Skill, AskUserQuestion, mcp__sequential-thinking__sequentialthinking
user-invocable: true
argument-hint: "<slug> [--max-iterations N] [--dry-run] [--autonomous]"
---

# Build Execute

Bounded execution loop. The scheduler and budgeter; per-iteration work is delegated.

## Hard preconditions (REFUSE if unmet)

- `.claude/PRPs/{slug}/prd.md` exists
- `.claude/PRPs/{slug}/plan.md` exists
- `.claude/PRPs/{slug}/validate.md` exists AND `### Verdict\nPASS` appears in it
- Profile's hard preconditions (defined in the profile) are met
- No prior `.claude/PRPs/{slug}/state.json` is in `state: running` (refuse double-runs)

If any precondition fails: stop, list the failures, do nothing else.

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

Why: the first edit commits the direction. If the plan says "rewrite SKILL.md prose for clarity" but Shawn realizes the actual issue is the trigger phrasings, this is the cheapest moment to course-correct.

Skip this gate if `--autonomous` was passed (e.g., for scheduled/batch runs).

## Per-iteration workflow

For iteration N (N starts at 1):

### Step 1 — READ STATE

Read prior iteration report if N > 1 (at `.claude/PRPs/{slug}/iterations/{N-1}.md`). Otherwise read the plan's "Step-by-step tasks" section for the iteration-1 starting point.

### Step 2 — DECIDE THE CHANGE (champion fan-out if ambiguous)

Identify ONE specific change to apply this iteration. Sources for the change, in priority order:

1. The next pending task from the plan (single-shot or pipeline shape).
2. The highest-severity finding from the prior iteration's per-iteration review (iterative-bounded shape).
3. User-supplied instruction (if user provided one with the invocation).

**If multiple candidate changes are tied in priority** (common in iterative-bounded shape when adversarial review surfaces 2-3 must-fixes), spawn champion agents in parallel — one per candidate — to argue for its choice. Synthesize the best argument:

```
# Spawn N agents in one message, one per candidate:
Agent(subagent_type="general-purpose", description="Champion: {candidate-1}", prompt="Argue why {candidate-1} is the right change for iteration {N}. Context: <PRD anchor + plan + prior iteration measurements>. One paragraph, end with confidence 0-1.")
Agent(subagent_type="general-purpose", description="Champion: {candidate-2}", prompt="<same shape for candidate 2>")
# ... up to 3
```

Use `mcp__sequential-thinking__sequentialthinking` to synthesize and pick the winner. Express the chosen change as a one-paragraph plan.

### Step 3 — PRE-EDIT BASELINE (iterative-bounded shape only, parallelized)

Capture the current state of the acceptance metric. If the profile names >1 fixture, run them in parallel via concurrent Bash calls (one per fixture in a single message). For single-shot / pipeline / wrapper shapes, skip this step.

### Step 4 — ADVERSARIAL REVIEW (CONDITIONAL — see the trigger list)

⚠ **This was MANDATORY on every iteration until 2026-09-01 and is now conditional.** Reviewing every
line change is the same pathology as re-panelling every plan revision, one scale down: it manufactures
findings proportional to the edits it just reviewed, and on a build with a mutation-backed suite it
re-derives what the mutations already prove. Once the harness can fail, **the harness is the reviewer**.

Run the per-iteration adversarial review when — and only when — the proposed change does one of:

- **changes a contract** — what a field means, what a function promises, what a writer may emit
- **moves a pinned constant** — a threshold, a hash pin, a closed enum, a blocking-type set, an
  assertion floor
- **adds a refusal limb**, or changes the conditions of an existing one
- **touches a path with no mutation covering it** — if nothing would go red when this is broken,
  a reviewer is the only detector you have

Otherwise **skip it and go straight to apply-and-measure.** A change that adds a case to a covered
path, adjusts a message, or extends a fixture is already guarded; the suite plus the mutation run is
a stronger signal than an opinion about a diff, and it costs seconds.

Record which branch each iteration took in the iteration report. An iteration that skipped the
review says so — never silently.

When it does run: spawn the profile's reviewer on the proposed change BEFORE applying. Must-fix
blocks the iteration; the change goes back to Step 2 with the finding added to the candidate set.

⚠ **If the suite has no mutation harness proving it can fail, every iteration takes the review.**
An unfalsifiable green suite is not a reviewer, and the conditional above assumes one that is.

### Step 4.5 — WRITING QUALITY PASS (if edit touches prose)

If the proposed edit modifies prose-heavy content (SKILL.md body, deliverable text, README, doc, judge prompt rubric), invoke `writing-quality` skill (rewrite mode) on the proposed text BEFORE applying. This is the same gate CLAUDE.md Rule 4 enforces for client-facing prose; applies equally to artifact prose.

```
Skill(skill="writing-quality", args="rewrite <proposed prose change>")
```

Skip if the edit is to code only (JSON, YAML frontmatter, scripts).

### Step 5 — APPLY THE EDIT + TICK THE PLAN CHECKLIST

Make the actual file changes. The change must match what was planned in Step 2 (and rewritten by Step 4.5 if invoked) verbatim — no scope creep mid-iteration.

**Then update the plan's checklist in place.** For each `- [ ]` item in `plan.md` "Step-by-step tasks" that the edit completed, flip it to `- [x]`. Do the same in "Acceptance checklist" if this iteration moved any criterion from unmet to met. The plan is the source of truth for "what's left" — the checklist is how that's read at a glance.

### Step 6 — POST-EDIT MEASUREMENT (parallelized)

Run the acceptance test from the plan (or the per-iteration check the profile defines). If multiple fixtures, run them in parallel (same pattern as Step 3). Capture each result.

### Step 7 — DECIDE: CONTINUE / STOP

Compare post-edit measurement to pre-edit baseline (or to acceptance bar for single-shot):

- **Acceptance bar met** → stop with success. Skip remaining iterations.
- **Measurable improvement, bar not yet met** → continue to next iteration.
- **No measurable change** → stagnation +1. **If stagnation_count reaches 2, invoke `five-whys` BEFORE the third strike** to root-cause whether the plan's change set is even the lever. Pass the iteration reports as input. The five-whys output may justify stopping, may justify continuing with a different change set, or may surface a deeper plan-level issue.
- **Regression** → stop AND invoke `five-whys` to root-cause the regression. **Then present an explicit choice to the user** (REVIEW GATE — skip only with `--autonomous`):

```
# Step 1: diagnose (always)
Skill(skill="five-whys", args="trigger=<stagnation|regression> slug={slug} iterations=<paths to iteration reports>")

# Step 2: gate (unless --autonomous)
AskUserQuestion:
  Question: "Regression detected in iteration {N}. Pre-edit measurement: {X}. Post-edit: {Y}. Five-whys root cause: {summary}. How to proceed?"
  Options:
    - "Revert iteration {N}" → undo the edit, leave state at iteration {N-1}, mark run stopped
    - "Continue with different change" → return to Step 2 with the original candidate REMOVED from the candidate set
    - "Accept regression and stop" → leave edit, mark run stopped, user will manually fix later
    - "Abort run entirely" → revert all iterations (1..N), mark run aborted
```

Without the gate, the loop would silently stop after diagnosis — the user loses agency over revert / continue / abort. The five-whys output informs the choice; the user makes it.

Same gate applies on stagnation_count == 2 (before strike 3): five-whys first, then ask "Continue with a different change set / Stop and re-plan / Abort."

### Step 8 — WRITE ITERATION REPORT

Write `.claude/PRPs/{slug}/iterations/{N}.md`:

```markdown
## Iteration {N}

**Change applied:** {one paragraph}
**Files touched:** {list}
**Pre-edit measurement:** {value or N/A}
**Post-edit measurement:** {value}
**Delta:** {improvement / same / regression}
**Stagnation count:** {N}
**Decision:** {continue / stop-success / stop-stagnation / stop-regression / stop-cap}

### Plan checklist state (after this iteration)

Step-by-step tasks:
- [x] {tasks flipped this iteration}
- [x] {tasks flipped in prior iterations — preserved}
- [ ] {tasks still open}

Acceptance checklist:
- [x] {criteria now met}
- [ ] {criteria still unmet}

**Flipped this iteration:** {count of `- [ ]` → `- [x]` in this run}
**Remaining open:** {count of `- [ ]` still unticked}
```

The plan.md itself is updated in Step 5. This report mirrors the current state so the per-iteration history shows how the checklist closed over time.

## State tracking

Write `.claude/PRPs/{slug}/state.json` continuously:

```json
{
  "slug": "{slug}",
  "state": "running | success | stopped",
  "iterations_completed": N,
  "iterations_max": N,
  "stagnation_count": N,
  "cumulative_spend": 0.0,
  "last_measurement": {...},
  "started_at": "{ISO}",
  "finished_at": "{ISO or null}"
}
```

State is the source of truth for re-entry. If the loop is interrupted mid-iteration, re-invocation reads state and resumes (or refuses if `state: running` and the heartbeat is stale).

## Output

```
## Execute Run: {slug}

**Final state:** success / stopped
**Iterations completed:** {N}/{cap}
**Final measurement:** {value}
**Acceptance bar:** {target}
**Bar met:** yes / no
**Iteration reports:** .claude/PRPs/{slug}/iterations/

### Next step
{If success}: Verify with `build-evaluate {slug}` — offer to dispatch via `Skill(skill="build-evaluate", args="{slug}")` if user confirms.
{If stopped via five-whys}: The five-whys report at `.claude/PRPs/{slug}/iterations/five-whys-{ISO}.md` names the root cause. Decide — fix at the plan level (re-run `build-plan`) or accept partial progress.
```

## Dry-run mode

`--dry-run` prints the iteration plan (what would happen) without applying edits or spending budget. Useful for sanity-checking the loop's decision logic before committing.

## Guidelines

- The loop NEVER bypasses the acceptance bar to "ship it." Acceptance comes from the PRD's anchor case + success criteria; the loop is not authorized to redefine them mid-run.
- One change per iteration. Bundling multiple changes hides which one moved the metric.
- Stagnation is not failure — it's a signal that the plan's current change set isn't the lever. Stop and re-plan.
- This skill does NOT decide what the artifact does long-term. It executes the plan as written.
