# clybor-claude-tooling — Router

This repo IS the standardized Claude bootstrap. When working in this repo, you're maintaining the template itself — agents, skills, commands, hooks, rules — that get copied into other projects via `scripts/init.sh`.

**KISS. YAGNI.** This template stays small on purpose. Anything domain-specific (database governance, messaging governance, branded deliverables, project-scoped workflows) belongs in a per-project rule file or a plugin, not here.

## Hard Rules

1. **Don't add a skill or agent here unless every project would want it.** If it's project-specific, put it in that project. If it's tool-domain governance, put it in a plugin.
2. **Genericize before committing.** Strip client names, project names, repo paths, IDs, and personal-workflow specifics. The template must work for an empty greenfield repo.
3. **Test the init script after structural changes.** Run `bash scripts/init.sh /tmp/test-init "Test"` and verify the output is a working `.claude/` tree.
4. **Bump the version in `docs/PRD.md` when changing agent prompts or rule semantics.** Downstream projects need a signal that an update is worth pulling.
5. **Quality-review your own changes.** Use `/quality-review` against any structural edit to this repo before commit.

## What lives here

| Path | Purpose |
|---|---|
| `templates/CLAUDE.md.template` | The router copied into new projects |
| `.claude/agents/quality/` | adversarial-reviewer, simplifier, chaos-engineer |
| `.claude/skills/` | quality-review, five-whys, writing-quality, skill-validator |
| `.claude/commands/` | /quality-review, /simplify, /adversarial, /chaos, /five-whys |
| `.claude/rules/` | routing-protocol, kiss-yagni |
| `.claude/hooks/compact-recovery.sh` | re-inject ROADMAP after compaction |
| `scripts/init.sh` | copy bundle into a target project |
| `docs/PRD.md` | bundle scope + ralph-loop validator spec |

## Adding to the bundle — pre-flight checklist

Before adding any new agent, skill, or rule to this template:

- [ ] Would every project that uses this template want this? If no, stop.
- [ ] Is it already in another repo in a project-specific form? Generalize before lifting.
- [ ] Does it reference any concrete client name, project name, repo path, or workflow specific to one project? Strip it.
- [ ] Does it have a clear, single responsibility? If it spans multiple lenses, split it.
- [ ] Is the description ≤1024 chars (Anthropic skill cap)? Trim.
