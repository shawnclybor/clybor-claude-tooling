# Agents

Subagents spawned via the Task tool. Read-only by default. Four lanes ship.

## Lane 1 — Quality review team (`quality/`)

Non-overlapping review lenses. `quality-review` orchestrates them in parallel.

- **adversarial-reviewer** (Opus) — Challenges claims and assumptions. Asks "is this the right thing?"
- **simplifier** (Sonnet) — Finds over-engineering, premature abstraction. Asks "is this the simplest way?"
- **chaos-engineer** (Sonnet) — Stress-tests robustness across edge cases, failure modes, concurrency, adversarial use. Asks "what breaks this?"

## Lane 2 — Code (`code/`)

Universal code-level agents.

- **code-reviewer** (Sonnet) — Read-only review of a diff or file set.
- **debugger** (Sonnet) — Reproduction-first bug diagnosis with evidence-driven hypothesis narrowing.
- **code-analyzer** (Sonnet) — Cross-file logic-flow analysis. Investigation, not grading.
- **security-auditor** (Opus) — OWASP-style audit of input handling, secrets, auth, injection, crypto.

## Lane 3 — Orchestration (`orchestration/`)

Coordinate multi-agent and multi-stage workflows.

- **workflow-orchestrator** (Sonnet) — Sequences multi-step workflows with explicit gates.
- **multi-agent-coordinator** (Sonnet) — Tracks state across parallel agents; handles partial failures.
- **agent-organizer** (Sonnet) — Picks which agents to spawn for a given task.
- **task-distributor** (Sonnet) — Splits tasks across parallel agents safely.
- **context-manager** (Sonnet) — Manages shared context across agent handoffs.
- **error-coordinator** (Sonnet) — Correlates failures across agents to find shared root causes.
- **knowledge-synthesizer** (Sonnet) — Combines multi-agent outputs into a single coherent report.
- **performance-monitor** (Sonnet) — Surfaces hotspots in agent runtime, retries, escalations.

## Lane 4 — Research (`research/`)

Multi-source synthesis and citation work.

- **research-analyst** (Sonnet) — Deep research, multi-source synthesis with cited claims.
- **search-specialist** (Haiku) — Quick precision lookups; one question, one cited answer.
- **evidence-auditor** (Sonnet) — Verifies quotes, citations, and factual claims against original sources.
- **metadata-fetcher** (Haiku) — Mechanical metadata lookups; returns structured records.

## Adding agents

When adding a new agent here, ensure it:

1. Has a clear single-lens responsibility
2. Specifies a model tier in frontmatter
3. Is read-only unless the agent's purpose explicitly requires writes
4. Has a description ≤1024 chars

Project-specific agents belong in the project's own `.claude/agents/`, not here.

A fifth lane (developer-experience: documentation, dependency, build tooling, MCP development) is catalogued in [`docs/agent-recommendations.md`](../../docs/agent-recommendations.md) — pull per project.
