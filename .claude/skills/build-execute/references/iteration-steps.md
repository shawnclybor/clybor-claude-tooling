<!-- build-execute reference: per-iteration workflow, Steps 1-7 (moved verbatim from SKILL.md) -->
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

⚠ **Capture the WHOLE output; trim only when you display it.** A log cut with `tail -N` at write
time loses whatever printed above the cut, and a parser over it then reports the value as absent —
which reads exactly like a failed build. Measured 2026-09-10: a corpus log trimmed to 12 lines
dropped the per-matter table, and the closing check printed the anchor NOT MET while the same
number sat in the driver's own tally line and in the records the probes read. A verdict-bearing
check gets a second witness that reads the artifact directly; on a failed check the first question
is whether the measurement failed or the reading of it.

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

