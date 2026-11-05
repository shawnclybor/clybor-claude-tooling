---
name: insight-builder
description: Build and prove a fix for an infrastructure or tooling problem once the cause is known and the lesson is filed. Step 3 of the insight chain (five-whys or why-diagnostic, insight-crystallizer, insight-builder, insight-promotion). Use when something must actually change (a script, hook, gate, config, scheduled-task prompt, plugin or skill) or the user says "build the fix", "fix it properly", "insight builder", "harden this" or "make this a gate". It checks the live system first, asks the simplifier for an easier way, makes the smallest change, runs every test twice (clean, then proven able to fail), has the chaos-engineer try to break it, ships it, proves it shipped and recommends the next step. Works in Claude Code and Cowork. Not for diagnosis, filing the lesson or promotion.
---

# Insight Builder

Turns a diagnosed problem into a fix that is small, tested both ways, and proven to have shipped.

<!-- INSIGHT-CHAIN v1 -->
## The insight chain

Type "insight" to find the trio. Each step ends by recommending the next one.

| # | Skill | Required? | What it gives you |
|---|---|---|---|
| 1 | `five-whys` or `why-diagnostic` | Optional | The cause, or an honest "cause not established" |
| 2 | `insight-crystallizer` | **Always** | The lesson, filed so it outlives the chat |
| 3 | `insight-builder` (this skill) | Optional | A built fix, tested twice, proven shipped |
| 4 | `insight-promotion` | Optional | The lesson made always-on, pointing at the fix |

Fix before promote. A rule written before its fix is proven tells every future session to
follow a guess. When the only change is a rule, skip this skill and use `insight-promotion`,
unless a script or gate could enforce it instead. Then build that here.

## Before you start

You need two things. If either is missing, stop and say which.

1. **What to change.** "Something is wrong with X" is not enough. "X blocks writes when its
   thinking server errors twice" is.
2. **The filed lesson** from `insight-crystallizer`. Missing: run it first. It is the one
   mandatory step.

## The steps

Do them in order. Report each one in a line before moving on.

### 1. Look at the real thing

Read the live file, prompt or setting where it actually runs, not a copy or your memory of it.

- **Claude Code:** the normal shell and file tools.
- **Cowork or any cloud session:** drive the user's machine with Desktop Commander
  (`start_process`, `read_file`, `edit_block`). A cloud shell edit never reaches the machine.
- Scheduled-task prompts live on the server. Read them there, not from a local backup copy.

**Run the existing tests before any edit and write down the result.** A test that was already
failing is a finding, not noise. Fix it or name it. Never let it hide inside "tests pass".

### 2. Ask for an easier way

Run the simplifier on the planned change (`/simplify`, or the `simplifier` agent in
`.claude/agents/quality/`). One question: is there a smaller or simpler fix? Common answers are
a setting instead of code, an existing flag, deleting instead of adding, or a script instead of
a paragraph of rules. Take the simpler fix unless it fails the goal.

### 3. Build the smallest change

- Edit in place. Never retype a file's contents from a tool result.
- A plugin: run its rebuild script's stage step (`scripts/rebuild-plugin.sh <plugin> --stage`)
  before editing, so drift is caught and a backup exists for step 4.
- Comment the change with the date, the task or issue ID and one line on why.
- Commit only when the user asks. Repos often carry other sessions' uncommitted work.

### 4. Test twice

A test that has only ever passed proves nothing. Every new or changed test runs twice.

1. **Clean run:** the new tests and every existing test pass on the fixed code.
2. **Red run:** the new tests FAIL on the old code. Put the old code (the step-3 backup, or
   `git show HEAD:<path>`) in a temp folder and run the tests there. No old code: break the fix
   on purpose (flip the condition, delete the new line) and confirm the test goes red.

Red run passes: the test is blind. Fix the test, not the code. Clean run fails because of the
test setup (a wrong mock, a missing fixture): say so and fix the setup. That is not a code
failure.

The same edit or command failed twice: stop and change approach (Two Strikes).

### 5. Try to break it

Run the chaos-engineer on the fix (`/chaos`, or the `chaos-engineer` agent). Give it the change,
the files, and what the fix protects. Fix Critical and High findings now when they are in scope.
List the rest, one line each, where the project keeps deferred work.

### 6. Ship it and prove it shipped

- Plugin: promote with the rebuild script, then `scripts/verify-plugin-shipped.sh` with a
  distinctive new phrase. It must say SHIPPED for every installed copy.
- Synced tooling: `scripts/sync-down.sh <project>` dry run first, then `--apply`.
- Scheduled-task prompt: update it, then hash the stored prompt against the source file.
- Say plainly what still needs a restart or reinstall before the fix is live.

### 7. Record it

Update the task or knowledge-base entry with what changed, the commands run and their real
output (clean and red), the version shipped, and anything left open.

### 8. Recommend the next step

End every run with this block, filled in. Short, plain, numbered.

```
Next step
1. <one action, who does it>  (recommended)
2. <alternative, if any>
Why: <one sentence>
```

- **Promote it** (`insight-promotion`) when the lesson should change how every future session
  works, the problem has happened twice or more, or the fix is a gate sessions must know about.
- **Stop here** when the fix closes the problem and nothing future sessions do needs to change.
  Say "No promotion needed" and why.
- **Restart or reinstall first** when the fix is not live yet. Name the exact action.

## Rules

- No deletes. Move retired files into a `_to_delete/` folder next to them.
- "Tests pass" means the tests you ran passed. Name them.
- A change that leaves the workspace (email, client systems, money) is not this skill's call.
  Stop and ask.
