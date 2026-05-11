---
name: insight-promotion
description: Promote a crystallized insight or one-off realization into always-on governance — a CLAUDE.md hard rule, a .claude/rules/*.md section, or a skill SKILL.md addition. Use when the user says "promote this to governance", "add this as a rule", "make this always-on", "codify this", "add to the router", or "this needs to be a rule not a note". Also trigger proactively right after insight-crystallizer when the insight meets promotion criteria (pattern recurred twice or more, describes a governance gap, prevents a known failure mode). Crystallizer captures knowledge; promotion makes knowledge enforceable.
---

# Insight Promotion

Bridge the gap between "filed under `docs/insights/`" (retrieval-dependent, only surfaces if someone searches) and "always-on governance" (loaded into every session that touches the domain).

## The rule

> Insight directories hold knowledge. `.claude/rules/` and `CLAUDE.md` hold enforcement. If an insight needs to shape behavior on the NEXT session without anyone searching for it, it has to be promoted.

## Promotion criteria

Promote if ANY of these is true:

1. **Pattern recurrence** — the insight describes a failure or decision that has come up twice or more. Filing it as another note will not change the third recurrence.
2. **Governance gap** — the insight reveals that existing rules are silent on a real scenario.
3. **Failure prevention** — the insight documents a specific, reproducible failure mode with a known fix.
4. **Cross-session applicability** — the insight is relevant to future sessions that will not mention the originating context.

Skip promotion if:

- The insight is project-specific and already lives in a project-scoped rule file.
- The insight is a one-off fact — that belongs in a memory file or comment, not governance.
- The insight contradicts existing governance without evidence. Open a discussion first.

## Target file selection

| Target | When | Example |
|---|---|---|
| `CLAUDE.md` Hard Rules section | Universal rule that applies to ALL requests | "Two Strikes — same op fails twice → STOP" |
| `CLAUDE.md` Router table | New domain or new skill / rule file added | Routing row for a new governance file |
| `.claude/rules/<domain>.md` main body | Domain-specific protocol or workflow | API design rule, DB migration rule |
| `.claude/rules/<domain>.md` Known Issues | Specific bug or quirk with a one-off fix | "Tool X is broken on input Y; use workaround Z" |
| Skill `SKILL.md` | Behavior lives in a skill already | New decision branch in a deliberation skill |
| `routing-protocol.md` Pre-Flight Checklist | Universal pre-flight check that applies to every write | "Tool-audit gate — check for a CLI one-liner before installing a library" |

## The flow

### Step 1 — Classify

State the insight in one line. Identify which promotion criterion it meets and which domain (universal or scoped).

### Step 2 — Pick the target

Use the table above. If multiple targets apply, pick the narrowest scope that still catches the insight. A library-specific trap goes in `.claude/rules/<library>.md`, not `CLAUDE.md`.

### Step 3 — Draft the entry

Match the target file's existing format. Most rule files have rule sections, Known Issues tables, or checklists. Drafts must be tight — governance files pay an always-on context tax, so every word earns its place. If the insight takes 500 words to explain, it is not promotion-ready. Boil it down.

### Step 4 — Confirm before writing

Present three things: the target file plus section, the exact draft text, and why it belongs there and not elsewhere. Wait for approval, edit, or redirect. Do not edit governance files silently.

### Step 5 — Apply

Use `Edit` on the target file. For Known Issues tables, append a row. For new sections, insert at the right anchor.

### Step 6 — Cross-reference

If the promoted insight came from `docs/insights/`, add a `promoted_to:` field to the insight's frontmatter pointing at the new governance location. Otherwise the insight becomes stale.

If a routing row was added, verify the routing source-of-truth (`CLAUDE.md`) reflects it.

## Pre-flight checklist

Before promoting any insight:

1. Does it meet at least one promotion criterion?
2. Is there a narrower home than `CLAUDE.md` Hard Rules? (Default to narrower.)
3. Have I drafted the exact text, not just a summary of the idea?
4. Have I confirmed with the user before editing?
5. Does the entry match the target file's existing format?
6. If the insight came from `docs/insights/`, have I updated the source frontmatter with `promoted_to:`?

## Append formats

### Known Issues row (most common)

```markdown
| YYYY-MM-DD | One-sentence description of the issue as observed. | One-sentence fix or workaround. Reference the governance change. |
```

### New Rule section

```markdown
## Short Title (promoted YYYY-MM-DD)

> One-sentence summary of the rule in bold or blockquote.

Two to four sentences of context: what the rule prevents, when it applies, what the failure mode looks like if you skip it. Keep it tight.

Example (if essential): minimal concrete case.
```

### CLAUDE.md Hard Rule

```markdown
N. **Rule Name** — one-sentence statement of the rule and its scope.
```
