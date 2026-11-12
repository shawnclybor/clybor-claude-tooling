<!-- build-execute reference: Step 8, state tracking, output, session report, dry-run, guidelines (moved verbatim from SKILL.md) -->
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

## The session report — what the HUMAN reads

⚠ The block above is the machine record. This is the report you give the person paying for the
build, and it has a **fixed shape**. Adopted 2026-09-02 after a session where the owner had to ask
"what's the overall status?" mid-run and then "is any of this a big deal or just a formality?" —
both questions are symptoms of a report that buried the decisions in the findings.

**No jargon. Ever.** Not "mutation harness", "refusal limb", "per_source", "fail-closed". If a
sentence needs a term the owner would not use at dinner, rewrite the sentence. Name the money, the
document, and the person affected instead.

### 1. Executive summary — 3 to 5 lines

What moved, in plain terms. Lead with the thing the owner actually asked for and whether it
happened. One line of hard numbers (tests, gates) — not a table.

### 2. What I need from you

The section that matters most, and the one most often written wrong. **Rules:**

- **Every item carries a verdict and a time cost.** `**This is the big deal.**` /
  `**This is a formality.** ⏱️ 30 seconds` / `**Your call, low risk.**` The owner is triaging;
  do the triage for them.
- **Say plainly what does NOT need them.** A list of three asks reads like a list of three problems
  unless you close it with "nothing else needs you — the dangerous one is mine to fix."
- **Escalate what is genuinely theirs, and NOTHING else.** A target that no longer matches what the
  build produces, a scope decision, a gate you were told to skip. Never pad this section with work
  you could just do.
- ⚠ **Never silently repair a TARGET.** If the PRD's number is now wrong, say so and ask — do not
  edit it and report success. Changing the target after seeing the result is how a build grades its
  own homework, and it is this repo's recorded failure mode. Say that reason out loud; owners
  respect it and it explains why you are asking instead of acting.
- **One word should be enough to answer each.** "Build it or cut it." "Say update them."

### 3. The sequence

A table of **rounds, not tasks.** A remaining-task count is a lie about effort — group the work by
what ships together, and **mark the row where the thing is actually done**:

| Round | Work | What it buys |
|---|---|---|
| 1 | … | … |
| — | — | **⬅ The demo is done here.** |

Then one line separating what is the deliverable from what is completeness.

⚠ **If a required piece is missing from the plan entirely, that is the headline of this section**,
not a footnote. Say "one required piece isn't on the list at all" and name it.

### 4. General thoughts — your call, no jargon

A short closing section, unstructured, entirely the model's judgement. Use it for the thing the
owner should know but did not ask about: an honest note on pace, a risk that is not yet a decision,
something the measurements suggest about the work ahead. **Not a summary of the above.** If there is
nothing worth saying, leave it out rather than padding it.

### On pace, when the owner is frustrated

Answer straight, once, factually — what took the time and why. Do not grovel, do not get defensive,
and do not bury it. Then move to the sequence. ⚠ If tasks were bugs rather than features, **say so
and say what the bug would have cost** — "a subrogation vendor was being printed as a doctor on a
settlement sheet" is information; "I fixed 3 defects" is not.

## Dry-run mode

`--dry-run` prints the iteration plan (what would happen) without applying edits or spending budget. Useful for sanity-checking the loop's decision logic before committing.

## Guidelines

- The loop NEVER bypasses the acceptance bar to "ship it." Acceptance comes from the PRD's anchor case + success criteria; the loop is not authorized to redefine them mid-run.
- One change per iteration. Bundling multiple changes hides which one moved the metric.
- Stagnation is not failure — it's a signal that the plan's current change set isn't the lever. Stop and re-plan.
- This skill does NOT decide what the artifact does long-term. It executes the plan as written.
