# Agent Recommendations (v2)

Revising the earlier draft. The v1 was too conservative — it under-weighted that this template ENCOURAGES multi-agent workflows (the `quality-review` skill spawns 3 agents in parallel; `dev-loop` chains 7 stages; `ralph-implement` and `skill-validator` both iterate with agent calls). Orchestration agents earn their place here precisely because the bundle is agent-heavy by design.

This v2 organizes agents by **lane**. Each lane is a coherent capability cluster. You can pull lanes wholesale, cherry-pick within a lane, or skip a lane entirely.

## Lane 1 — Quality (already bundled)

| Agent | Model | Status |
|---|---|---|
| `adversarial-reviewer` | Opus | Bundled |
| `simplifier` | Sonnet | Bundled |
| `chaos-engineer` | Sonnet | Bundled |

The existing review team. No changes proposed.

## Lane 2 — Code (strong recommend — add wholesale)

Universal across language and framework. Each does something the existing quality team doesn't.

| Agent | Model | Role | Why universal |
|---|---|---|---|
| `code-reviewer` | Sonnet | Read-only review of a diff or symbol set | Every codebase has reviews |
| `debugger` | Sonnet | Diagnose bugs; reproduce, hypothesize, narrow with evidence | Every codebase has bugs. Complements `five-whys` — five-whys is the protocol, debugger is the executor |
| `code-analyzer` | Sonnet | Deep-dive cross-file analysis; traces logic flow, investigates suspicious behavior | Different from code-reviewer: not just "is this code good," but "how does this code work and where does it break" |
| `refactoring-specialist` | Sonnet | Safe transformations that preserve behavior; pattern application; complexity reduction | Every codebase has refactoring needs. Differs from `simplifier` lens by working on existing code, not proposals |
| `security-auditor` | Opus | OWASP-style assessment of input handling, secrets, auth, dependencies | Every codebase has a security surface. Opus because the reasoning surface is unbounded |

**My recommendation:** add all five under `.claude/agents/code/`.

## Lane 3 — Orchestration (recommend — add for multi-agent workflows)

I dismissed these in v1 as "heavyweight." That was wrong for THIS template. The whole point of the dev-loop is multi-stage, multi-agent work. Orchestration agents fill a real gap.

| Agent | Model | Role | When it earns its place |
|---|---|---|---|
| `workflow-orchestrator` | Sonnet | Sequences multi-step workflows with state | Anchors `dev-loop` stage transitions; alternative to inline stage management |
| `multi-agent-coordinator` | Sonnet | Tracks parallel agent state, handles partial failures, coordinates handoffs | When `quality-review` or `ralph-implement` spawns 3+ parallel agents |
| `agent-organizer` | Sonnet | Picks which agents to spawn for a given task | Reduces "which agent for this?" decision overhead in the user's loop |
| `task-distributor` | Sonnet | Splits work across parallel agents safely (avoids contended writes) | Useful inside `ralph-implement` for parallelizable task groups |
| `context-manager` | Sonnet | Manages shared context across agents; prevents context fragmentation | Useful when agents need to hand off without losing state |
| `error-coordinator` | Sonnet | Handles failures across agents; correlates symptoms; recovers cleanly | When parallel agents fail in correlated ways and you need root-cause attribution |
| `knowledge-synthesizer` | Sonnet | Synthesizes findings across agents into a single report | Useful at the end of multi-agent work where each agent produced findings |
| `performance-monitor` | Sonnet | Observes agent latency, retry counts, escalation rates | Useful for tuning the loop over time |

**My recommendation:** add `workflow-orchestrator`, `multi-agent-coordinator`, `agent-organizer`, `task-distributor` under `.claude/agents/orchestration/`. Skip `context-manager`, `error-coordinator`, `knowledge-synthesizer`, `performance-monitor` until the project actually needs them — they're useful but more situational.

If you want them all, that's also defensible — they're each cheap to keep around.

## Lane 4 — Research (recommend — add for any project that does research)

Most non-trivial projects do at least some technical research. These four cover the lane cleanly.

