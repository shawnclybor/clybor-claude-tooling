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

Six scenarios, as the tooling runs today.

### 1. A build, start to finish

> *"Build the thing the client asked for on Tuesday."*

**Stage 1, `build-prd`.** Question-driven discovery that locks four things before any code: the target, success criteria that are binary, one anchor case with its expected outcome, and the out-of-scope list. The PRD lands at `.claude/PRPs/<slug>/prd.md`. Two anchors, never merged: a CRITERIA anchor (one concrete input, what comes out) and an OPERATIONAL anchor (the whole corpus, exit codes, counts).

**Stage 2, `build-probe`.** Every number, count, filename and line reference the PRD asserts becomes a small script that prints one value, with the expected value in `expected.tsv` and every cited file pinned by hash in `sources.lock`. `run.sh` passes only when every probe emits what the PRD says and no source has moved. A mismatch means fix the PRD or fix the probe; editing the expected value to match is what turns the gate into a mirror. Claims a script cannot decide are marked UNPROVABLE and carried to the next stage. This re-runs in seconds at every later stage.

**Stage 3, `build-validate`.** One page, `premises.md`: the three to five claims about the world the design rests on, each with what becomes incoherent if it is false and who can settle it. The pass condition is written into `validate.md` before any agent runs. Three named agents, one message, once: a premise auditor (what is the design relying on that the page does not say), a falsifier (CONTRADICTED / SUPPORTED / NO EVIDENCE per premise against the sources), an oracle auditor (name one case where every criterion passes and the output is still wrong for its reader). A premise the owner settles is closed and never reopened. When nothing is contested, skip the stage and record the skip.

**Stage 4, `build-plan`.** One runnable increment, no more. The acceptance driver is written first and red. `check-plan-soundness.py` gates the plan in under a second: DONE checks that grep a string the task itself wrote, artifacts the test uses that no task authors, DONEs depending on later tasks, criterion drift across documents, cycles, duplicate ids, unpinned citations, prose-named artifacts. No panel.

**Stage 5, `build-estimate`.** Optional. Projects the remaining effort from the calibration ledger of measured builds. Never a gate and never an argument for scope.

**Stage 6, `build-execute`.** Bounded iteration with hard caps. Adversarial review runs only when a change touches a contract, a pinned constant, a refusal limb or a path no mutation covers. Each increment adds its mutation rows and runs only those; the full mutation table runs once, at evaluate. Once a build runs and carries a suite that can fail, the harness is the reviewer.

**Stage 7, `build-evaluate`.** Binary verdict against the anchor cases, with cold-read agents fanned out. FAIL calls five-whys; PASS with a new pattern calls insight-promotion. `state.json` records the stage, which detectors each round ran, every decision the owner made, and what is still awaiting a human.

### 2. Autonomous overnight grind

> *"Iterate this regex ruleset against the fixture corpus until every fixture passes."*

`/ralph-loop` with the prompt, a completion promise and an iteration cap. The Stop hook re-feeds the same prompt until the promise appears in the transcript or the cap is hit; deleting `.ralph-loop/state.json` cancels. This is for rote work with a deterministic check. Never run it on the same task as `build-execute`, and never on work that needs a judgment call between iterations.

### 3. Something failed twice

> *"The same command failed twice with the same error."*

Two Strikes. No third blind retry. `why-diagnostic` first if the framing is unclear; then `/five-whys`, which refuses to advance without a precise problem statement. `debugger` reproduces the failure and narrows the cause with evidence; `code-analyzer` traces the blast radius across files. The fix is the smallest change that addresses the root cause. Then the part that stops it recurring: `insight-promotion` writes the lesson as a rule and, wherever a script can check it, as a hook with a negative control. A rule nobody enforces gets skipped; a gate does not.

### 4. A document that will be reviewed more than once

> *"Tear this plan apart before I commit to it."*

`/adversarial-review`. The rubric loads before the target is read, so severity is a property of the finding and not of the round: must-fix means a false pass, a wrong deliverable or wasted days, and a finding that cannot name which is a note. The mechanical checker runs first and stops the review if it fails. `review-drift.py` checks whether earlier rounds have been ratcheting. Three lenses in one message, each with one question and told which classes are already machine-checked. Synthesis dedups, re-grades every claimed must-fix, and counts self-inflicted findings separately. The round is recorded; three rounds is the cap, and a fourth needs a written reason. Remaining doubt is resolved by building and running, not by reading again.

### 5. Prose a person will act on

> *"Draft the memo the settlement team will work from."*

`writing-quality` strips AI-isms. The write-time gates catch what reads fine and is still wrong: `check-empty-prose.py` denies slogans, flourish and filler; `check-document-claims.py` denies an absolute claim about a document that does not carry the line it rests on; `no-postmortem-validator.py` denies prose that narrates what changed instead of stating what is; `availability-claim-validator.py` denies "blocked" or "missing" without the evidence beside it. If the draft came from source material, `adversarial-re-read` runs a second pass against the source, because a first extraction misses a fifth of what is there, and `evidence-auditor` checks every quote and figure against where it came from. A decision worth keeping goes through `insight-crystallizer` so it survives the chat.

### 6. Promoting tooling back here

> *"That hook I built in the client repo is reusable."*

Every session starts with `check-promotion.sh --surface` listing tooling in the project that is not here yet, or has drifted from the copy that is. `promote.sh <path>` copies it across at the same relative path. In this repo the commit runs `verify-clean.py --staged`, which denies client names, people, identifiers and home paths; a hit is scrubbed at the source in the project first, so the two copies stay byte-identical and the project's drift gate stays quiet. A skill that is reusable as a pattern but filled with client specifics goes to `assets/` through `scrub.py`, which tokenises it, with a `catalog.json` entry declaring its tokens; the project's filled copy is then skipped by the drift check by design. Commit here, then the project's next commit passes its own gate.
