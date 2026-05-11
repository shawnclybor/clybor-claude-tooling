# Skills

Composable building blocks. Each skill has a single responsibility.

## Adversarial review

- **quality-review** — Orchestrates the 3-agent quality team (simplifier + adversarial-reviewer + chaos-engineer) in parallel via `multi-agent-coordinator`, synthesized via `knowledge-synthesizer`. Use before any irreversible decision (PRD, plan, schema, architecture).
- **five-whys** — Root-cause analysis for unexpected failures. Triggered by the Two Strikes rule. Hands off to `debugger` for reproduction-based investigation and `error-coordinator` for correlated parallel failures.

## Development flow

Per-stage skills, invokable independently or in sequence. Each has explicit pass gates.

| Stage | Skill | Pass gate |
|---|---|---|
| 1. PRD | **prd-writer** | Binary success criteria, scope, dependencies, risks. Uses `templates/prd-template.md`. |
| 2. Plan | **task-plan** | Every criterion covered by ≥1 task; tasks one-pass completable; parallelizable groups identified via `task-distributor`. Uses `templates/plan-template.md`. |
| 3. Validate plan | **quality-review** | No Critical findings; High findings addressed or accepted |
| 4. Implement | **ralph-implement** | Every task check returns green within retry budget; `code-reviewer` clean per-task; `debugger` resolved any two-strikes |
| 5. Verify | **verify** | Every PRD criterion's check returns green |
| 6. Evaluate impl | **quality-review** | No Critical findings on the built artifact |
| 7. Iterate or close | — | Return to Stage 4 with narrower scope, or write a closure note |

Stages run in order. A failed gate returns to that stage, not earlier ones. The numbered checkbox tasks in the plan double as the workflow log.

## Knowledge capture

- **insight-crystallizer** — Captures valuable analyses into `docs/insights/*.md` so they survive past the chat session. Cites sources via `evidence-auditor`; synthesizes multi-source claims via `research-analyst`.
- **insight-promotion** — Promotes a crystallized insight into always-on governance (`CLAUDE.md`, `.claude/rules/`, or a skill SKILL.md). Runs the proposed rule through `adversarial-reviewer` before applying.

## Quality

- **writing-quality** — Audits and rewrites content to remove AI-isms. Runs before any client-facing prose ships.
- **skill-validator** — Ralph-loop validator that iterates a target skill against pass criteria until pass or budget exhausted. Sibling to `ralph-implement`, specialized for skills. Invokes `debugger` on iteration failures.

## Adding skills

Each skill is a folder containing one `SKILL.md` with YAML frontmatter (`name`, `description`). The description ≤1024 chars and drives auto-invocation, so it must list real triggers and use cases.

Project-specific skills (deliverable generators, domain workflows) belong in the project's own `.claude/skills/`, not here.