| Agent | Model | Role |
|---|---|---|
| `research-analyst` | Sonnet | Deep technology research, multi-source synthesis, actionable intelligence |
| `search-specialist` | Haiku | Quick documentation lookups, hard-to-find information, precision retrieval |
| `evidence-auditor` | Sonnet | Verifies quotes, citations, and factual claims against original sources |
| `metadata-fetcher` | Haiku | Bibliographic / API metadata lookups, DOI resolution, open-access checks |

**My recommendation:** add all four under `.claude/agents/research/`. Cost is minimal — they're tightly scoped — and the value compounds when the team needs to cite external sources without fabricating them.

## Lane 5 — Developer experience (recommend — add selectively)

These pay off in serious projects but might be overkill in scratch repos.

| Agent | Model | Role | When to add |
|---|---|---|---|
| `documentation-engineer` | Sonnet | Technical guides, API docs, documentation-as-code | If docs are a first-class deliverable |
| `dependency-manager` | Sonnet | Dependency conflicts, security audits of packages, supply-chain | If the project has a non-trivial dependency graph |
| `mcp-developer` | Sonnet | MCP server / client development | If the project builds or consumes MCPs |
| `build-engineer` | Sonnet | Build system optimization, bundle sizes, CI / CD | Frontend / fullstack projects with complex builds |
| `git-workflow-manager` | Sonnet | Branching strategies, conflict resolution, workflow design | Teams of 3+ contributors |

**My recommendation:** add `documentation-engineer`, `dependency-manager`, `mcp-developer` under `.claude/agents/dev-experience/`. Skip `build-engineer` and `git-workflow-manager` from the universal bundle — they're situational.

## Lane 6 — Skip from universal bundle (project-local)

These ARE valuable. They just belong in the project that uses them, not in every project.

- **Language specialists** — `react-specialist`, `python-specialist`, `typescript-pro`, `php-pro`, `laravel-specialist`, `nextjs-developer`, `frontend-developer`, `api-designer`
- **Stack investigators** — `flowise-investigate`, `langfuse-investigate`, `supabase-investigate`
- **Data-stack agents** — `data-pipeline-engineer`, `database-optimizer`, `dbt-specialist`, `data-researcher`, `trend-analyst`
- **Domain-specific reviewers** — `judge-prompt-adversarial-reviewer`, `langfuse-writeback-auditor`, `eval-scorer-refactor-expert`, `kb-auditor`, `transcript-processor`, `scorer-results-synthesizer`, `accessibility-tester`
- **Older / duplicate versions** — `code-simplifier` (duplicates `simplifier`'s lens), `chaos-agent` (older version of `chaos-engineer`)

## Recommendation summary

**Default add (lanes 2 + 3 + 4 + selective 5):** ~16 agents added. Organized under `.claude/agents/code/`, `.claude/agents/orchestration/`, `.claude/agents/research/`, `.claude/agents/dev-experience/`. This is the recommendation if you want the template to support the multi-agent workflows it's designed for.

**Conservative add (lane 2 only):** 5 agents added. Just the code lane. This matches the v1 recommendation. Defensible if you want to keep the bundle minimal and add lanes later.

**Aggressive add (all lanes 2-5):** ~21 agents added including the situational orchestration / dev-experience ones. Defensible if you regularly hit cases where you wish the agent had been there.

## Open questions for you

1. **Which lanes do you want in the default bundle?** Pick from: code (lane 2), orchestration (lane 3), research (lane 4), dev-experience (lane 5).
2. **Within each lane, all-of-lane or cherry-pick?** Lane 3 specifically has an "all 8" option and a "core 4" option.
3. **Naming convention** — `code/`, `orchestration/`, `research/`, `dev-experience/` matches the existing `.claude/agents/quality/` shape. Confirm or override.
4. **Lift-or-rewrite** — for the agents I'd lift from your repos, do you want them lifted verbatim, or do you want me to genericize the descriptions (strip stack-specific phrasing) the way I did with `simplifier` and `chaos-engineer`?

## Source surveyed

Repos scanned for agent definitions across `~/gits/`. ~50 distinct agent definitions found, deduplicated. Lifting candidates pulled primarily from `naf-mentor-dashboard-backend/.claude/agents/` and `naf-mentor-dashboard-frontend/.claude/agents/` (most comprehensive sets) with cross-reference to `naf-chatbot/.claude/agents/` and `new-research-system/.claude/agents/`.
