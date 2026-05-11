# {{FEATURE_TITLE}} — PRD

**Status:** draft
**Slug:** {{FEATURE_SLUG}}
**Owner:** {{OWNER}}

## 1. Problem

[1-3 paragraphs. What is the user / system pain? What is the current state? Why now?]

## 2. Success criteria

Each criterion is binary — verifiable by running a command, reading a file, or observing a measurable signal. Vibes-shaped criteria belong in `## 7. Open questions`, not here.

- [ ] [Criterion 1 — e.g., "P95 latency on `/login` under 200ms across 100 test requests"]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## 3. In scope

- [What is included]

## 4. Out of scope

- [What is explicitly NOT included — anti-scope prevents scope creep]

## 5. Dependencies

- [External systems, libraries, APIs, datasets, credentials, decisions that must land first]

## 6. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| [Specific failure mode] | common / occasional / rare | [How it is prevented or handled] |

## 7. Open questions

- [Anything unresolved that affects design]

---

**How to use:** copy this file to `docs/PRDs/<feature-slug>.md`, fill it in, and invoke the `prd-writer` skill if you want guided refinement. The `task-plan` skill consumes this file at Stage 2; `verify` consumes the success criteria at Stage 5.
