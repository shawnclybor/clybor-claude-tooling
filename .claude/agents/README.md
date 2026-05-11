# Agents

Subagents spawned via the Task tool. Read-only by default. Two lanes bundled — `quality/` and `code/`.

## Lane 1 — Quality review team (`quality/`)

Non-overlapping review lenses. `quality-review` orchestrates them in parallel.

- **adversarial-reviewer** (Opus) — Challenges claims and assumptions. Asks "is this the right thing?"
- **simplifier** (Sonnet) — Finds over-engineering, premature abstraction. Asks "is this the simplest way?"
- **chaos-engineer** (Sonnet) — Stress-tests robustness across edge cases, failure modes, concurrency, adversarial use. Asks "what breaks this?"

## Lane 2 — Code (`code/`)

Universal code-level agents. Operate on actual code rather than proposals.

- **code-reviewer** (Sonnet) — Read-only review of a diff or file set. Catches correctness, type-safety, security, structure issues.
- **debugger** (Sonnet) — Diagnose a bug with reproduction-first, evidence-driven hypothesis narrowing. Complements `five-whys` — five-whys is the protocol, debugger is the executor.
- **code-analyzer** (Sonnet) — Deep-dive cross-file analysis. Traces logic flow, surfaces implicit contracts, finds dead code. Investigation, not grading.
- **security-auditor** (Opus) — OWASP-style assessment of input handling, secrets, auth, injection risk, dependencies, crypto.

## Adding agents

When adding a new agent here, ensure it:

1. Has a clear single-lens responsibility (no overlap with existing agents)
2. Specifies a model tier (Haiku / Sonnet / Opus) in frontmatter
3. Is read-only unless the agent's purpose explicitly requires writes
4. Has a description ≤1024 chars

Project-specific agents (language specialists, ORM specialists, framework experts) belong in the project's own `.claude/agents/`, not here.

Other lanes considered but not bundled by default — orchestration, research, dev-experience. See [`docs/agent-recommendations.md`](../../docs/agent-recommendations.md) for the survey and the rationale; pull in lanes per-project as needed.
