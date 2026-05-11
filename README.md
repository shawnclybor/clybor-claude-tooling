# clybor-claude-tooling

Standardized Claude Code bootstrap for new projects. Drop-in `.claude/` tree + `CLAUDE.md` template + adversarial review team + ralph-loop skill validator.

## Install / use

1. Clone this repo: `git clone https://github.com/shawnclybor/clybor-claude-tooling.git ~/gits/clybor-claude-tooling`
2. Create the target project dir (if it doesn't exist): `mkdir -p ~/gits/my-new-project`
3. Run init: `bash ~/gits/clybor-claude-tooling/scripts/init.sh ~/gits/my-new-project "My New Project"`
4. `cd ~/gits/my-new-project` and start Claude Code

The project-facing router template lives at [`templates/CLAUDE.md.template`](templates/CLAUDE.md.template). `scripts/init.sh` copies it into the target project and substitutes `{{PROJECT_NAME}}`.

## What you get

**Lane 1 — Quality review team (3 agents)**

| Agent | Model | Lens | Asks |
|---|---|---|---|
| `adversarial-reviewer` | Opus | Evidence and reasoning | *Is this the right thing?* |
| `simplifier` | Sonnet | KISS / YAGNI | *Is this the simplest way?* |
| `chaos-engineer` | Sonnet | Robustness and edge cases | *What breaks this?* |

The three lenses are non-overlapping by design. `quality-review` runs them in parallel and synthesizes findings.

**Lane 2 — Code (4 agents)**

| Agent | Model | Role |
|---|---|---|
| `code-reviewer` | Sonnet | Read-only review of a diff or file set |
| `debugger` | Sonnet | Diagnose a bug with reproduction-first hypothesis narrowing |
| `code-analyzer` | Sonnet | Deep-dive cross-file analysis; traces logic flow, finds dead code |
| `security-auditor` | Opus | OWASP-style audit of input handling, secrets, auth, injection, crypto |

Other lanes (orchestration, research, dev-experience) considered and not bundled by default — see [`docs/agent-recommendations.md`](docs/agent-recommendations.md) for the survey and rationale.

**Skills**

- `quality-review` — orchestrates the 3-agent team against a plan, PRD, file, or proposal
- `five-whys` — root-cause analysis when something breaks unexpectedly
- `writing-quality` — strip AI-isms from client-facing prose
- `skill-validator` — ralph loop that iterates skill fixes against a target repo until pass criteria met
- `dev-loop` — 7-stage development workflow: PRD → plan → validate → ralph → verify → evaluate → iterate
- `insight-crystallizer` — captures valuable analyses into `docs/insights/*.md` so they survive past the chat session
- `insight-promotion` — promotes a crystallized insight into always-on governance

**Slash commands**

- `/quality-review` — full 3-agent review
- `/adversarial`, `/simplify`, `/chaos` — single-lens reviews
- `/five-whys` — debug protocol
- `/dev-loop` — run the 7-stage feature workflow

**Rules** (auto-loaded)

- `routing-protocol.md` — 5-step Classify→Load→Think→Pre-flight→Validate ritual
- `kiss-yagni.md` — principles, Two Strikes, Blocker Protocol, Cascade Re-Scope

**Hooks**

- `compact-recovery.sh` — re-injects ROADMAP and recent commits after context-window compaction
- `kiss-yagni-reminder.py` — prints a one-line KISS / YAGNI checkpoint to stderr when writing code files (reminder, not block)

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
├── README.md
├── .claude/
│   ├── agents/
│   │   ├── README.md
│   │   ├── quality/
│   │   │   ├── adversarial-reviewer.md
│   │   │   ├── simplifier.md
│   │   │   └── chaos-engineer.md
│   │   └── code/
│   │       ├── code-reviewer.md
│   │       ├── debugger.md
│   │       ├── code-analyzer.md
│   │       └── security-auditor.md
│   ├── skills/
│   │   ├── README.md
│   │   ├── quality-review/SKILL.md
│   │   ├── five-whys/SKILL.md
│   │   ├── writing-quality/SKILL.md
│   │   ├── skill-validator/SKILL.md
│   │   ├── dev-loop/SKILL.md
│   │   ├── insight-crystallizer/SKILL.md
│   │   └── insight-promotion/SKILL.md
│   ├── commands/
│   │   ├── README.md
│   │   ├── quality-review.md
│   │   ├── adversarial.md
│   │   ├── simplify.md
│   │   ├── chaos.md
│   │   ├── five-whys.md
│   │   └── dev-loop.md
│   ├── hooks/
│   │   ├── README.md
│   │   ├── compact-recovery.sh
│   │   └── kiss-yagni-reminder.py
│   ├── rules/
│   │   ├── README.md
│   │   ├── routing-protocol.md
│   │   └── kiss-yagni.md
│   └── settings.json.template
├── scripts/
│   └── init.sh
├── templates/
│   └── CLAUDE.md.template
└── docs/
    ├── PRD.md                  # bundle scope + ralph-loop spec
    └── agent-recommendations.md # other agents surveyed + recommendation
```
