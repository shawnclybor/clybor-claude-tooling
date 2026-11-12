<!-- build-evaluate Phases 5-5.5, moved verbatim from SKILL.md -->

## Phase 5: COLD-READ FAN-OUT (2-3 agents in parallel)

⚠ **Every cold-read prompt MUST say the agent is READ-ONLY and must NOT run the build's drivers,
generators, or test harnesses.** A capable agent will otherwise run the driver itself to check a
number, which puts a second writer on the tree Phase 3+4 just serialized. Measured 2026-09-10: a
`code-analyzer` given a findings-only brief launched its own copy of the acceptance driver to settle
an assertion count. Findings-only is not the same instruction as run-nothing — say both.

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
