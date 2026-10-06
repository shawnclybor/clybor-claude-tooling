# read-first

With read-first installed, Claude Code blocks a tool call until Claude has loaded the guide
skill you mapped to that tool.

A **guide skill** is one part rules and one part operating manual:

- **Rules:** what needs a person's approval first, what is off-limits, and the yes/no checks
  before any write.
- **Operating manual:** the setup, which tool to pick when several overlap, the workflow,
  and the known issues.

read-first makes sure Claude has read the guide skill before it touches the tool. It doesn't
check what the guide says; the guide does that work once it's loaded.

## What it does

- **Blocks a mapped tool until its guide skill is loaded.** The block message names the
  guide skill and tells Claude to load it and retry the same call.
- **Points to a fix when the guide skill doesn't exist.** The message names the bundled
  `write-guide-skill` skill. That skill probes the tool, asks only what it can't find out,
  drafts the guide from `templates/guide-skill.md`, and checks the draft with
  `scripts/check-guide-skill.py`.
- **Blocks when it can't decide.** If a rule can't be read, or the gate itself crashes, it
  blocks every MCP tool and every tool a rule names. Built-in tools that no rule names (Read,
  Edit, Bash) are never touched, so a broken gate can't stall the whole session.
- **Counts every way a guide skill loads:** typed as `/name`, called through the Skill tool,
  or preloaded into a subagent. It counts a guide skill only once its text actually reached
  Claude, so a failed load doesn't count. A guide loaded under its plugin prefix
  (`my-guides:notion-guide`) counts as `notion-guide`.

## Configure

Run `/plugin configure read-first`, then set:

| Setting | Meaning | Default |
|---|---|---|
| `rules` | `tool-pattern => guide[, guide]`, separated by `;` or newlines. A plain pattern is a glob over the tool's full name (`*` matches anything). `/regex/` matches anywhere in the name; use `^` and `$` to anchor it. | empty (the gate does nothing) |
| `match` | `all` requires the guide skills of every rule that matches. `first` requires only the first matching rule's, so rule order decides. | `all` |
| `mode` | `enforce` blocks the call. `warn` lets the call run and tells Claude which guide skill it skipped. | `enforce` |
| `strict` | Also blocks MCP tools that no rule covers, and points Claude to `write-guide-skill`. | `false` |

Example:

```
mcp__notion__* => notion-guide; /__send_/ => mail-guide, compliance-guide; WebFetch => web-guide
```

## The guide skill standard

Every guide skill has `## Rules` before `## Operating manual`. Rules has at least one list
item, and the operating manual ends with a dated `### Known issues` table. Check one with:

```bash
python3 scripts/check-guide-skill.py path/to/SKILL.md
```

## Where it runs

read-first is a mod: a plugin with code that runs inside Claude Code. It needs Claude Code
2.1.287 or later, with mods on. Mod hooks run in the terminal, in the Desktop app's Code
tab, under `claude -p` and in the Agent SDK. Anthropic's documentation doesn't list Claude
Cowork, and read-first hasn't been tested there.

## What it reaches

`claude plugin validate .` lists everything the module touches. It hooks `skill.prompt` and
`tool.call`, and its only call is `$.env.get` for one variable, `READ_FIRST_FAULT`. It makes
no network requests and reads or writes no files.

## Known limits

- **Resumed sessions start empty.** After `--resume`, guide skills loaded before the resume
  must be loaded again. That's deliberate: the gate only counts what it saw load.
- **Early-access API.** Anthropic marks the mod API as early access. It may change between
  releases.

## Verify it

Each check below has been shown to fail as well as pass:

```bash
claude plugin test .                    # 15 behaviour tests
python3 scripts/mutate.py               # breaks the gate 13 ways; every break must turn a test red
bash scripts/test-check-guide-skill.sh  # the format checker passes a good guide and fails 8 bad ones
bash scripts/e2e.sh                     # 3 real sessions: blocked, unblocked after loading, control without the gate
```

`READ_FIRST_FAULT=1` in the environment makes the gate crash on purpose. That's how the
"blocks when it crashes" behaviour is tested.
