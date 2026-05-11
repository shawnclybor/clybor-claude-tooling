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

The three lenses are non-overlapping. `quality-review` runs them in parallel and synthesizes findings.

**Lane 2 — Code (4 agents)**

| Agent | Model | Role |
|---|---|---|
| `code-reviewer` | Sonnet | Read-only review of a diff or file set |
| `debugger` | Sonnet | Reproduction-first bug diagnosis |
| `code-analyzer` | Sonnet | Cross-file logic-flow analysis |
| `security-auditor` | Opus | OWASP-style threat audit |

**Lane 3 — Orchestration (8 agents)**

| Agent | Model | Role |
|---|---|---|
| `workflow-orchestrator` | Sonnet | Sequences multi-stage workflows |
| `multi-agent-coordinator` | Sonnet | Tracks parallel agent state; handles partial failures |
| `agent-organizer` | Sonnet | Picks which agents fit a task |
| `task-distributor` | Sonnet | Splits work across parallel agents safely |
| `context-manager` | Sonnet | Manages shared context across handoffs |
| `error-coordinator` | Sonnet | Correlates failures to find shared root causes |
| `knowledge-synthesizer` | Sonnet | Combines multi-agent outputs |
| `performance-monitor` | Sonnet | Surfaces hotspots in agent runtime |

**Lane 4 — Research (4 agents)**

| Agent | Model | Role |
|---|---|---|
| `research-analyst` | Sonnet | Multi-source synthesis with cited claims |
| `search-specialist` | Haiku | Quick precision lookups |
| `evidence-auditor` | Sonnet | Verifies quotes and citations |
| `metadata-fetcher` | Haiku | Mechanical metadata lookups |


**Skills — adversarial review**

- `quality-review` — orchestrates the 3-agent team against a plan, PRD, file, or proposal
- `five-whys` — root-cause analysis when something breaks unexpectedly

**Skills — ralph loops**

- `ralph-loop` — canonical Stop-hook ralph. Single prompt + completion-promise. Use for autonomous walk-away iteration. `/ralph-loop` command.
- `ralph-implement` — task-driven sibling. Reads a task plan, supports parallel groups, structured escalation.
- `skill-validator` — ralph specialized for validating SKILL.md files.

**Skills — development flow** (run in sequence; each stage standalone)

| Stage | Skill |
|---|---|
| 1. PRD | `prd-writer` (uses `templates/prd-template.md`) |
| 2. Plan | `task-plan` (uses `templates/plan-template.md`) |
| 3. Validate plan | `quality-review` |
| 4. Implement | `ralph-implement` |
| 5. Verify | `verify` |
| 6. Evaluate impl | `quality-review` |
| 7. Iterate or close | (decision, no skill) |

**Skills — other**

- `writing-quality` — strip AI-isms from client-facing prose
- `insight-crystallizer` — captures valuable analyses into `docs/insights/*.md` so they survive past the chat session
- `insight-promotion` — promotes a crystallized insight into always-on governance

**Slash commands**

- `/quality-review` — full 3-agent review
- `/adversarial`, `/simplify`, `/chaos` — single-lens reviews
- `/five-whys` — debug protocol
- `/ralph-loop` — start a Stop-hook-driven autonomous ralph loop

**Rules** (auto-loaded)

- `routing-protocol.md` — 5-step Classify→Load→Think→Pre-flight→Validate ritual
- `kiss-yagni.md` — principles, Two Strikes, Blocker Protocol, Cascade Re-Scope

**Hooks**

- `compact-recovery.sh` — re-injects ROADMAP and recent commits after context-window compaction
- `kiss-yagni-reminder.py` — prints a one-line KISS / YAGNI checkpoint to stderr when writing code files (reminder, not block)
- `ralph-stop.sh` — Stop hook for the Ralph Loop. Reads `.ralph-loop/state.json`, scans transcript for completion-promise, blocks exit + re-feeds prompt or allows exit

## User journeys

Five scenarios showing how the bundle's pieces compose.

### 1. New feature, full dev cycle

> *"I need to add rate limiting to the public API. Walk me through the right way."*

```
prd-writer        →  binary success criteria, scope, dependencies, risks
task-plan         →  checkbox tasks; task-distributor groups parallel work
/quality-review   →  simplifier + adversarial-reviewer + chaos-engineer on the plan
ralph-implement   →  per-task loop with code-reviewer on every completed task;
                     debugger if a task fails twice with the same error
verify            →  every PRD criterion's check runs green; security-auditor
                     covers any security-shaped criterion
/quality-review   →  3-agent team against the built implementation
```

Result: a PRD, a plan, a verified implementation, and an audit trail of what passed each gate.

### 2. Autonomous overnight task

