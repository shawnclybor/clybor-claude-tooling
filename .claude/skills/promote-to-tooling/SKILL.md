---
name: promote-to-tooling
description: Review a tooling change made in a working repo (new skill, script, rule, hook, template, or workflow fix) and promote the universal parts into the clybor-claude-tooling master template. Use when the user says "promote to tooling", "add this to the master tooling", "update clybor-claude-tooling", "parlay this into the template", "should this go in the template repo", or right after building or adapting tooling in any project repo. Runs a universality test, diffs against the master counterpart, generalizes project-specific bits, applies the edit, wires references, and flags downstream repos that need a re-sync.
---

# Promote to Tooling

clybor-claude-tooling (`~/gits/clybor-claude-tooling/`) is the master template new repos
initialize from (`scripts/init.sh`). Tooling improvements born in working repos
(life-crm, client repos) die there unless promoted. This skill is the promotion path.

## When to run

- Right after building or meaningfully adapting a skill, script, rule, hook, command,
  agent, or template in a working repo
- When the user asks whether a change belongs in the master
- Periodically: "review recent tooling changes for promotion candidates"

## The universality test (gate)

From the master rules README: would this apply equally to a Python backend, a
TypeScript frontend, a research repo, a documentation site?

| Verdict | Action |
|---|---|
| Universal as-is | Port verbatim |
| Universal mechanism, project-specific surface (paths, names, IDs) | Generalize, then port |
| Project-specific (registry formats, client branding, Notion IDs, MCP tool IDs) | Stays in the working repo — record a pointer only |

## Where things live in the master

| Working-repo artifact | Master destination |
|---|---|
| Skill | `.claude/skills/<name>/SKILL.md` |
| Slash command | `.claude/commands/<name>.md` |
| Agent definition | `.claude/agents/<lane>/<name>.md` |
| Hook script | `.claude/hooks/` + wire in `.claude/settings.json.template` |
| Always-on rule | `.claude/rules/` (only if universal — see rules README) |
| Gate/utility script | `scripts/` |
| Document/folder template | `templates/` |
| Router or Hard-Rule text | `templates/CLAUDE.md.template` |

## Workflow

1. **Name the candidate** — file path(s) in the working repo + one line on what it does.
2. **Universality test** — verdict from the table above. Stop here if project-specific.
3. **Diff against the master counterpart** — search the master for an existing equivalent
   (skills list, `scripts/`, `templates/`, commands). If one exists, diff and merge into
   it — don't create a parallel duplicate.
4. **Generalize** — strip project paths, person names, repo-specific IDs. Pick the right
   default over adding a config (KISS).
5. **Apply** — in Cowork, `.claude/` paths need Desktop Commander on the host path
   (`/Users/shawnclybor/gits/clybor-claude-tooling/...`); `scripts/`, `templates/`,
   `docs/` take native writes. In Claude Code, edit directly.
6. **Wire the references** — router row and Key Paths in `templates/CLAUDE.md.template`,
   skills-list row, `settings.json.template` hook if applicable. Undiscoverable tooling
   is dead tooling.
7. **Validate** — run a changed script once; run `bash scripts/check-context-budget.sh`
   if always-on files grew; confirm new skill frontmatter parses (name + description,
   description under 1024 chars).
8. **Report downstream impact** — repos already initialized do NOT auto-update. List
   which active repos should re-sync the changed file (manual copy, or re-run the
   relevant `init.sh` step). The working repo that originated the change usually keeps
   its own specialized version — say so explicitly.

## Anti-patterns

- Porting registry- or client-coupled scripts wholesale (life-crm's `new-project.sh` is
  registry-specific; the master's analog is `init.sh`)
- Creating a parallel skill when the master already covers the concept under another
  name (e.g., `prd-writer`/`task-plan` vs a working repo's `build-prd`/`build-plan` —
  diff and merge, don't fork)
- Promoting a non-universal rule into `.claude/rules/` — rules are paid for in always-on
  context in every downstream repo
- Promoting without updating `templates/CLAUDE.md.template` — the next repo won't know
  the tooling exists
- Skipping the downstream-impact report — a master-only fix silently diverges from every
  live repo
