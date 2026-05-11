# Agents

Subagents spawned via the Task tool. Read-only by default. Four lanes ship.

## Lane 1 — Quality (`quality/`)

Non-overlapping review lenses. `quality-review` orchestrates them in parallel.

| Agent | Model | Role |
|---|---|---|
| `adversarial-reviewer` | Opus | Challenges claims and assumptions. Asks "is this the right thing?" |
| `simplifier` | Sonnet | Finds over-engineering, premature abstraction. Asks "is this the simplest way?" |
| `chaos-engineer` | Sonnet | Stress-tests robustness across edge cases, failure modes, concurrency, adversarial use. Asks "what breaks this?" |

## Lane 2 — Code (`code/`)

Universal code-level agents.

| Agent | Model | Role |
|---|---|---|
| `code-reviewer` | Sonnet | Read-only review of a diff or file set. Catches correctness, type-safety, structure, security issues. |
| `debugger` | Sonnet | Reproduction-first bug diagnosis with evidence-driven hypothesis narrowing. Complements `five-whys` — five-whys is the protocol, debugger is the executor. |
| `code-analyzer` | Sonnet | Deep-dive cross-file analysis. Traces logic flow, surfaces implicit contracts, finds dead code. Investigation, not grading. |
| `security-auditor` | Opus | OWASP-style assessment of input handling, secrets, auth, injection risk, dependencies, crypto. |

## Lane 3 — Orchestration (`orchestration/`)

Coordinate multi-agent and multi-stage workflows.

| Agent | Model | Role |
|---|---|---|
| `workflow-orchestrator` | Sonnet | Sequences multi-step workflows with explicit gates between stages. |
| `multi-agent-coordinator` | Sonnet | Tracks state across parallel agents; handles partial failures. |
| `agent-organizer` | Sonnet | Picks which agents to spawn for a given task. |
| `task-distributor` | Sonnet | Splits work across parallel agents safely (no contended writes). |
| `context-manager` | Sonnet | Manages shared context across agent handoffs. |
| `error-coordinator` | Sonnet | Correlates failures across agents to find shared root causes. |
| `knowledge-synthesizer` | Sonnet | Combines multi-agent outputs into a single coherent report. |
| `performance-monitor` | Sonnet | Surfaces hotspots in agent runtime, retries, escalations. |

## Lane 4 — Research (`research/`)

Multi-source synthesis and citation work.

| Agent | Model | Role |
|---|---|---|
| `research-analyst` | Sonnet | Deep research, multi-source synthesis with cited claims. |
| `search-specialist` | Haiku | Quick precision lookups; one question, one cited answer. |
| `evidence-auditor` | Sonnet | Verifies quotes, citations, and factual claims against original sources. |
| `metadata-fetcher` | Haiku | Mechanical metadata lookups; returns structured records. |

## Adding agents

When adding a new agent here, ensure it:

1. Has a clear single-lens responsibility
2. Specifies a model tier in frontmatter
3. Is read-only unless the agent's purpose explicitly requires writes
4. Has a description ≤1024 chars

Project-specific agents (language specialists, framework experts, stack-specific reviewers) belong in the project's own `.claude/agents/`, not here.
