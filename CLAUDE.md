# clybor-claude-tooling — Router

This repo IS the standardized Claude bootstrap. When you're working in this repo, you're maintaining the template itself — agents, skills, commands, hooks, rules — that get copied into other projects via `scripts/init.sh`.

**KISS. YAGNI.** This template stays small on purpose. Anything domain-specific (Notion, Drive, Supabase, branded deliverables) belongs in a per-project rule file or a Cowork plugin, not here.

## Hard Rules

1. **Don't add a skill or agent here unless every Clybor project would want it.** If it's project-specific, put it in that project. If it's tool-domain governance, put it in a Cowork plugin.
2. **Genericize before committing.** Strip client names (TeachSim, NAF, ICF, Equifinality), strip Notion IDs, strip personal-workflow specifics. The template should work for an empty greenfield repo.
3. **Test the init script after structural changes.** Run `bash scripts/init.sh /tmp/test-init "Test"` and verify the output is a working `.claude/` tree.
4. **Bump the version in PRD.md when changing agent prompts or rule semantics.** Downstream projects need a signal that an update is worth pulling.
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

- [ ] Would every Clybor project want this? If no, stop.
- [ ] Is it already in life-crm or new-research-system in a project-specific form? Generalize before lifting.
- [ ] Does it reference any Notion ID, client name, file path, or workflow specific to one project? Strip it.
- [ ] Does it have a clear, single responsibility? If it spans multiple lenses, split it.
- [ ] Is the description ≤1024 chars (Anthropic skill cap)? Trim.

## Sources used to build this template

- `~/gits/life-crm/.claude/` — routing protocol, five-whys, writing-quality, KISS/YAGNI patterns
- `~/gits/new-research-system/.claude/` — adversarial-reviewer, simplifier, quality-review skill, compact-recovery hook
- `~/gits/new-research-system/.claude/PRPs/prds/new-research-system.md` — chaos-agent scope (lifted, generalized, built fresh)
