# Skills

Composable building blocks. Each skill has a single responsibility and a clear description that drives auto-invocation.

## Bundled

- **quality-review** — Orchestrates the 3-agent adversarial review team in parallel. Use before any irreversible decision (plan, PRD, schema, architecture).
- **five-whys** — Root-cause analysis for unexpected failures. Triggered by the Two Strikes rule.
- **writing-quality** — Audits and rewrites content to remove AI-isms. Runs before any client-facing prose ships.
- **skill-validator** — Ralph-loop validator that iterates a target skill against pass criteria until pass or budget exhausted.
- **dev-loop** — End-to-end 7-stage development workflow: PRD → plan → validate → ralph → verify → evaluate → iterate.
- **insight-crystallizer** — Captures valuable analyses, decisions, and findings into `docs/insights/*.md` so they survive past the chat session.
- **insight-promotion** — Promotes a crystallized insight into always-on governance (`CLAUDE.md`, `.claude/rules/`, or a skill's SKILL.md).

## Adding skills

Each skill is a folder containing one `SKILL.md` with YAML frontmatter (`name`, `description`). The description ≤1024 chars and drives auto-invocation, so it must list real triggers and use cases.

Project-specific skills (deliverable generators, domain workflows) belong in the project's own `.claude/skills/`, not here.
