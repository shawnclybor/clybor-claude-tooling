# Skills

Composable building blocks. Each skill has a single responsibility and a clear description that drives auto-invocation.

## Bundled

**Adversarial review team**

- **quality-review** — Orchestrates the 3-agent adversarial review team (simplifier + adversarial-reviewer + chaos-engineer) in parallel. Use before any irreversible decision.
- **five-whys** — Root-cause analysis for unexpected failures. Triggered by the Two Strikes rule.

**Dev loop (7 stages)**

- **prd-writer** — Stage 1. Write a PRD with binary success criteria.
- **task-plan** — Stage 2. Decompose the PRD into a sequenced checkbox task list.
- (Stage 3 uses `quality-review` against the plan)
- **ralph-implement** — Stage 4. Continuous-iteration code implementation with two-strike rule.
- **verify** — Stage 5. Run deterministic checks mapped to PRD success criteria.
- (Stage 6 uses `quality-review` against the implementation)
- **dev-loop** — Thin orchestrator that sequences the seven stages with explicit pass gates.

**Knowledge capture**

- **insight-crystallizer** — Captures valuable analyses into `docs/insights/*.md` so they survive past the chat session.
- **insight-promotion** — Promotes a crystallized insight into always-on governance (`CLAUDE.md`, `.claude/rules/`, or a skill).

**Quality**

- **writing-quality** — Audits and rewrites content to remove AI-isms. Runs before any client-facing prose ships.
- **skill-validator** — Ralph-loop validator that iterates a target skill against pass criteria until pass or budget exhausted. Sibling to `ralph-implement`, specialized for skills.

## Adding skills

Each skill is a folder containing one `SKILL.md` with YAML frontmatter (`name`, `description`). The description ≤1024 chars and drives auto-invocation, so it must list real triggers and use cases.

Project-specific skills (deliverable generators, domain workflows) belong in the project's own `.claude/skills/`, not here.
