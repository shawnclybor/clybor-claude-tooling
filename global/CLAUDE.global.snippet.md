## Reusable tooling → clybor-claude-tooling (always on)

Reusable tooling has ONE canonical home: `~/gits/clybor-claude-tooling`. This covers Claude **skills, hooks, validators, slash commands, agents**, and **project scaffolding patterns** (the router CLAUDE.md, project-rule, and Karpathy knowledge-wiki structure).

When you build or improve something reusable in any project, **promote it**: `~/gits/clybor-claude-tooling/scripts/promote.sh <path>`, then commit it there. A project's copy must not **drift** from canonical — the global pre-commit hook blocks committing drift, and the SessionStart hook surfaces promotable/drifted tooling each session. (Honor-System Gates Fail — Codify as Scripts.)
