# Agent Reference

Catalog of agents that fit alongside the bundled quality and code lanes. Organized by lane. Pull what each project needs.

## Lane 1 — Quality (bundled)

| Agent | Model | Role |
|---|---|---|
| `adversarial-reviewer` | Opus | Challenges claims and assumptions |
| `simplifier` | Sonnet | KISS / YAGNI lens |
| `chaos-engineer` | Sonnet | Robustness / edge-case lens |

`quality-review` orchestrates the three in parallel.

## Lane 2 — Code (bundled)

| Agent | Model | Role |
|---|---|---|
| `code-reviewer` | Sonnet | Read-only quality review of a diff or file set |
| `debugger` | Sonnet | Reproduction-first bug diagnosis |
| `code-analyzer` | Sonnet | Cross-file logic-flow analysis |
| `security-auditor` | Opus | OWASP-style threat audit |

## Lane 3 — Orchestration

For projects that spawn many parallel agents or chain multi-stage workflows. Useful when the existing 7 stages of `dev-loop` need more sophisticated coordination than the orchestrator provides.

| Agent | Model | Role |
|---|---|---|
| `workflow-orchestrator` | Sonnet | Sequences multi-step workflows with state |
| `multi-agent-coordinator` | Sonnet | Tracks parallel agent state; handles partial failures |
| `agent-organizer` | Sonnet | Picks which agents to spawn for a given task |
| `task-distributor` | Sonnet | Splits work across parallel agents safely |
| `context-manager` | Sonnet | Manages shared context across agents |
| `error-coordinator` | Sonnet | Correlates failures across agents; recovers cleanly |
| `knowledge-synthesizer` | Sonnet | Synthesizes findings across agents into a report |
| `performance-monitor` | Sonnet | Observes agent latency, retry counts, escalation rates |

## Lane 4 — Research

For projects that synthesize external sources or maintain cited findings.

| Agent | Model | Role |
|---|---|---|
| `research-analyst` | Sonnet | Deep technology research, multi-source synthesis |
| `search-specialist` | Haiku | Quick documentation lookups, precision retrieval |
| `evidence-auditor` | Sonnet | Verifies quotes, citations, factual claims |
| `metadata-fetcher` | Haiku | Bibliographic / API metadata lookups |

## Lane 5 — Developer experience

For projects with serious documentation, dependency, or tooling surfaces.

| Agent | Model | Role |
|---|---|---|
| `documentation-engineer` | Sonnet | Technical guides, API docs, documentation-as-code |
| `dependency-manager` | Sonnet | Dependency conflicts, security audits, supply chain |
| `mcp-developer` | Sonnet | MCP server / client development |
| `build-engineer` | Sonnet | Build optimization, bundle sizes, CI/CD |
| `git-workflow-manager` | Sonnet | Branching strategies, conflict resolution |

## Project-local lanes (do not bundle)

These belong in the project that uses them, not in this template.

- **Language specialists** — `react-specialist`, `python-specialist`, `typescript-pro`, `php-pro`, `laravel-specialist`, `nextjs-developer`, `frontend-developer`, `api-designer`
- **Stack investigators** — agents that probe specific service stacks
- **Data-stack agents** — `data-pipeline-engineer`, `database-optimizer`, ORM specialists
- **Domain-specific reviewers** — agents tuned to a single workflow or product

## Adding a lane to a project

Drop the agent files into the project's `.claude/agents/<lane>/` and add a routing row in the project's `CLAUDE.md` pointing at when to invoke them.

Genericize before lifting — strip stack-specific phrasing so the agent works for the project at hand.
