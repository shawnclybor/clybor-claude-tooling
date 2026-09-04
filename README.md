# clybor-claude-tooling

The canonical home for reusable Claude Code tooling: a drop-in `.claude/` tree, a `CLAUDE.md` router template, a measured build pipeline, an adversarial review system with drift detection, write-time and commit-time gates with their negative controls, and a sanitized catalog of skills harvested from real projects.

A project bootstraps from here with `scripts/init.sh`. When a project improves something reusable, it promotes the change back with `scripts/promote.sh`, and a global pre-commit gate keeps every project's copy byte-identical to the canonical one.

## Install / use

1. Clone: `git clone <this repository> ~/gits/clybor-claude-tooling`
2. Create the target project dir: `mkdir -p ~/gits/my-new-project`
3. Init: `bash ~/gits/clybor-claude-tooling/scripts/init.sh ~/gits/my-new-project "My New Project"`
4. `cd ~/gits/my-new-project` and start Claude Code

The router template is [`templates/CLAUDE.md.template`](templates/CLAUDE.md.template). `init.sh` copies the `.claude/` tree, fills `{{PROJECT_NAME}}`, makes hooks executable and prints next steps. Re-running it after a template change overwrites `.claude/` but leaves a project's own `CLAUDE.md` alone (it writes `CLAUDE.md.new` to diff against).

For the promotion gate on every machine you commit from: `bash scripts/install-global.sh` sets the global `core.hooksPath` and installs the SessionStart detector that lists promotable and drifted tooling at the start of each session.

## The Build Pipeline

The build is seven stages with a gate between each. This is for non-deterministic work. Use Ralph loops for rote code projects. The sequence of build is fixed: `prd → probe → validate → plan → estimate → build → evaluate`.

| Stage | Skill | What it does |
|---|---|---|
| 1 | `build-prd` | Locks the target, binary success criteria, one anchor case, and the out-of-scope list before any code |
| 2 | `build-probe` | Turns every asserted number, count, filename and line reference in the PRD into an emitted one: one executable probe per claim plus a `sources.lock` pinning every cited file. Re-runs in seconds at every later stage |
| 3 | `build-validate` | Reviews the three to five premises the design rests on, once. Not the plan. Skipped and recorded when no premise is contested |
| 4 | `build-plan` | Decomposes into one runnable increment with the acceptance driver written red first; gated by `check-plan-soundness.py`, not by a panel |
| 5 | `build-estimate` | Projects remaining effort from a calibration ledger of measured builds, never a typed number. Optional, never a gate |
| 6 | `build-execute` | Bounded iteration with hard caps; adversarial review only on a contract, a pinned constant, a refusal limb or an unmutated path |
| 7 | `build-evaluate` | Binary verdict against the anchor case; five-whys on FAIL, insight-promotion on PASS |

A lighter flow alternative for small work: `prd-writer` → `task-plan` → `/quality-review` → `ralph-implement` → `verify`.

## Adversarial Review

The suite of adversarial review agents, skills, and hooks. Blends mechanical, deterministic checks with inferential, nondeterministic natural-language workflows.

| Skill or command | Use |
|---|---|
| `adversarial-review` / `/adversarial-review` | Three lenses in parallel (chaos, simplifier, adversarial-reviewer) against a fixed rubric loaded before any agent runs. Runs the mechanical checker first, checks for review drift second, caps at three rounds. For anything that will be reviewed more than once |
| `quality-review` / `/quality-review` | The same three agents with no rubric and no memory. For a one-off look |
| `/adversarial`, `/simplify`, `/chaos` | One lens each |
| `adversarial-re-read` | Mandatory second pass over source material against the extraction it produced; first-pass extraction misses 15 to 25% of what is there |
| `five-whys` / `/five-whys` | Root-cause protocol, triggered by Two Strikes |
| `why-diagnostic` | A framing diagnostic for "why did this happen" moments before reaching for five-whys |
| `verify` | Deterministic gate against a PRD's success criteria |

`review-drift.py` records each round and flags four ways a review ratchets: never coming back clean, counts rising on an unchanged target, self-inflicted findings, and re-grades against unchanged text. The logic underlying this is that agents do a terrible job assessing things over multiple iterations, due to the underlying imperatives of their system prompts and engineering. Mechanical checks keep standards consistent and prevent mission creep.

## Agents

Nineteen subagents in four lanes, spawned by the skills above. Read-only by default. Generally I find that these are not well utilized unless they are baked directly into commands and skills. 

**Quality:** `adversarial-reviewer` (Opus, is this true), `simplifier` (Sonnet, is this the simplest way), `chaos-engineer` (Sonnet, what breaks this). Non-overlapping by construction.

