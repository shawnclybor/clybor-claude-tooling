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

Five scenarios showing how the pieces compose.

### 1. New feature, full dev cycle

> *"I need to add rate limiting to the public API. Walk me through the right way."*

**Step 1 — Write the PRD.** You invoke `prd-writer`. It asks for the problem statement, then walks you through writing success criteria that are binary — *"P95 latency on `/api/*` stays under 200ms across 100 test requests"* rather than *"make it fast."* If the original problem cites external claims (a vendor's rate-limit doc, a research paper), `research-analyst` and `evidence-auditor` run first so the PRD has verified citations. Output lands in `docs/PRDs/rate-limiting.md`.

**Step 2 — Plan the work.** `task-plan` reads the PRD and decomposes it into one-pass-completable tasks: schema/config first, then middleware, then tests, then docs. `task-distributor` analyzes the list and identifies which tasks can run safely in parallel (the tests for endpoint A and endpoint B can; the schema and the middleware that reads the schema cannot). The plan lands in `docs/PRDs/rate-limiting-plan.md`.

**Step 3 — Validate the plan.** `/quality-review` spawns three agents in parallel via `multi-agent-coordinator`. `simplifier` asks "is this the simplest decomposition?" — maybe a config flag is overkill for the first version. `adversarial-reviewer` challenges the plan's assumptions — "the PRD says burst tolerance is needed; the plan doesn't address it." `chaos-engineer` asks "what breaks this?" — clock skew, distributed counter races, header spoofing. `knowledge-synthesizer` combines the three reports into one. Critical findings go back to Step 2. High findings get addressed in the plan or explicitly accepted with rationale.

**Step 4 — Implement task-by-task.** `ralph-implement` works through the plan. For each task: it implements the smallest change that addresses the task, runs the per-task check (unit test, type check, lint), and on green invokes `code-reviewer` to catch issues the check itself doesn't — type-safety gaps, observability holes, structural debt. If a task fails twice with the same error, the loop stops and calls `debugger`, which reproduces the failure and narrows the cause with evidence before patching. If `debugger` can't find a root cause, `five-whys` halts the task and surfaces it to you. Parallel task groups get spawned via `multi-agent-coordinator`; `error-coordinator` correlates failures across them when they happen.

**Step 5 — Verify against PRD criteria.** `verify` runs every PRD success criterion through its corresponding check command. The latency criterion runs the perf test. The "API returns 429 on threshold breach" criterion runs the integration test. The security criterion fires `security-auditor` against the rate-limit middleware. If a PRD criterion has no check, the verdict is PARTIAL — you either write the check or strike the criterion before continuing.

**Step 6 — Evaluate the implementation.** `/quality-review` runs again, this time against the built code rather than the plan. Same three agents, different question: did we build the right thing well? Critical findings send a narrower task list back into `ralph-implement`. Clean → close with a short note in `docs/PRDs/rate-limiting-closure.md`: what shipped, what was deferred, follow-ups.

### 2. Autonomous overnight task

> *"Build the user-profile CRUD endpoints with tests. I'll check it in the morning."*

**Step 1 — Frame the prompt.** The Ralph loop only knows when to stop if you tell it. Write the prompt with a clear completion criterion: every endpoint implemented, every test passing, then emit the exact string `COMPLETE`. Include what to do if stuck — *"after 25 iterations document what's blocking and emit BLOCKED."*

**Step 2 — Launch the loop.**

```
/ralph-loop "Implement the four CRUD endpoints in routes/profile/.
             Write integration tests for each. Run the suite each iteration
             and fix what fails. Output <promise>COMPLETE</promise> when all
             tests pass." --completion-promise "COMPLETE" --max-iterations 30
```

This writes `.ralph-loop/state.json` and starts Claude working on the task.

**Step 3 — The loop runs itself.** Each time Claude tries to exit the session, the `ralph-stop.sh` Stop hook fires. It reads the state file, scans the last 200 lines of the transcript for the exact string `COMPLETE`. Not found → increment iteration counter, block the exit, re-feed the original prompt. Claude wakes up to the same prompt, sees its previous work in files, and continues. Iteration after iteration.

**Step 4 — The loop exits.** Three paths: Claude emits `COMPLETE` (hook clears state, allows exit), the counter hits 30 (hook clears state, allows exit with a halt message), or you delete `.ralph-loop/state.json` mid-run to cancel. No external bash loop. No tabs to monitor.

**Step 5 — Morning checkout.** You open the repo, read the closing transcript, scan the git history (one commit per substantive iteration), run the test suite to confirm it's green. If something went sideways, the transcript is the audit trail.

### 3. Production bug investigation

> *"The dedup job is silently skipping records. I've retried it twice with the same failure."*

**Step 1 — Two strikes triggers the protocol.** Same operation failing twice with the same signal is the Two Strikes rule from `kiss-yagni.md`. You stop retrying and invoke `/five-whys`. It refuses to advance until you write a precise problem statement: *"the dedup job processed 1,000 input rows, wrote 982 output rows, logged no errors, and there's no record of which 18 were skipped."*

**Step 2 — Walk the why-chain with Sequential Thinking.** Each "why" is one thought. Why are 18 rows missing? → Because the dedup predicate returned the same hash for them. Why? → Because the hash uses a field that's nullable. Why? → Because the schema migration didn't reject null on that field. Why? → Because the validation step was disabled for the migration window and never re-enabled. Root cause: validation flag left disabled.

**Step 3 — Reproduce before patching.** `debugger` takes the root-cause hypothesis and reproduces it: synthesize 1,000 input rows with the null field on row 17, run the job, confirm row 17 (and 17 more like it) silently drops. Cited evidence: specific line in `dedup/hash.py:42` where the null hashes to the same value as an empty string, and the migration log showing the validation flag never flipped back.

**Step 4 — Trace the surface.** `code-analyzer` maps the cross-file logic flow to confirm no other consumer relies on the disabled flag. It surfaces one more silent path: a separate report job uses the same field for filtering. So the fix needs to cover both consumers.

**Step 5 — Fix and promote.** The minimal fix is two lines: re-enable the validation flag and guard the hash function against null. But the lesson is bigger: validation flags should never be disabled without an automated re-enable check. `insight-promotion` runs that proposed rule through the 3-agent quality team, then adds it to `.claude/rules/` so the next session that touches a migration sees the rule before disabling anything.

### 4. Pre-merge audit on a sensitive change

> *"This PR touches the auth middleware. I don't want to ship without a hard look."*

**Step 1 — Code-level review first.** You point `code-reviewer` at the diff. It walks the checklist — correctness, type-safety, error handling, resource management, observability. Specific findings come back numbered, with file:line citations: "line 47 catches the JWT decode error but never logs the cause; failure mode is silent denial-of-access," "line 89 reads `req.user` before the auth check completes."

**Step 2 — Security review on the same diff.** `security-auditor` (Opus tier) walks a different axis: input validation, injection risk, secret handling, auth flow integrity, dependency surface. It models the attack scenario for each finding — "an attacker submits a forged JWT with an empty signature; the verify call short-circuits to true; full account takeover."

**Step 3 — Design review on the bigger choice.** Even if the diff is clean, the *approach* might be wrong. `/quality-review` runs the 3-agent team on the design itself. `simplifier` asks whether a built-in library would replace the custom middleware. `adversarial-reviewer` asks whether the chosen JWT lifetime contradicts the threat model the PRD assumed. `chaos-engineer` asks what happens under clock drift, key rotation, replay attacks. `knowledge-synthesizer` combines the three.

**Step 4 — Merge gate.** The merge rule is "no Critical findings; High findings either addressed in this PR or explicitly accepted with rationale logged in the PR description." Critical-level security findings always block. The findings table from each agent is the documentation of why this merged or didn't.

### 5. Research-backed decision doc

> *"Should we switch from polling to webhooks for the third-party integration? Write me the decision."*

**Step 1 — Cast the net.** `research-analyst` reads the vendor's documentation, scans community threads about reliability, pulls public incident reports about webhook delivery guarantees, and synthesizes it into a structured claims table — every claim with a citation, every disagreement between sources preserved rather than smoothed over.

**Step 2 — Precision lookups for the specific quirks.** `search-specialist` handles the targeted questions: what's the exact retry policy in the vendor's webhook API? What's the maximum payload size? Is signature verification mandatory? Each lookup returns the exact quote plus the URL plus a retrieval date.

**Step 3 — Audit the citations.** Before any of this lands in a decision doc, `evidence-auditor` walks the claims table and verifies each citation actually says what it's claimed to say. Fabricated URLs, paraphrased "quotes," and out-of-context excerpts get flagged. Anything FLAGGED gets fixed or struck before the doc moves forward.

**Step 4 — Draft the decision.** With the cited claims locked in, you draft the recommendation. `writing-quality` audits the draft for AI-isms — drops "leverage," "robust," "comprehensive"; flattens the rule-of-three patterns; rewrites the formulaic conclusion. The output sounds like a competent human wrote it.

**Step 5 — Make it persistent.** A decision that lives only in chat history will be re-litigated in three months when someone forgets why it was made. `insight-crystallizer` files the decision to `docs/insights/<date>-webhooks-vs-polling.md` with the rationale, the sources, the trade-offs that were considered, and the conditions under which the conclusion would change. Future sessions searching this directory find the answer instead of re-running the research.

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
