# think-first

think-first makes Claude Code run a sequential-thinking step at the two moments where
acting without a plan costs the most:

1. **Before the first write in each turn.** A turn starts with each new request, whether
   typed, sent with `claude -p`, sent from a phone, fired by a schedule, or sent by another
   session. A background task finishing doesn't start a new turn.
2. **Before retrying a tool call that just failed.** A plan made earlier in the turn doesn't
   cover a failure that came after it.

One successful thinking step covers every write in the turn and clears earlier failures.

## It installs what it needs

The plugin declares the Model Context Protocol sequential-thinking server
(`@modelcontextprotocol/server-sequential-thinking`, pinned to `2025.11.25`). Claude Code
starts it with `npx` when the plugin loads; there's nothing else to install. If you already
run a server under the same name, Claude Code uses yours and skips the plugin's duplicate.
think-first accepts any tool whose name ends in `sequentialthinking`.

## Configure

Run `/plugin configure think-first`, then set:

| Setting | Meaning | Default |
|---|---|---|
| `writes` | Which tools count as writes. Patterns are separated by `;`. A glob uses `*`; `/regex/flags` matches anywhere in the tool name. | MCP tools whose names contain create, update, delete, send, post, publish, upload, move, remove, insert, execute, write, apply, deploy, trash, share, edit or merge |
| `retries` | Which tools need a thinking step before they're retried after a failure, in the same format. | `mcp__*` |
| `mode` | `enforce` blocks the call. `warn` lets it run and tells Claude it skipped the step. | `enforce` |

## When the thinking tool itself is down

- **A malformed call** (wrong or missing parameters) means the server answered, so it's
  healthy. Claude has to fix the call.
- **Two real errors in a row** mark the server unavailable for the rest of the turn. Writes
  then go through, with a note telling Claude to say in its reply that it couldn't think
  first. This means a broken server can't deadlock the session.

## When the gate itself fails

If a setting can't be read, or the gate crashes, think-first blocks MCP tools and every
write. It never blocks the thinking tool itself, so there's always a way out.

## Where it runs

think-first is a mod: a plugin with code that runs inside Claude Code. It needs Claude Code
2.1.287 or later, with mods on. Mod hooks run in the terminal, in the Desktop app's Code
tab, under `claude -p` and in the Agent SDK. Anthropic's documentation doesn't list Claude
Cowork, and think-first hasn't been tested there.

## What it reaches

`claude plugin validate .` lists everything the module touches. It hooks `prompt.submit` and
`tool.call`, and its only call is `$.env.get` for one variable, `THINK_FIRST_FAULT`. The
module makes no network requests and reads or writes no files. The bundled server is
started by Claude Code itself, with `npx` downloading the pinned package from the npm
registry.

## Verify it

Each check below has been shown to fail as well as pass:

```bash
claude plugin test .          # 17 behaviour tests
python3 scripts/mutate.py     # breaks the gate 15 ways; every break must turn a test red
bash scripts/e2e.sh           # real sessions: server self-install, blocked, unblocked after thinking, retry blocked, control
```

`THINK_FIRST_FAULT=1` in the environment makes the gate crash on purpose. That's how the
"blocks when it crashes" behaviour is tested.
