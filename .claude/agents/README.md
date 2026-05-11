# Agents

Subagents spawned via the Task tool. Read-only by default. The 3 in `quality/` form the adversarial review team that `quality-review` orchestrates.

## Bundled

### `quality/`

- **adversarial-reviewer** (Opus) — Challenges claims and assumptions. Asks "is this the right thing?" Finds logical gaps, unstated assumptions, weak evidence.
- **simplifier** (Sonnet) — Enforces KISS / YAGNI. Asks "is this the simplest way?" Finds over-engineering, premature abstractions, unnecessary indirection.
- **chaos-engineer** (Sonnet) — Stress-tests for robustness. Asks "what breaks this?" Walks four lenses — edge cases, failure modes, concurrency / scale, adversarial use.

The three lenses are non-overlapping by design. Run them in parallel via the `quality-review` skill or `/quality-review` command.

## Adding agents

When adding a new agent here, ensure it:

1. Has a clear single-lens responsibility (no overlap with the three above)
2. Specifies a model tier (Haiku / Sonnet / Opus) in frontmatter
3. Is read-only unless the agent's purpose explicitly requires writes
4. Has a description ≤1024 chars

Project-specific agents (language specialists, ORM specialists, framework experts) belong in the project's own `.claude/agents/`, not here.
