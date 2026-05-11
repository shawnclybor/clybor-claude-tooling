---
name: insight-crystallizer
description: Capture valuable insights, analyses, and decisions from a chat session and file them as persistent markdown so they survive past the current context. Use when a conversation produces something worth keeping — a comparison, a decision with rationale, a research synthesis, a non-obvious debugging finding, a framework. Triggers — "file this", "save this insight", "this is worth keeping", "remember this analysis", "crystallize this", "don't lose this". Also trigger proactively after deep analytical work whose result would help future sessions. Prevents the "forgotten session" problem where valuable thinking evaporates when the chat ends.
---

# Insight Crystallizer

Most chat sessions produce throwaway exchanges — quick questions, formatting, routine tasks. Some produce real intellectual work: a comparison that weighed three options, a debugging session that uncovered a non-obvious root cause, a framework that connected strategy to implementation.

That work dies when the chat ends unless it gets crystallized.

## The core idea

Adapted from Karpathy's "file good answers back" pattern: when an answer is valuable, it shouldn't disappear into chat history. It becomes a first-class record — searchable, linkable, available to future sessions.

This skill files insights as markdown under `docs/insights/` by default. The path is configurable per project — see Configuration.

## When to crystallize

### Suggest proactively after any of these:

- A comparison or evaluation of tools, approaches, or vendors
- A synthesis that connected dots across multiple files, modules, or projects
- A decision with explicit trade-offs and rationale
- A research summary on a topic relevant to active work
- A technical architecture or design decision
- A debugging session that uncovered a non-obvious root cause
- A competitive intelligence finding or market analysis
- An analysis that required 3+ tool calls, web searches, or file reads to assemble

### Manual triggers

The user explicitly asks to save, file, log, remember, or crystallize the insight.

### Skip if

- Routine Q&A (definitions, syntax, formatting)
- Work already filed elsewhere (commits, tickets, docs)
- Draft content that has not been reviewed
- Opinions or preferences without analytical backing
- Anything the user said to discard

## Phase 1 — Extract

Read the conversation. Identify what is worth preserving. Not everything from a productive session needs to be kept — extract the signal, not the process.

Structure the extraction as:

### Title
A clear, searchable title in the format: `[Type] Topic — Key Finding`.

Examples:
- `Analysis: SQLite vs Postgres for local-first sync — Postgres wins under N concurrent writers`
- `Decision: Use server components by default — rationale documented`
- `Finding: Race condition in queue draining when worker exits during retry`
- `Comparison: Vector store options — short benchmark table, hybrid recommended`

### Insight Type
Classify so retrieval is easier later:
- **Analysis** — evaluation of options with trade-offs and a recommendation
- **Research** — synthesized findings from multiple sources
- **Decision** — a choice made with documented rationale
- **Finding** — a non-obvious discovery (bug, pattern, gotcha)
- **Framework** — a reusable mental model or decision template
- **Comparison** — structured evaluation of alternatives
- **Strategy** — directional thinking about approach or positioning

### Summary (2-4 sentences)
The key takeaway. If a reader only reads this, they should know what was decided or discovered and why it matters.

### Full Content
The detailed analysis, comparison table, decision rationale, or research findings. Include the question, sources consulted, reasoning, conclusion, and any caveats or open questions.

### Connections
Which other files, modules, decisions, or insights does this relate to? Capture as a short list of relative paths or insight slugs.

### Confidence and Shelf Life
- **Confidence**: High (well-sourced and verified) / Medium (reasonable but not verified) / Low (preliminary)
- **Shelf life**: Evergreen / Seasonal / Perishable. Perishable insights include a re-check-by date.

## Phase 2 — Confirm before writing

Present the extracted insight for review. Wait for confirmation. Common adjustments: wrong scope, confidence adjustment, additional context, don't file after all.

## Phase 3 — Write the markdown file

Default location: `docs/insights/YYYY-MM-DD-<slug>.md`. The slug is a kebab-case short title (3-5 words). Example: `2026-05-10-postgres-vs-sqlite-local-first.md`.

### File template

```markdown
---
title: [The full title]
type: [analysis | research | decision | finding | framework | comparison | strategy]
date: YYYY-MM-DD
confidence: [high | medium | low]
shelf_life: [evergreen | seasonal | perishable]
recheck_by: [YYYY-MM-DD or omit]
connections:
  - [relative path or slug]
---

# [Title]

## Summary

[The 2-4 sentence summary.]

## Context

[The question or problem that prompted the work.]

## Analysis

[The full content — sources consulted, reasoning, findings, conclusion.]

## Open Questions

[Anything unresolved. Omit if nothing is open.]

## Sources

[Sources, URLs, files, or tools consulted. Be specific — paths, line numbers, commit hashes, URL plus retrieval date.]
```

## Phase 4 — Optional follow-up

After filing, check whether the new insight connects to or updates existing knowledge.

### Connection check

Search `docs/insights/` for related entries. If the new insight:
- **Supersedes** an older one — add `superseded_by:` to the old frontmatter; do not delete it.
- **Contradicts** an older one — flag for the user: "This contradicts [old slug]. Update or keep both?"
- **Extends** an older one — add cross-references in both frontmatters.

### Pattern detection

If 3+ insights now exist on the same topic, mention it: "You have N insights on [topic]. Want me to synthesize them into a consolidated overview?"

## Configuration

Default location: `docs/insights/`. Override per project by:
- Setting `INSIGHTS_DIR=path` in the environment, OR
- Adding `.claude/rules/insights-location.md` with one line: `Insights directory: <path>`.

If the directory does not exist, the skill creates it on first write.

## When to escalate

If the insight meets any of these criteria, suggest promoting it via the `insight-promotion` skill before closing the task:

1. **Pattern recurrence** — describes a failure or decision that has come up twice or more.
2. **Governance gap** — reveals that existing rules are silent on a real scenario.
3. **Failure prevention** — documents a specific, reproducible failure mode with a known fix.
4. **Cross-session applicability** — relevant to future sessions that will not mention the originating context.

`docs/insights/` is where knowledge lives. `.claude/rules/` and `CLAUDE.md` are where knowledge is enforced.

## Agent integration

- **`evidence-auditor`** — if the insight cites external sources (URLs, papers, claims attributed to third parties), runs before filing. Confirms each citation traces accurately. An insight with fabricated citations is worse than no insight.
- **`research-analyst`** — if the insight synthesizes across 3+ external sources, invoke before drafting the Analysis section. Produces the cited-claims table the insight depends on.
