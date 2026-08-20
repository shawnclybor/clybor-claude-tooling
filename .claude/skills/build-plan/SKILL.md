---
name: build-plan
description: Decompose a build PRD into an implementation plan. Names mandatory reading with file paths and line ranges, identifies the mirror target to copy structure from, lists step-by-step tasks, and specifies the acceptance test that build-evaluate will run. Plan only — no implementation code is written. Output is `.claude/PRPs/{slug}/plan.md`. Use after build-prd, before build-validate. Triggers — "plan the build", "decompose the PRD", "implementation plan for X", "/build plan", or any time a PRD exists but no plan does.
allowed-tools: Read, Grep, Glob, Agent, Write, Edit, Bash, Skill, mcp__sequential-thinking__sequentialthinking
user-invocable: true
argument-hint: "<slug> matching a PRD in .claude/PRPs/{slug}/"
---

# Build Plan

Decompose a PRD into an implementation plan. PLAN ONLY — no implementation code is written.

## Arguments

Slug matching an existing PRD. Example: `build-plan clybor-skill-discovery-research`.

If no argument, prompt for the slug or list candidates from `.claude/PRPs/*/prd.md`.

## Phase 1: PARSE + PARALLEL LOAD

**Batch in one message** — these reads have no dependencies:
- `Read` `.claude/PRPs/{slug}/prd.md` (verify status `drafting`/`approved`; all sections filled; anchor case concrete; mirror named-or-flagged)
- `Read` `.claude/PRPs/_profiles/{type}.md` (profile from PRD frontmatter)
- `Read` mirror target verbatim (path from PRD)
- Profile's mandatory-reading paths — `Read` each in the same batch (not sequentially)

If any PRD check fails: stop, surface the gap, instruct user to revise via `build-prd` or direct edit.

## Phase 2: ADVERSARIAL RE-READ OF PRD

The PRD is the source document for this plan. First-pass extraction misses 15-25% per the `adversarial-re-read` skill. Invoke it before planning:

```
Skill(skill="adversarial-re-read", args="source=.claude/PRPs/{slug}/prd.md target=plan-for-{slug}")
```

The re-read returns a synthesis-vs-source diff identifying everything the first read missed. Treat each finding as a planning constraint.

## Phase 3: GROUND THE MIRROR (parallel Explore)

The mirror target's sibling files often matter as much as the file itself (shared scripts, profile, templates, related skills in the same plugin). Spawn Explore — independent search, no need for the main context window to hold all the file content:

```
Agent(
  subagent_type="Explore",
  description="Map mirror target and its environment",
  prompt="Read the mirror target at {path from PRD} and identify: (1) which sections to copy verbatim, (2) which sections need adaptation for this build, (3) which sibling files in the same folder/plugin are referenced. Return a section-by-section copy/adapt/skip recommendation plus a list of sibling files worth reading. Search breadth: medium."
)
```

## Phase 4: DECIDE THE SHAPE

Use `mcp__sequential-thinking__sequentialthinking` to choose ONE shape:

| Shape | When | Example |
|---|---|---|
| Single-shot | Write once, ship, no iteration expected | One-off deliverable template |
| Iterative-bounded | Quality bar requires multiple passes | Skill prompt, judge prompt, scorer rubric |
| Pipeline | Multiple stages, each ships independently | Multi-skill plugin |
| Wrapper | Thin layer over existing tool | New slash command that delegates to a skill |

The shape determines what build-execute does: single-shot = one pass; iterative-bounded = calibration loop with hard caps; pipeline = sequential per-stage execute; wrapper = compose existing pieces.

### Pipeline shape → scaffold numbered stage folders

When the shape is Pipeline, the plan MUST scaffold the execution structure (mirror `docs/templates/stage-pipeline/`):

- Create `.claude/PRPs/{slug}/stages/NN-{stage-name}/` per stage — zero-padded prefixes encode execution order; reordering = renaming folders.
- Each stage folder gets a `CONTEXT.md` contract — Inputs (source / where / why), Process (numbered steps), Outputs (artifact / location / format) — under 80 lines, plus an `output/` folder for the handoff artifact.
- A stage reads ONLY its declared Inputs (previous stage's `output/` + named references). Everything else is do-not-load.
- build-execute walks stages in folder order with a human review gate at every boundary: Shawn inspects `output/` before the next stage runs; the next stage picks up whatever he left.
- Plan tasks map 1:1 to stages; each stage's DONE check = its Outputs exist and satisfy the contract.

## Phase 5: WRITE THE PLAN (delegate step-decomposition to Plan agent)

The step-by-step decomposition is exactly what the `Plan` subagent exists for. Spawn it AFTER the shape is locked but BEFORE you write the plan file:

```
Agent(
  subagent_type="Plan",
  description="Decompose {slug} into step-by-step tasks",
  prompt="Design a step-by-step implementation plan. Shape: {shape}. PRD: <paste>. Mirror recommendation: <paste from Phase 3 Explore output>. Adversarial re-read findings: <paste from Phase 2>. Return: numbered tasks, each with a binary DONE check. No 'polish' or 'finalize' steps. Identify which files get touched in which order."
)
```

Copy `.claude/PRPs/_templates/plan-template.md` to `.claude/PRPs/{slug}/plan.md`. Fill every section using the Plan agent's output as the basis for "Step-by-step tasks":

- **Mandatory reading**: exact file paths + line ranges. Vague references ("the relevant skill") are not allowed.
- **Mirror target**: path + which sections to copy verbatim vs adapt.
- **Step-by-step tasks**: numbered. Each task has a clear DONE check. No "polish" or "finalize" tasks — those hide ambiguity.
- **Acceptance test**: how build-evaluate will measure success. Reference the PRD's anchor case explicitly.
- **Anti-patterns to avoid**: from the profile, plus anything specific to this build.
- **Estimated effort**: rough order — minutes, hours, days. Helps execute pick the right caps.

## Phase 6: SAFETY CHECK

If the profile defines forbidden patterns (e.g., "skill description > 1024 chars," "plugin.json missing version bump"), grep the plan for them. If any appear, flag and refuse to exit — the plan as written will fail validate.

## Phase 7: LINK BACK

Edit the PRD frontmatter: set `status: planning` and add `plan_ref: .claude/PRPs/{slug}/plan.md`.

## Output

```
## Plan Generated: {PRD title}

**Plan:** .claude/PRPs/{slug}/plan.md
**PRD:** .claude/PRPs/{slug}/prd.md (status → planning)
**Shape:** {single-shot / iterative-bounded / pipeline / wrapper}
**Mirror:** {path to mirror target, or "none — adversarial review will be heavier"}
**Estimated effort:** {minutes / hours / days}

### Next step
Validate before executing: `build-validate {slug}` — offer to dispatch via `Skill(skill="build-validate", args="{slug}")` if user confirms.
```

## Guidelines

- This skill writes ONLY the plan markdown. No implementation files.
- Mirror existing artifacts aggressively. New structure invites bugs.
- The acceptance test must reference the PRD's anchor case. If it doesn't, you wrote the wrong test.
- "Step-by-step tasks" must each have a binary DONE check. Tasks that say "improve X" are a smell.
