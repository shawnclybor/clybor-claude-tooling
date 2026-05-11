# Agent Recommendations

Survey of subagents found across the repos the template draws from, plus a recommendation on which (if any) belong in this universal template.

Default bias is to **keep the bundle small**. Every agent here gets shipped to every downstream project — additions need to clear "would every project want this?"

## Strong recommend — add to default bundle

These are universal across language, framework, and project type. Each fills a clearly distinct role from the existing three.

| Agent | Model | Role | Why universal |
|---|---|---|---|
| **code-reviewer** | Sonnet | Read-only review of a diff or symbol set. Catches correctness, blast-radius, type-safety, and security issues. | Every codebase has code reviews. Single lens, sharp scope. |
| **debugger** | Sonnet | Diagnose bugs and unexpected behavior. Reproduces, hypothesizes, narrows the cause with evidence, proposes a minimal fix. | Every codebase has bugs. Complements `five-whys` — five-whys is the protocol, debugger is the executor. |
| **security-auditor** | Opus | OWASP-style assessment of input handling, secrets, auth, dependencies. Read-only. | Every codebase has a security surface. Even simple ones get this wrong (hardcoded secrets, unvalidated input). |

These three are non-overlapping with the existing quality team:
- **quality team** reviews proposals and plans
- **code-reviewer / debugger / security-auditor** review and diagnose actual code

## Conditional — add only if the project warrants

These are useful in specific contexts but would be dead weight in others. Skip unless the project clearly needs them.

| Agent | When to add |
|---|---|
| **refactoring-specialist** | The project has more than ~5k LOC and active refactoring work |
| **research-analyst** + **search-specialist** | The project does multi-source research (academic, market, technical due diligence) |
| **evidence-auditor** | The project produces deliverables with cited claims (research output, analyst reports, audit findings) |
| **mcp-developer** | The project builds or maintains MCP servers |
| **documentation-engineer** | The project maintains user-facing docs as a first-class deliverable |
| **dependency-manager** | The project has a complex dependency graph or supply-chain security concerns |
| **accessibility-tester** | The project ships a UI surface |

## Skip — keep out of the universal template

These are valuable but project-specific or duplicative.

| Agent | Why skip |
|---|---|
| **code-simplifier** | Duplicates the existing `simplifier` agent's lens. Difference is "code only" vs "any proposal" — the existing simplifier covers both. |
| **chaos-agent** | Older / smaller version of the existing `chaos-engineer`. The bundled one is the canonical version. |
| Language specialists (`react-specialist`, `php-pro`, `python-specialist`, `laravel-specialist`, `nextjs-developer`, `typescript-pro`, `frontend-developer`, `api-designer`) | Project-specific. Add to the project's own `.claude/agents/`, not the universal template. |
| Investigation agents (`flowise-investigate`, `langfuse-investigate`, `supabase-investigate`) | Stack-specific. Belong in the project that uses that stack. |
| Orchestration agents (`multi-agent-coordinator`, `workflow-orchestrator`, `agent-organizer`, `error-coordinator`, `context-manager`, `task-distributor`, `knowledge-synthesizer`, `performance-monitor`) | Heavyweight; designed for >10-agent workflows. Most projects do not have the agent density to justify them. Add only when there is a real orchestration problem. |
| Build / git / dependency agents (`build-engineer`, `git-workflow-manager`) | Project-specific tooling. CLI flags + `kiss-yagni` cover the universal cases. |
| Data-stack agents (`data-pipeline-engineer`, `database-optimizer`, `dbt-specialist`, `data-researcher`, `trend-analyst`) | Stack-specific. |
| Domain-specific reviewers (`judge-prompt-adversarial-reviewer`, `langfuse-writeback-auditor`, `eval-scorer-refactor-expert`, `kb-auditor`, `transcript-processor`, `scorer-results-synthesizer`) | Single-use specialists. Not universal. |

## Decision

Default recommendation: **add `code-reviewer`, `debugger`, and `security-auditor` to the universal bundle** under `.claude/agents/code/`. Skip everything else from the universal template; surface the conditional list in this doc so each project can pull what it needs.

If you only want one: `code-reviewer`. It is the highest-frequency need across all project types.

If you want zero: also fine. The existing quality team plus `five-whys` covers proposal review and failure diagnosis. Adding code-level agents is a separable decision.

## Source surveyed

Repos scanned for agent definitions:

- `~/gits/icf-dbt-models/.claude/agents/`
- `~/gits/iwai-knowledge-base/.claude/agents/`
- `~/gits/naf-chatbot/.claude/agents/`
- `~/gits/naf-mentor-dashboard-backend/.claude/agents/`
- `~/gits/naf-mentor-dashboard-frontend/.claude/agents/`
- `~/gits/new-research-system/.claude/agents/`
- `~/gits/teachsim/.claude/agents/`

~50 distinct agent definitions found, deduplicated across repos.