**Code:** `code-reviewer`, `debugger`, `code-analyzer` (Sonnet), `security-auditor` (Opus).

**Orchestration:** `workflow-orchestrator`, `multi-agent-coordinator`, `agent-organizer`, `task-distributor`, `context-manager`, `error-coordinator`, `knowledge-synthesizer`, `performance-monitor`.

**Research:** `research-analyst`, `evidence-auditor` (Sonnet), `search-specialist`, `metadata-fetcher` (Haiku).

Full table in [`.claude/agents/README.md`](.claude/agents/README.md).

## Other skills

**Ralph loops.** `ralph-loop` / `/ralph-loop` is the Stop-hook loop cycle that was all the rage of last month: one prompt re-fed until Claude emits the completion promise or the iteration cap. `ralph-implement` is the task-driven sibling. `skill-validator` is the ralph specialised for validating a SKILL.md. I use this for rote coding projects. It gets the job done right.

**Prose and knowledge.** `writing-quality` strips AI-isms and empty prose from anything a person will read. `session-output` writes the report of what a session did. `insight-crystallizer` files a decision so it survives the chat; `insight-promotion` turns one into an always-on rule. `promote-to-tooling` reviews a tooling change in a working repo and promotes the universal part here. `ooda` runs Boyd's decision cycle on a task you ask to work that way.

**Governance.** `notion-governance`, `search-governance` and `excel-connector-governance` are domain-governance skills for the workspaces they name. The pattern they follow is `assets/skills/governance-skill-template/`; project-specific governance belongs in the project.

## Hooks

Hooks are the silent heroes of AI, and also the most underused. Hooks are checks. Hooks are external validation. Hooks are gates -- is AI allowed to continue or no? Did it do what it was supposed to? Did it follow a rule? Did it format a sheet? Did it remember to do something? Hooks are the antidote to the "Oops my bad." And every gate ships with a negative control (`test-*.sh`) that proves it can fail, and where the gate is a list, a mutator (`mutate-*.py`) that proves the control catches a broken gate. A gate that cannot fail proves nothing. Nothing is itself without its opposite. 

**Wired by default** in `settings.json.template`:

| Hook | Event | Does |
|---|---|---|
| `session-context.sh` | SessionStart | Loads the project rule and recent knowledge log into context |
| `kiss-yagni-reminder.py` | PreToolUse Write/Edit | One-line KISS / YAGNI checkpoint on code files. Reminds, never blocks |
| `no-postmortem-validator.py` | PreToolUse Write/Edit | Denies change-narration in operational prose: words that describe a prior state, strikethrough, headings that narrate what changed. Provenance-named files and an inline marker are exempt |
| `availability-claim-validator.py` | PreToolUse Write/Edit | Denies a claim that something is blocked, missing or owed by someone else without the evidence beside it |
| `compact-recovery.sh` | Stop (compact) | Re-injects the roadmap and recent commits after context compaction |
| `ralph-stop.sh` | Stop | Drives the Ralph loop from `.ralph-loop/state.json` |

**Shipped, wire per project:**

| Hook | Does |
|---|---|
| `check-zsh-safety.py` | PreToolUse on Bash. The tool runs `zsh -c`; a word beginning with `=` aborts the whole script and an unquoted glob makes a command silently not run. Blocks both |
| `check-document-claims.py` | PreToolUse on Write/Edit. An absolute, uncited claim about a specific document is denied; a claim about the paper carries the line it rests on |
| `check-empty-prose.py` | Prose that reads fluently and says nothing: slogans, flourish, filler, insider terms. A different defect from AI-isms |
| `check-prp-naming.py` | Naming, frontmatter and placement of build artifacts; also regenerates each build's index |
| `check-plan-soundness.py` | Eight mechanical checks on a build plan: self-satisfying DONEs, unauthored artifacts, premature DONEs, criterion drift, cycles, duplicate ids, unpinned citations, prose-named artifacts. Under a second |
| `review-drift.py` | The review ledger described under Review |
| `no-postmortem-precommit.py` | The commit-time backstop for the write-time validator |

## Slash commands

I used slash commands for a while to orchestrate skills into larger workflows. I haven't done much of that work lately because markdown files do the job well enough. Generally, the least necessary part of this repo.

`/adversarial-review`, `/quality-review`, `/adversarial`, `/simplify`, `/chaos`, `/five-whys`, `/ralph-loop`, and `/daily-review` (a Notion, Gmail and Calendar review that needs those connectors). Commands are thin; the logic lives in the skill each one invokes.

## Scripts

