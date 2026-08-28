# Skills

Composable building blocks. Each skill has a single responsibility.

## Adversarial review

- **quality-review** — Orchestrates the 3-agent quality team (simplifier + adversarial-reviewer + chaos-engineer) in parallel via `multi-agent-coordinator`, synthesized via `knowledge-synthesizer`. Use before any irreversible decision.
- **five-whys** — Root-cause analysis for unexpected failures. Triggered by the Two Strikes rule. Hands off to `debugger` (reproduction) and `error-coordinator` (correlated parallel failures).

## Ralph loops

- **ralph-loop** — Canonical Stop-hook ralph. Single prompt re-fed until Claude emits the completion-promise or max-iterations is hit. Monolithic, single-process. Use for autonomous walk-away iteration on a well-defined task.
- **ralph-implement** — Task-driven sibling. Reads a `task-plan` output, iterates through tasks with per-task checks, supports parallel groups via `multi-agent-coordinator`. Use when you have a structured plan, not just a prompt.
- **skill-validator** — Skill-validation sibling. Iterates a SKILL.md against pass criteria until pass or budget. Specialized ralph for skill authoring.

## Development flow

Per-stage skills, invokable independently or in sequence. Each has explicit pass gates.

| Stage | Skill | Pass gate |
|---|---|---|
| 1. PRD | **prd-writer** | Binary success criteria, scope, dependencies, risks. Uses `templates/prd-template.md`. |
| 2. Plan | **task-plan** | Every criterion covered by ≥1 task; parallelizable groups identified via `task-distributor`. Uses `templates/plan-template.md`. |
| 3. Validate plan | **quality-review** | No Critical findings; High addressed or accepted |
| 4. Implement | **ralph-implement** | Every task check returns green; `code-reviewer` clean; `debugger` resolved any two-strikes |
| 5. Verify | **verify** | Every PRD criterion's check returns green |
| 6. Evaluate impl | **quality-review** | No Critical findings on the built artifact |
| 7. Iterate or close | — | Return to Stage 4 with narrower scope, or write a closure note |

## Working method

- **ooda** — Boyd's decision cycle as a working protocol for tasks whose conditions change mid-flight. Requires a named Orientation Block before any decision commits, and loops back to Observe after acting. Explicit invocation only; it never selects itself.

## Reporting

- **session-output** — Reports what a working session actually did, in two modes: a self-contained HTML dashboard (default) or plain prose (`/session-output simplify`). Measured outcomes only, never invented. Ships `assets/template.html` and `scripts/session_file_check.py`.

## Knowledge capture

- **insight-crystallizer** — Captures valuable analyses into `docs/insights/*.md`. Cites via `evidence-auditor`; synthesizes multi-source claims via `research-analyst`.
- **insight-promotion** — Promotes a crystallized insight into always-on governance. Runs the proposed rule through the full quality team before applying.

## Quality

- **writing-quality** — Audits and rewrites content to remove AI-isms. Runs before any client-facing prose ships. Invokes `evidence-auditor` on cited content.

## Adding skills

Each skill is a folder containing one `SKILL.md` with YAML frontmatter (`name`, `description`). The description ≤1024 chars and drives auto-invocation. Project-specific skills belong in the project's own `.claude/skills/`, not here.
