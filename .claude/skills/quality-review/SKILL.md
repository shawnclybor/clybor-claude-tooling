---
name: quality-review
description: Structured 3-agent quality review using parallel simplifier, adversarial-reviewer, and chaos-engineer agents. Use when evaluating plans, designs, PRDs, architecture decisions, or any proposal before implementation. Three non-overlapping lenses — KISS/YAGNI, evidence/reasoning, robustness/edge cases.
---

# Quality Review

A structured interrogation methodology using three review agents in parallel to stress-test proposals before committing to them. Each agent attacks a different axis with no overlap.

## The Three Lenses

| Agent | Model | Lens | Asks |
|---|---|---|---|
| `simplifier` | Sonnet | KISS / YAGNI — complexity, abstractions, duplication | *Is this the simplest way?* |
| `adversarial-reviewer` | Opus | Evidence, assumptions, logical gaps | *Is this the right thing?* |
| `chaos-engineer` | Sonnet | Robustness, edge cases, failure modes | *What breaks this?* |

**Why three:** the simplifier prevents over-engineering, the adversarial reviewer prevents under-thinking, the chaos engineer prevents under-stress-testing. Together they catch design failures across complexity, correctness, and robustness.

**Why Opus for adversarial:** adversarial reasoning needs to find non-obvious logical gaps and challenge framing itself. The other two work in well-defined search spaces (complexity patterns, failure patterns) and run fine on Sonnet.

## When to Use

- Before implementing a new phase, feature, or architecture change
- When making irreversible decisions (schema design, MCP server architecture, skill interfaces, API contracts)
- After a research team or planning agent produces recommendations — before accepting them
- When the user asks "is this right?" or "should I do this?"
- Before publishing public-facing copy or signing off on a deliverable
- Before merging a structural PR

## When NOT to Use

- Trivial changes (single-file edits, config tweaks, typo fixes)
- Pure information requests (quality-review is for proposals, not questions)
- Code review of already-implemented code where the design is locked — use a code-review pass instead

## The Pattern

### Round 1 — Initial Review

Spawn all three agents **in parallel** against the proposal:

```
Agent(simplifier):           "Review this proposal. Find over-engineering and simpler alternatives."
Agent(adversarial-reviewer): "Review this proposal. Challenge assumptions and find weaknesses."
Agent(chaos-engineer):       "Review this proposal. Find edge cases, failure modes, and robustness gaps."
```

**Feed each agent:**
- The proposal / plan / PRD being reviewed (full text or file path)
- Relevant context (existing PRDs, CLAUDE.md, current project state)
- The specific decision being made, if there is one

**Collect:** numbered findings grouped by priority (Critical / High / Medium / Low) from each agent.

### Round 2 — Synthesis

Synthesize all three agents' findings into a unified report:

- **Where do they agree?** (high-confidence findings — implement these)
- **Where do they disagree?** (needs human judgment — surface the tension, don't resolve it)
- **What's the combined recommendation?** (specific structural changes to PRD, design, or implementation plan)

Present to the user for decision.

### Round 3 — Re-Review (if context changes)

When the user provides new context that changes the framing (e.g., "this is a template, not a one-off" or "this is throwaway code"), re-engage the relevant agents with the updated context:

```
Agent(<lens>): "You previously found X. The user clarifies Y. Re-evaluate."
```

This round often produces the strongest insights — agents refine their positions with better information. Don't run more than 2 re-review rounds unless genuinely new information arrives.

### Round 4 — Convergence

Final synthesis. Typically you have:

- Findings all three agents agree on → implement
- Findings resolved by new context → document the resolution
- Remaining disagreements → user decides
- Specific structural recommendations → integrate into PRD / design doc / ROADMAP immediately, don't leave as floating review notes

## Prompt Structure

When spawning each review agent, always provide:

1. **Role reminder** — "You are the Simplifier / Adversarial Reviewer / Chaos Engineer."
2. **The artifact** — full text of what's being reviewed, or a file path with explicit instruction to read it
3. **Context** — existing PRD, project state, user constraints (≤200 words, only what's relevant)
4. **Specific question** — what the user is actually deciding (not just "review this")

Keep the prompt under 300 words. Over-specified prompts constrain the agent's judgment and waste context.

## Outputs

Quality review produces:
- **Findings table** — numbered, prioritized, with all three agents' positions
- **Structural recommendations** — specific changes to the PRD or design
- **Decision items** — things only the user can resolve

All accepted recommendations should be integrated into the source artifact (PRD, design doc, ROADMAP) immediately, not left as floating review notes.

## Anti-Patterns

- Don't run quality-review on trivial changes
- Don't run more than 2 rounds without genuinely new context
- Don't treat agent findings as authoritative — they inform user judgment, they don't override it
- Don't let review become a substitute for building — the goal is better decisions, not more documents
- Don't skip the chaos-engineer when the proposal "feels safe." Safety bias is exactly when chaos catches the most.

## Synthesis via knowledge-synthesizer

After Round 1 gathers findings from the three agents in parallel, invoke `knowledge-synthesizer` to combine the outputs rather than hand-rolling the merge. The synthesizer:

- Identifies findings 2+ agents independently surfaced (high confidence)
- Surfaces unique findings from a single agent (still data, not consensus)
- Preserves disagreements explicitly (does not force resolution)
- Flags coverage gaps

For Round 2 re-engagement after context shifts, run the affected agents in parallel via `multi-agent-coordinator` (so a failure in one does not stop the others), then re-synthesize via `knowledge-synthesizer`.

## Parallel spawn discipline

The three review agents run truly in parallel — spawn them via `multi-agent-coordinator`, do not serialize. The coordinator tracks state, handles partial failures, and returns the combined results to the synthesizer.