> *"Build the user-profile CRUD endpoints with tests. I'll check it in the morning."*

```
/ralph-loop "Implement the four CRUD endpoints in routes/profile/.
             Write integration tests for each. Run the suite each iteration
             and fix what fails. Output <promise>COMPLETE</promise> when all
             tests pass." --completion-promise "COMPLETE" --max-iterations 30
```

The Stop hook re-feeds the prompt until Claude emits `COMPLETE` or hits 30 iterations. State lives in `.ralph-loop/state.json`. Cancel with `rm .ralph-loop/state.json`.

Result: morning checkout shows the work + git history of every iteration.

### 3. Production bug investigation

> *"The dedup job is silently skipping records. I've retried twice with the same failure."*

```
/five-whys                  →  walks the root-cause protocol
debugger (invoked by skill) →  reproduces the failure, narrows with evidence
code-analyzer               →  traces the cross-file logic path that ends in
                               the silent skip
                            →  minimal fix proposed
insight-promotion           →  if the root cause reveals a governance gap,
                               codify the rule (e.g. "always log skip events
                               with the input row")
```

Result: a structural root cause (not just a symptom), a minimal fix, and a governance update so the same class of bug doesn't recur silently.

### 4. Pre-merge audit on a sensitive change

> *"This PR touches the auth middleware. I don't want to ship without a hard look."*

```
code-reviewer       →  correctness, type-safety, structure, observability
security-auditor    →  OWASP-style review of the auth flow specifically
/quality-review     →  3-agent team on the design choice itself, not just the code
```

Result: numbered findings grouped Critical / High / Medium / Low across three lenses (quality, security, design). Merge gate is "no Critical; High addressed or accepted with rationale."

### 5. Research-backed decision doc

> *"Should we switch from polling to webhooks for the third-party integration? Write me the decision."*

```
research-analyst    →  multi-source synthesis (vendor docs, reliability data,
                       community threads); produces a cited claims table
search-specialist   →  precision lookups for specific API quirks
evidence-auditor    →  verifies every citation traces accurately
writing-quality     →  strips AI-isms from the decision doc before sharing
insight-crystallizer→  files the decision to `docs/insights/` so future
                       sessions don't re-litigate
```

Result: a defensible decision doc with cited claims, no fabricated sources, and a permanent record of the rationale.

## Init a new project

```bash
bash /path/to/clybor-claude-tooling/scripts/init.sh /path/to/new-project "My Project Name"
```

That copies the `.claude/` tree, fills the `{{PROJECT_NAME}}` placeholder in `CLAUDE.md`, makes hooks executable, and prints next steps.

If you re-run init after updating the template, it overwrites `.claude/` files but leaves a project's own `CLAUDE.md` in place (creates `CLAUDE.md.new` instead so you can diff).

## Not in the template

- Domain governance (database, messaging, storage, calendar) — lives per project
- Document generators (docx, pptx, xlsx) — bundle per project
- Source-handling, research-integrity rules — bundle per project that needs them

Add anything project-specific to that project's own `.claude/`, not here.

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
│   │   ├── quality/             # adversarial-reviewer, simplifier, chaos-engineer
│   │   ├── code/                # code-reviewer, debugger, code-analyzer, security-auditor
│   │   ├── orchestration/       # 8 orchestration agents
│   │   └── research/            # research-analyst, search-specialist, evidence-auditor, metadata-fetcher
│   ├── skills/
│   │   ├── README.md
│   │   ├── quality-review/SKILL.md
│   │   ├── five-whys/SKILL.md
│   │   ├── writing-quality/SKILL.md
│   │   ├── ralph-loop/SKILL.md
│   │   ├── ralph-implement/SKILL.md
│   │   ├── skill-validator/SKILL.md
│   │   ├── prd-writer/SKILL.md
│   │   ├── task-plan/SKILL.md
│   │   ├── verify/SKILL.md
│   │   ├── insight-crystallizer/SKILL.md
│   │   └── insight-promotion/SKILL.md
│   ├── commands/
│   │   ├── README.md
│   │   ├── quality-review.md
│   │   ├── adversarial.md
│   │   ├── simplify.md
│   │   ├── chaos.md
│   │   ├── five-whys.md
│   │   └── ralph-loop.md
│   ├── hooks/
│   │   ├── README.md
│   │   ├── compact-recovery.sh
│   │   ├── kiss-yagni-reminder.py
│   │   └── ralph-stop.sh
│   ├── rules/
│   │   ├── README.md
│   │   ├── routing-protocol.md
│   │   └── kiss-yagni.md
│   └── settings.json.template
├── scripts/
│   └── init.sh
└── templates/
    ├── CLAUDE.md.template
    ├── prd-template.md
    └── plan-template.md
```
