---
name: write-guide-skill
description: Writes a guide skill, the skill Claude must load before using a tool, for any MCP server or built-in tool that has none. A guide skill is one part rules and one part operating manual, in a fixed format a checker verifies. Use when read-first blocks a call and no guide skill exists, when strict mode blocks an unmapped MCP tool, or when someone says "write a guide for [tool]", "we just connected [tool]", "this tool keeps biting us", or "add [tool] to read-first". Probes the tool, asks only what the probe cannot answer, drafts from the template, checks it, then gives the exact read-first rule to add. Cheap to write, expensive to learn a tool's traps one wrong write at a time.
---

# Write a guide skill

A **guide skill** is the skill Claude loads before it uses a tool. It has two parts, always
in this order:

1. **Rules** — what needs a person's approval first, what is off-limits, and the yes/no
   checks before any write.
2. **Operating manual** — the setup, which tool to pick when several overlap, the workflow,
   and the known issues.

read-first only checks that the guide skill was loaded. What the guide says is what Claude
then follows, so the content is where the value lives.

The template is `templates/guide-skill.md` and the checker is
`scripts/check-guide-skill.py`, both two folders up from this skill's own folder (the
plugin's root).

## Step 1 — Probe (spend none of the person's attention on what you can find yourself)

1. **List the tools.** For an MCP server, its `mcp__<server>__` prefix is the inventory.
   Record each verb and resource (create, get, list, update, delete).
2. **Read the server's instructions block** if it ships one. Mine it for traps.
3. **Make one cheap read call** (a list, a get, an account lookup) and look at the real
   response: where IDs sit, whether it paginates, whether content is wrapped.
4. **Check for overlap.** If another connected tool covers the same service, the
   operating manual needs its "Which tool when" table.

## Step 2 — Ask only the gaps

In plain text, as one short list:

1. Which account, workspace and recurring IDs matter?
2. Has this tool already burned you? (wrong target, silent replace, stale data) Each answer
   becomes a dated Known issues row.
3. Which operations can't be undone, or reach other people? Those go under "Needs approval
   first".
4. Is anything off-limits entirely? That goes under "Never".

## Step 3 — Draft from the template

Copy `templates/guide-skill.md` to `.claude/skills/<tool>-guide/SKILL.md` in the project, so
it travels with the repository (cloud sessions read a repo's `.claude/skills/`, not your
machine's). Fill every section. Keep the headings exactly as the template writes them;
the checker reads them.

- **Do not invent traps.** If nothing has gone wrong yet, keep the "None confirmed yet" row.
- **Every known issue carries a date** (YYYY-MM-DD). It is an incident record, not caution.
- **Checks are yes/no**, each tied to a failure you can name.
- **The description is matched, not read.** Put trigger phrases early, name the single
  worst trap, and never use a colon followed by a space in it.

## Step 4 — Check it

```
python3 <plugin root>/scripts/check-guide-skill.py .claude/skills/<tool>-guide/SKILL.md
```

Fix every FAIL line and run it again until it prints PASS.

## Step 5 — Wire it into read-first

Give the person the exact rule to add, and how:

```
/plugin configure read-first
rules:  ...existing rules...; mcp__<server>__* => <tool>-guide
```

Then load the new guide skill with the Skill tool and retry the call that was blocked. If
the Skill tool does not list it yet, the session needs a restart to see it.

Stop at "draft written, check passed, rule given." The person reviews the guide skill
before it is relied on.
