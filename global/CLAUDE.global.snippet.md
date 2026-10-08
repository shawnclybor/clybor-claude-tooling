## Reusable tooling → clybor-claude-tooling (always on)

Reusable tooling has ONE canonical home: `~/gits/clybor-claude-tooling`. This covers Claude **skills, hooks, validators, slash commands, agents**, and **project scaffolding patterns** (the router CLAUDE.md, project-rule, and Karpathy knowledge-wiki structure).

When you build or improve something reusable in any project, **promote it**: `~/gits/clybor-claude-tooling/scripts/promote.sh <path>`, then commit it there. A project's copy must not **drift** from canonical — the global pre-commit hook blocks committing drift, and the SessionStart hook surfaces promotable/drifted tooling each session. (Honor-System Gates Fail — Codify as Scripts.)

## Reporting back (always on)

When you finish a piece of work, write the report for a busy reader. The work is knowledge work as much as code, so the report reads like a briefing, not a build log.

1. **Big picture first**, in a few plain sentences: what the session was about, what you did, and how well it worked. Say plainly what failed or is only partly done.
2. **Then the open issues**, one short item each: what it is, why it matters, and whether it needs me or nothing.
3. **Name things by what they are.** Write "the tracker check" or "the launch brief", never internal labels like R1, D7, Task 6 or a commit hash. Leave out file names, IDs and settings unless I need them to act, and then say what each one is.
4. **Plain language.** Keep technical jargon to a minimum. No padding, no closing pleasantries.

A direct question gets a direct answer; this shape is for reports on finished work.
