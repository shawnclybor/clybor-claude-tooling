# Agents

Nineteen subagents in four lanes, spawned with the Agent tool. Every file carries `name`, `description` and `model` in its frontmatter; none restricts `tools`, so each agent has whatever the session has. Read-only by convention: an agent reports, and the skill that spawned it decides what lands.

An agent that no skill, command or hook names does not get used. Sessions reach for the tools a skill puts in front of them, not for a roster. So the useful column below is **Called by**, measured on 2026-09-04 by grepping every skill, command and hook in this repo for the agent's name. Four agents are called by nothing; they are listed last, on purpose, and are the first candidates to cut.

## Quality (`quality/`)

Three non-overlapping lenses. Each gets one question, and a finding outside its column is dropped rather than reported; three agents reporting one defect is three counts of one problem. The boundaries are written down in `.claude/skills/adversarial-review/rubric.md`.

| Agent | Model | Owns | Called by |
|---|---|---|---|
| `adversarial-reviewer` | Opus | **Is it true?** Claims unsupported by evidence, reasoning that does not follow, a conclusion the cited source does not carry | `adversarial-review`, `quality-review`, `build-validate` (as the premise auditor), `build-evaluate`, `insight-promotion`; `/adversarial`, `/adversarial-review`, `/quality-review` |
| `chaos-engineer` | Sonnet | **What breaks it?** Failure modes, malformed input, empty and boundary states, ordering hazards, fail-open shapes | `adversarial-review`, `quality-review`, `build-validate` (as the oracle auditor), `insight-promotion`, `ooda`; `/chaos`, `/adversarial-review`, `/quality-review` |
| `simplifier` | Sonnet | **Is it more than it needs to be?** Over-engineering, premature abstraction, scope beyond the stated requirement | `adversarial-review`, `quality-review`, `build-evaluate`, `insight-promotion`; `/simplify`, `/adversarial-review`, `/quality-review` |

## Code (`code/`)

| Agent | Model | Does | Called by |
|---|---|---|---|
| `code-reviewer` | Sonnet | Read-only review of a diff or file set: correctness, blast radius, type safety, observability, security, naming | `ralph-implement`, `ralph-loop`, `skill-validator`, `verify` |
| `debugger` | Sonnet | Reproduces a failure, narrows the cause with evidence, proposes the minimal fix. `five-whys` is the protocol; this is the executor | `five-whys`, `why-diagnostic`, `ralph-implement`, `ralph-loop`, `skill-validator`; `/ralph-loop` |
| `code-analyzer` | Sonnet | Cross-file investigation: how does this actually work, where does it break. Investigation, not grading | `build-evaluate`, `verify` |
| `security-auditor` | Opus | OWASP-style audit of input handling, secrets, auth, injection, dependencies, crypto | `ralph-loop`, `verify` |

## Research (`research/`)

| Agent | Model | Does | Called by |
|---|---|---|---|
| `evidence-auditor` | Sonnet | Checks every quote, citation and figure in a document against its source. CONTRADICTED / SUPPORTED / NO EVIDENCE, with the file and line that decides it | `adversarial-re-read`, `build-validate` (as the falsifier), `writing-quality`, `insight-crystallizer`, `prd-writer`, `ralph-loop` |
| `research-analyst` | Sonnet | Multi-source synthesis with cited claims and disagreements preserved | `prd-writer`, `insight-crystallizer` |
| `search-specialist` | Haiku | One question, one cited answer: an API signature, an error code, an exact quote | `prd-writer` |
| `metadata-fetcher` | Haiku | Mechanical lookups: bibliographic data, DOIs, package versions, licences | `prd-writer` |

`evidence-auditor` is the most-called agent outside the quality lane. It is the second pass behind every extraction: the build pipeline's premise round uses it to falsify each stated premise against the sources, and `adversarial-re-read` uses it because a first extraction misses a fifth of what is there.

## Orchestration (`orchestration/`)

| Agent | Model | Does | Called by |
|---|---|---|---|
| `multi-agent-coordinator` | Sonnet | Tracks state across parallel agents, handles partial failure, coordinates handoffs | `quality-review`, `ralph-implement`, `ralph-loop` |
| `task-distributor` | Sonnet | Splits a task list into groups that can run in parallel without contended writes | `task-plan`, `ralph-implement`, `ralph-loop` |
| `error-coordinator` | Sonnet | Correlates failures across parallel agents to one root cause | `five-whys`, `ralph-implement`, `skill-validator` |
| `knowledge-synthesizer` | Sonnet | Folds several agents' reports into one, keeping disagreements visible | `quality-review`, `insight-crystallizer` |

## Called by nothing

| Agent | Model | Was meant to |
|---|---|---|
| `workflow-orchestrator` | Sonnet | Sequence multi-stage workflows with gates between stages. The build pipeline does this in skills, stage by stage, with `state.json` as the record |
| `agent-organizer` | Sonnet | Pick which agents fit a task. Every skill names its agents directly, so the choice is never open |
| `context-manager` | Sonnet | Curate shared context across handoffs. Skills pass what each agent needs in its prompt |
| `performance-monitor` | Sonnet | Surface agents that time out, retry or escalate. Nothing consumes the report |

They stay in the repo until a skill wants one. A project that needs a smaller roster removes them and lists its `agents/README.md` in `.claude/promotion-ignore`, since that README then describes the project's roster rather than this one.

## How the pipeline uses them

The build pipeline calls agents in exactly two places, both bounded. `build-validate` spawns three in one message, once per build: the premise auditor (`adversarial-reviewer`), the falsifier (`evidence-auditor`) and the oracle auditor (`chaos-engineer`), each with the pass condition already written down. `build-evaluate` fans out cold readers at the end. `build-execute` spawns a review only when a change touches a contract, a pinned constant, a refusal limb or an unmutated path. Everything else in the pipeline is a probe, a mechanical checker or the test harness, because those cost seconds and do not drift.

## Adding an agent

1. One lens. If its question overlaps an existing agent's column, it is a prompt for that agent, not a new file.
2. `model` in the frontmatter. Opus for judgment (adversarial-reviewer, security-auditor); Sonnet for the rest; Haiku for lookups.
3. Read-only unless its purpose requires writes, and then the description says so.
4. Name the skill or command that will call it, in the same commit. An agent with no caller joins the table above.
5. Description under 1,024 characters.

Project-specific agents (language specialists, framework experts, a stack's own reviewer) belong in the project's `.claude/agents/`, not here.
