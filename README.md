# clybor-claude-tooling

Standardized Claude Code bootstrap for new projects. Drop-in `.claude/` tree + `CLAUDE.md` template + adversarial review team + ralph-loop skill validator.

The project-facing `CLAUDE.md` template lives at [`templates/CLAUDE.md.template`](templates/CLAUDE.md.template). `scripts/init.sh` copies it into a target project and substitutes `{{PROJECT_NAME}}`. There is intentionally no `CLAUDE.md` at this repo's root — the bootstrap stays agnostic.

## What you get

**Three quality agents (the adversarial review team)**

| Agent | Model | Lens | Asks |
|---|---|---|---|
| `adversarial-reviewer` | Opus | Evidence and reasoning | *Is this the right thing?* |
| `simplifier` | Sonnet | KISS / YAGNI | *Is this the simplest way?* |
| `chaos-engineer` | Sonnet | Robustness and edge cases | *What breaks this?* |

The three lenses are non-overlapping by design. `quality-review` runs them in parallel and synthesizes findings.

**Skills**

- `quality-review` — orchestrates the 3-agent team against a plan, PRD, file, or proposal
- `five-whys` — root-cause analysis when something breaks unexpectedly
- `writing-quality` — strip AI-isms from client-facing prose
- `skill-validator` — ralph loop that iterates skill fixes against a target repo until pass criteria met

**Slash commands**

- `/quality-review` — full 3-agent review
- `/adversarial`, `/simplify`, `/chaos` — single-lens reviews
- `/five-whys` — debug protocol

**Rules** (auto-loaded)

- `routing-protocol.md` — 5-step Classify→Load→Think→Pre-flight→Validate ritual
- `kiss-yagni.md` — principles, Two Strikes, Blocker Protocol

**Hooks**

- `compact-recovery.sh` — re-injects ROADMAP and recent commits after context-window compaction

## Init a new project

```bash
bash /path/to/clybor-claude-tooling/scripts/init.sh /path/to/new-project "My Project Name"
```

That copies the `.claude/` tree, fills the `{{PROJECT_NAME}}` placeholder in `CLAUDE.md`, makes hooks executable, and prints next steps.

If you re-run init after updating the template, it overwrites `.claude/` files but leaves a project's own `CLAUDE.md` in place (creates `CLAUDE.md.new` instead so you can diff).

## What this template does NOT include (by design)

- Domain governance (Notion, Gmail, Drive, Slack, Supabase) — those live in per-project rule files or Cowork plugins
- Document generators (docx, pptx, xlsx) — bundle them per project
- Source-handling, research-integrity — research-system specifics

If a rule isn't always relevant to every project, it doesn't belong here.

## Updating the template

This is git-controlled. Make changes here, commit, then re-run `init.sh` against any project that should pick up the change.

For long-running projects that have customized rules, prefer copying individual files (`cp .claude/agents/quality/chaos-engineer.md /target/.claude/agents/quality/`) so you don't clobber project-specific edits.

## Layout

```
clybor-claude-tooling/
├── CLAUDE.md                   # this repo's own router (meta — describes itself)
├── README.md
├── .claude/
│   ├── agents/quality/
│   │   ├── adversarial-reviewer.md
│   │   ├── simplifier.md
│   │   └── chaos-engineer.md
│   ├── skills/
│   │   ├── quality-review/SKILL.md
│   │   ├── five-whys/SKILL.md
│   │   ├── writing-quality/SKILL.md
│   │   └── skill-validator/SKILL.md
│   ├── commands/
│   │   ├── quality-review.md
│   │   ├── adversarial.md
│   │   ├── simplify.md
│   │   ├── chaos.md
│   │   └── five-whys.md
│   ├── hooks/
│   │   └── compact-recovery.sh
│   ├── rules/
│   │   ├── routing-protocol.md
│   │   └── kiss-yagni.md
│   └── settings.json.template
├── scripts/
│   └── init.sh
├── templates/
│   └── CLAUDE.md.template
└── docs/
    └── PRD.md                  # bundle scope + ralph-loop spec
```
