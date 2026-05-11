# Agent Catalog

Reference for agents that ship with this template plus additional lanes available to pull per project.

## Bundled lanes

### Lane 1 — Quality (`.claude/agents/quality/`)

| Agent | Model | Role |
|---|---|---|
| `adversarial-reviewer` | Opus | Challenges claims and assumptions |
| `simplifier` | Sonnet | KISS / YAGNI lens |
| `chaos-engineer` | Sonnet | Robustness / edge-case lens |

### Lane 2 — Code (`.claude/agents/code/`)

| Agent | Model | Role |
|---|---|---|
| `code-reviewer` | Sonnet | Quality review of a diff or file set |
| `debugger` | Sonnet | Reproduction-first bug diagnosis |
| `code-analyzer` | Sonnet | Cross-file logic-flow analysis |
| `security-auditor` | Opus | OWASP-style threat audit |

### Lane 3 — Orchestration (`.claude/agents/orchestration/`)

| Agent | Model | Role |
|---|---|---|
| `workflow-orchestrator` | Sonnet | Sequences multi-stage workflows |
| `multi-agent-coordinator` | Sonnet | Tracks parallel agent state; handles partial failures |
| `agent-organizer` | Sonnet | Picks which agents fit a task |
| `task-distributor` | Sonnet | Splits work across parallel agents safely |
| `context-manager` | Sonnet | Manages shared context across handoffs |
| `error-coordinator` | Sonnet | Correlates failures to find shared root causes |
| `knowledge-synthesizer` | Sonnet | Combines multi-agent outputs |
| `performance-monitor` | Sonnet | Surfaces hotspots in agent runtime |

### Lane 4 — Research (`.claude/agents/research/`)

| Agent | Model | Role |
|---|---|---|
| `research-analyst` | Sonnet | Multi-source synthesis with cited claims |
| `search-specialist` | Haiku | Quick precision lookups |
| `evidence-auditor` | Sonnet | Verifies quotes and citations |
| `metadata-fetcher` | Haiku | Mechanical metadata lookups |

## Additional lane — Developer experience

Pull per project where the surface warrants.

| Agent | Model | Role | When to add |
|---|---|---|---|
| `documentation-engineer` | Sonnet | Technical guides, API docs, docs-as-code | Docs are a first-class deliverable |
| `dependency-manager` | Sonnet | Dependency conflicts, security audits, supply chain | Non-trivial dependency graph |
| `mcp-developer` | Sonnet | MCP server / client development | Project builds or consumes MCPs |
| `build-engineer` | Sonnet | Build optimization, bundle sizes, CI/CD | Complex builds |
| `git-workflow-manager` | Sonnet | Branching strategies, conflict resolution | Multi-contributor team |

## Project-local agents (do not bundle)

These belong in the project that uses them.

- **Language and framework specialists** — agents tuned to a specific language, runtime, or framework
- **Stack investigators** — agents that probe a specific service or platform
- **Data-stack specialists** — agents tuned to a specific database, ORM, or data pipeline
- **Workflow-specific reviewers** — agents tuned to a single product or domain

## Adding a lane to a project

Drop the agent files into the project's `.claude/agents/<lane>/`. Add a row in the project's `CLAUDE.md` routing table for when to invoke them. Genericize before lifting if the source agent mentions a specific tech stack.
