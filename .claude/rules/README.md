# Rules

Auto-loaded governance read on every non-trivial request. Small on purpose. Anything domain-specific belongs in a per-project rule file or a plugin, not here.

## Bundled

- **routing-protocol.md** — The 5-step ritual that runs on every non-trivial request: Classify → Load → Think → Pre-flight Checklist → Validate. Includes the tool-audit, date-window, iteration, and extraction gates.
- **kiss-yagni.md** — KISS / YAGNI principles, Two Strikes Rule, Blocker Protocol, Cascade Re-Scope, Honor-System Gates rule (codify as scripts when prose-only rules fail).

## Adding rules

Before adding a rule here, ask: is this universally relevant to every project that uses this template? If no, put it in the project's own `.claude/rules/`.

Universally relevant means: it would apply equally to a Python backend, a TypeScript frontend, a research repo, a documentation site. If it would not, it is project-specific.

Rules are paid for in always-on context. Every word in this folder costs context on every request. Keep them tight.
