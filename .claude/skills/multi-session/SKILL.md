---
name: multi-session
description: Run, type into, and SEE other interactive Claude Code sessions from this one, through Orca terminal tabs. Use to test anything that only shows up on screen (the /workflows progress view, a slash command's output, a permission prompt), to run a workflow stage in a fresh session, or to run independent sessions side by side and read their results. Triggers — "open another session", "run it in a fresh session", "test what the screen looks like", "watch the other session", "drive Claude in a terminal". Needs the `orca` CLI. For a result you only need as text, use headless `claude -p` instead (cheaper, no screen). General Orca terminal and worktree reference: `orca skills get orca-cli`; supervised worker fleets: `orca skills get orchestration`.
---

# Multi-session — drive other Claude Code sessions

You are not limited to this session. From Bash you can open a new Claude Code session in an Orca
terminal tab, type into it, and read its **rendered screen**. The user sees the tab in Orca too.

This skill covers what is specific to driving **Claude Code**. For everything else about Orca
terminals (handles, receipts, worktrees), run `orca skills get orca-cli`.

## Pick the lighter tool first

| Need | Use |
|---|---|
| A result as text (an answer, a file written, a smoke test) | `claude -p "<prompt>"` from Bash. No screen, cheapest |
| What a screen looks like, or an interactive-only feature | This skill |
| Many workers with task tracking and replies | `orca skills get orchestration` |

## The loop

```bash
# 1. Open. Launch Claude bare: a prompt on the command line can be lost (gotcha 1).
H=$(orca terminal create --worktree active --title "<name>" --json \
  --command "cd <dir> && claude --permission-mode acceptEdits --allowedTools 'Workflow,Read,Grep,Glob,Write,Edit,Bash'" \
  | grep -o 'term_[0-9a-f-]*' | head -1)
orca terminal wait --terminal $H --for tui-idle --timeout-ms 30000 --json   # read wait.satisfied

# 2. Look before you type.
orca terminal read --terminal $H --screen

# 3. Type. --wait-submit proves the turn started; input_accepted alone does not.
orca terminal send --terminal $H --text '<prompt or /command>' --enter --wait-submit 15

# 4. Watch. Foreground sleep is blocked: use Monitor with an until-loop on the screen.
until orca terminal read --terminal $H --screen | grep -q '<done marker>'; do sleep 5; done

# 5. Close when finished. This kills that Claude process.
orca terminal close --terminal $H
```

Keys: arrow down is `--text $'\e[B'`, Esc is `--text $'\e'`, and Enter alone is `--text "" --enter`.

## Gotchas (all measured)

1. **The folder-trust dialog eats the first prompt.** In a folder Claude hasn't opened before, a
   prompt passed on the command line is lost behind "Do you trust this folder?". Launch bare, read
   the screen, accept (arrow down, then Enter), then `send` the prompt.
2. **An open panel eats typed prompts.** While `/workflows` (or any full-screen panel) is open, a
   sent prompt is dropped and the receipt still says `input_accepted`. Send Esc first. Treat a
   receipt without `turn_started` as **not delivered**.
3. **Use `read --screen` for anything visual.** A plain `read` returns the raw stream: repainted
   lines arrive as stacked fragments and TUI layout is lost.
4. **`/workflows` opens only when sent on its own.** Send it, then `read --screen`. With one run in
   the session it opens that run's progress view directly.
5. **Permissions decide whether a run stalls.** An unattended session stuck on a prompt waits
   forever. Pass `--permission-mode` and `--allowedTools` at launch. A saved workflow also needs
   `Workflow` (or `Workflow(<name>)`) allowed, or it asks first.
6. **Each session costs a full context.** A fresh session loads the CLAUDE.md files, skills and
   tools of the folder it opens in. Use a scratch folder with a tiny fixture when you only need
   to test behaviour.
7. **Close what you open.** Tabs persist after your turn ends. List them with `orca terminal list`.

## Report

Tell the user which tab you opened (its title), what you sent, and what the screen showed, quoting
the lines from `read --screen`. Never describe a screen you did not read.
