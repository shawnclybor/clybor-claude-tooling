---
name: build-prd
description: Capture what you're building BEFORE writing it. Question-driven discovery that locks the target, success criteria, anchor case (one concrete example with expected outcome), and out-of-scope BEFORE any code, plan, or scaffolding. Output is `.claude/PRPs/{slug}/prd.md`. Use when starting a new skill, plugin, scorer, integration, deliverable template, or any artifact where "done" needs a verifiable definition. Triggers — "PRD for X", "spec out X", "let's plan a new skill/plugin", "build pipeline for X", "what are we actually building", or before any non-trivial build where you've caught yourself about to write code without a target. Pairs with build-plan (next), build-validate, build-execute, build-evaluate.
allowed-tools: AskUserQuestion, Read, Grep, Glob, Write, Edit, Bash, Agent, Skill, mcp__sequential-thinking__sequentialthinking
user-invocable: true
argument-hint: "<slug> e.g. clybor-skill-discovery-research"
---

# Build PRD

Codify what you're building BEFORE writing it. A build whose definition of "done" is vague will be done forever.

## When to use

- Starting a new skill, plugin, scorer, integration, deliverable template, or any non-trivial artifact.
- Re-specifying an existing artifact after a scope change.
- Anytime you catch yourself about to write code without an explicit target and acceptance test.

## When NOT to use

- Quick one-off scripts that won't ship and won't be re-run. Just write them.
- Bug fixes to existing code — the bug is the spec.
- Conversation-grade exploration. PRDs are for builds that will be run again.

## Phase 1: PARSE

Extract from argument:
- `slug` — kebab-case, ≤ 60 chars, unique within `.claude/PRPs/`
- target type (skill, plugin, scorer, deliverable, integration, other)

If argument missing, ask the user for slug + one-sentence description.

Check: does `.claude/PRPs/{slug}/prd.md` already exist? If yes, refuse and tell the user — either edit the existing PRD or pick a new slug.

## Phase 2: LOAD PROFILE + PARALLEL DISCOVERY READS

**Batch in one message** (independent reads, no dependencies):
- `Read` profile at `.claude/PRPs/_profiles/{target-type}.md` if it exists
- `Glob` `.claude/PRPs/*/prd.md` — list past PRDs (anchor cases worth cross-referencing)
- `Glob` `.claude/PRPs/*/evaluate.md` — find prior FAIL verdicts on similar slugs (warnings)
- `Read` `CLAUDE.md` Hard Rules section if the target type is "skill" or "plugin" (Rule 11 backlinks discipline applies)

If no profile matches: proceed with the generic question set. Flag in the PRD `profile: none-loaded` so build-plan and build-validate know to demand heavier review.

## Phase 3: DISCOVERY (3–5 questions, batched)

Use `AskUserQuestion` for closed-form items. Use prose questions for the anchor.

Mandatory questions:

1. **What is this?** One paragraph in plain English. What does the artifact DO from the user's perspective?
2. **Why does this matter?** What decision or outcome rides on it? What gets worse if we don't build it (or build it wrong)?
3. **Anchor case.** Name ONE concrete example: a specific input + the expected output/behavior. This is the verifiable "done" target. Vague anchors ("works well") are not acceptable.
4. **Success criteria.** What measurable signals say this is built correctly? (e.g., "passes N fixture rows," "Shawn approves the first 3 outputs," "round-trips through tool X without errors")
5. **Out-of-scope.** What should this artifact explicitly NOT do? List 2-3 things to prevent scope creep at execute time.

Profile-specific questions append to this list.

## Phase 4: GROUND IN EXISTING WORK (parallel subagent fan-out)

Local `Grep`/`Glob` searches only your immediate working tree. The mirror target may live in any of: `.claude/skills/`, `cowork/*/skills/`, `~/gits/{sibling-repo}/.claude/skills/`, `~/gits/{other-project-repo}/`. **Spawn an Explore subagent** to find it efficiently across all of them:

```
Agent(
  subagent_type="Explore",
  description="Find mirror target for {target-type} build",
  prompt="Find the closest existing {target-type} to what's described below. Search .claude/skills/, $HOME/gits/{this-repo}/cowork/*/skills/, $HOME/gits/{sibling-repo}/.claude/skills/. Return top 3 candidates with one-line rationale each, and excerpts of the most relevant frontmatter/headers. Search breadth: medium.\n\nBuild description: <paste discovery Q1 + Q2 answers>"
)
```

The PRD should reference the top candidate verbatim as the mirror target. If the Explore returns weak matches, flag `mirror: none — heavier adversarial review at validate time`.

## Phase 5: GENERATE

Copy `.claude/PRPs/_templates/prd-template.md` to `.claude/PRPs/{slug}/prd.md`. Fill every section. Empty sections must be marked `TBD — block this build until filled`, not silently omitted.

## Phase 5.5: WRITING QUALITY PASS

Invoke `writing-quality` skill (rewrite mode) on the PRD's "What this is" and "Why this matters" sections before exiting. The PRD is a source document — Future-You and build-plan/build-validate will re-read it; AI-isms in the source compound into AI-isms in the artifact.

```
Skill(skill="writing-quality", args="rewrite .claude/PRPs/{slug}/prd.md sections 'What this is' and 'Why this matters'")
```

## Phase 6: VERIFY (tick through this checklist)

Re-read the generated PRD. Walk this checklist literally — tick each box yes/no in the output, do NOT skip silently:

- [ ] Anchor case names ONE concrete input (not a category, not "a typical case")
- [ ] Anchor case names an expected outcome concrete enough to grep / diff / visually compare
- [ ] Success criteria are measurable — each names a script, fixture, command, or named reviewer
- [ ] No success criterion contains "feels right", "high quality", "polished", or similar wish-words
- [ ] Out-of-scope lists 2-3 specific things (not "anything else")
- [ ] Mirror target named OR explicitly flagged "none exists"
- [ ] Acceptance checklist subsection populated with one `- [ ]` per criterion + anchor case
- [ ] Writing-quality pass run on "What this is" and "Why this matters" (Phase 5.5)

If any box is `[ ]`, edit the PRD before exiting. Surface unresolved items to the user before printing the "Next step" line.

## Output

```
## PRD Created: {target-type} — {short title}

**File:** .claude/PRPs/{slug}/prd.md
**Target type:** {skill / plugin / scorer / deliverable / integration / other}
**Profile:** {profile name or "generic (no profile)"}
**Anchor case:** {one-line summary}

### Next step
Generate the implementation plan: `build-plan {slug}` — offer to dispatch via `Skill(skill="build-plan", args="{slug}")` if user confirms.
```

## Guidelines

- Question-driven; never assume the target. Asking 5 questions saves 5 hours of rework.
- Keep the PRD to one page. Long PRDs hide vague anchors.
- The template is the contract. Don't add new sections without updating the template.
- Do NOT write code, plan, or scaffolding. This skill produces a markdown PRD only.
- The slug is durable — it identifies this build across all subsequent skills (plan, validate, execute, evaluate).
