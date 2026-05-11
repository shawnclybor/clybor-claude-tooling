---
name: prd-writer
description: Write a PRD (product requirements doc) for a new feature or non-trivial change. Output is a markdown file with problem statement, binary success criteria, in/out of scope, dependencies, and risks. Use at the start of any work that warrants a quality gate before implementation. Triggers — "write a PRD", "draft a PRD for X", "start with a PRD", "PRD for [feature]", "spec out [feature]". The success criteria written here become the verification gates downstream — they must be binary (yes/no answerable), not vibes.
---

# PRD Writer

A PRD here is short and operational. It is the contract between the problem and the implementation. If the success criteria are wrong, every downstream stage is wrong.

## When to use

- Starting a new feature with more than a trivial change
- A refactor that crosses module boundaries
- An integration where the contract with an external system matters
- Any change where the user wants a quality gate before code lands

## When NOT to use

- One-line fixes, typos, dependency bumps
- Spike work where the goal is to learn
- Bug fixes where the fix is mechanically obvious

## Inputs

- **`feature_slug`** — kebab-case identifier
- **`problem_statement`** — one paragraph: what is being built and why
- (optional) **`source_material`** — links, screenshots, prior art

If `problem_statement` is missing, ask before drafting. Do not infer.

## Source-gathering (when needed)

If the problem statement references external claims, libraries, papers, or product names, invoke:

- **`research-analyst`** — for deep multi-source synthesis (3+ sources to compare or summarize)
- **`search-specialist`** — for a single precise lookup (API signature, version, exact quote)
- **`evidence-auditor`** — to verify any claim the draft PRD attributes to an external source

These run before drafting, not after. A PRD with unverified citations is worse than one with no citations.

## Output

`docs/PRDs/<feature_slug>.md`, copied from `templates/prd-template.md` and filled in. Sections:

1. **Problem** — 1-3 paragraphs of current state + pain
2. **Success criteria** — binary checkboxes
3. **In scope** — what is included
4. **Out of scope** — anti-scope
5. **Dependencies** — what must land first
6. **Risks** — specific failure modes with likelihood and mitigation
7. **Open questions** — unresolved items

## The success criteria rule (most important)

Criteria must be **binary**. Each one passes a single test:

> Can a fresh reader, given the criterion plus the implementation, answer yes or no without judgment?

Bad (vibes): "Improve performance", "Make the code cleaner", "Handle edge cases gracefully"

Good (binary): "P95 latency on `/login` under 200ms across 100 test requests", "Cyclomatic complexity ≤ 8 for every function in `auth/`", "On invalid email, the API returns HTTP 400 with `{error: 'invalid_email'}` (verified by integration test)"

If a criterion cannot be made binary, it belongs in `## 7. Open questions` until resolved.

## Pre-flight checklist

Before writing the file:

1. Do I have the problem statement from the user, in their words?
2. Have I distinguished problem from solution? (PRD is about WHAT, not HOW.)
3. Is every success criterion binary? If not, fix or move to open questions.
4. Is there a clear out-of-scope section?
5. Have I listed dependencies even if "none"?
6. Are risks specific failure modes, not generic phrases?
7. If the PRD cites external claims, has `evidence-auditor` verified them?

## What happens next

The PRD feeds three downstream skills:
- `task-plan` — decomposes the PRD into a checkbox task list
- `verify` — uses the success criteria as the verification gates
- `quality-review` — runs the 3-agent team against the PRD before implementation starts

If the PRD is wrong, all three are wrong. Spend the time here.

## Anti-patterns

- Inferring success criteria from vibes — ask the user
- Burying solution in the problem — PRD describes WHAT, not HOW
- Vague risks — "things might break" is not a risk; "the third-party API rate-limits at 100 req/min" is
- Skipping out-of-scope — if you do not write the anti-scope, scope creeps
- 500-word PRDs for 20-line features — the PRD should be proportional to the work
- Unverified citations — every external claim runs through `evidence-auditor` before the PRD ships
- **`metadata-fetcher`** — invoked when the PRD references a paper, library, package, or repo by identifier (DOI, package name, repo URL). Returns the structured record (version, license, OA status, last release) so the PRD cites accurate metadata. Mechanical lookup; no analysis.