**Promotion.** `promote.sh <path>` copies a file or directory from the current project to the same path here. `check-promotion.sh --surface` lists promotable and drifted tooling; `--gate` blocks a commit on drift and is what every managed project's pre-commit runs. A project opts a file out with `.claude/promotion-ignore`. `install-global.sh` wires the global pre-commit and the SessionStart detector.

**Public-repo gates.** `verify-clean.py --staged` runs on every commit here and denies client names, people, identifiers and home paths from `scripts/denylist.local.json` (gitignored, never ships) plus regex classes for UUIDs, IPs and emails. `scrub.py` replaces the same terms with `{{TOKEN}}`s. `check-knowledge.sh` fails a commit when a Serena memory on disk is missing from the memory index, or a skill is installed but not routed.

**Repo hygiene.** `check-okf.sh` (frontmatter drift), `check-backlinks.sh`, `check-root-strays.sh`, `check-context-budget.sh` (size of always-on context), `check-new-names.sh`, `check_grep_blindspots.py` (probe visibility), `scan-large-payload.sh`, `check-deliverables.sh`, `log-correction.sh`, `sync-scheduled-tasks.sh`, `rebuild-plugin.sh`, `new-project.sh`.

## Catalog

`assets/` holds sanitized, tokenised skills harvested from real projects, indexed in `catalog.json` with each asset's adaptation points. Eight today: `five-whys`, `writing-quality`, `meeting-workflow`, `governance-skill-template`, `project-bootstrap`, `graduate-project`, `notion-governance`, `yellow-sheet-corpus`.

A skill lands in `assets/` rather than `.claude/skills/` when a project's filled copy legitimately differs from the canonical one (client paths, matter names). `check-promotion.sh` skips a project's copy of any catalog asset, so the filled copy never reads as drift. To set up a new project from the catalog, invoke `project-bootstrap`: it profiles the project, proposes an install set, copies assets, fills tokens and writes a `TOOLING.md` manifest.

## Rules and templates

Here's how we enforce behavioral patterns.

`.claude/rules/routing-protocol.md` (Classify → Load → Think → Pre-flight → Validate) and `kiss-yagni.md` (KISS, YAGNI, Two Strikes, Blocker Protocol, Cascade Re-Scope) load in every project.

`templates/` carries the router (`CLAUDE.md.template`), the PRD and plan templates, a gitignore, a `knowledge-check.conf`, the three-stage research → draft → final pipeline (`stage-pipeline/`), and a scheduled-task template. `global/` holds the snippet for a user-level `CLAUDE.md` and the global pre-commit and session detector that `install-global.sh` installs. `knowledge/log.md` is this repo's own decision log, newest first.

## Not in the template

Domain governance for a specific workspace, document generators, and source-handling rules for a particular client live in that project's own `.claude/`. The port-header pattern (a skill naming which of its upstream routes are unreachable from a given repo) is reusable; the ported skills are not.

## Layout

```
clybor-claude-tooling/
├── README.md
├── catalog.json                    # index of assets/, with adaptation points
├── .claude/
│   ├── agents/                     # quality/ code/ orchestration/ research/ (19)
│   ├── skills/                     # 27 skills: build-* pipeline, review, ralph loops, governance, prose
│   ├── commands/                   # 8 slash commands
│   ├── hooks/                      # gates, each with its test-*.sh negative control
│   ├── rules/                      # routing-protocol.md, kiss-yagni.md
│   └── settings.json.template      # the default hook wiring
├── assets/skills/                  # tokenised catalog skills (8)
├── scripts/                        # init, promote, check-promotion, verify-clean, scrub, gates
├── templates/                      # CLAUDE.md, PRD, plan, gitignore, stage-pipeline, scheduled-tasks
├── global/                         # user-level CLAUDE.md snippet, global pre-commit, session detector
└── knowledge/log.md                # this repo's decision log
```

## Updating

This repo is the source of truth. Change it here, commit through the gates, then either re-run `init.sh` against a project or copy the single file across. Never edit a project's copy of shared tooling without promoting the change back; the drift gate will stop the project's next commit until you do.

## User journeys

Five scenarios showing how the pieces compose in the lighter flow.

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

## Catalog (assets/ + catalog.json)

Sanitized, reusable tooling harvested from real projects — indexed in `catalog.json`,
PII-gated by `scripts/verify-clean.py` (pre-commit). To set up a NEW project from the
catalog, invoke the `project-bootstrap` skill (assets/skills/project-bootstrap/) — it
profiles the project, proposes an install set, copies assets, fills adaptation tokens,
and writes a TOOLING.md manifest. Rebuilds of the catalog itself: scrub with
`scripts/scrub.py`, verify with `scripts/verify-clean.py` (token mode enforces that
every {{TOKEN}} is declared in catalog.json adaptation_points).
