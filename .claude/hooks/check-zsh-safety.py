#!/usr/bin/env python3
"""check-zsh-safety.py -- PreToolUse gate on Bash: reject zsh-hostile shell idioms.

The Bash tool runs `zsh -c`, not bash. Two zsh defaults break idioms written from bash habit, and
both fail in ways that are easy to misread as success:

  EQUALS expansion -- a word beginning with `=` is resolved to a command's path. Measured 2026-08-30:
    zsh -c 'echo start; echo ===; echo after'   -> prints start, errors "== not found", NEVER prints
                                                   after. The whole script aborts, across `;`.
    zsh -c 'echo =ls'                           -> prints /bin/ls. No error at all: silently wrong.
    zsh -c '[ x == x ]'                         -> errors "= not found". `[[ x == x ]]` is fine.
  NOMATCH -- an unquoted glob with no match is an error, not a literal. Measured:
    zsh -c 'grep -rn x --include=*.md .; echo after' -> grep never runs, `after` prints, SCRIPT RC 0.

The cost is not the error message. It is a PARTIAL result returned as a whole one: the commands that
never ran leave no trace of not having run, so a batched call reads as complete with one warning.
That is the same defect shape as a skip line that prints nothing.

WHAT THIS DOES NOT COVER (stated, not silently capped):
  * General unquoted globs (`ls *.md`). Same NOMATCH risk, but flagging every glob would be unusable;
    only globs destined for a TOOL rather than the shell are flagged, where quoting is always correct.
  * Anything inside a heredoc body, a comment, or quotes -- measured safe, so deliberately skipped.
  * zsh options the user may have set (NO_NOMATCH, NO_EQUALS) are not consulted: the hook encodes the
    default this harness actually runs under.

FAIL-OPEN by design: unreadable input, unparseable JSON or an internal error exits 0. A convenience
gate that blocks every Bash call when it breaks is worse than the failure it prevents.

  hook mode:  PreToolUse JSON on stdin      exit 0 allow, exit 2 block (stderr shown to Claude)
  cli  mode:  check-zsh-safety.py --check '<command>'      same exit codes, for the negative control
"""
import json
import sys

GLOB = set("*?[")
FIND_OPTS = {"-name", "-iname", "-path", "-ipath", "-wholename", "-iwholename", "-regex", "-iregex"}
WORD_BREAK = set(" \t\n;|&()<>")


def scan(cmd):
    """Return a list of (word, quoted_mask, prev_word, bracket_depth).

    quoted_mask[i] is True when word[i] reached the word through quoting or a backslash escape --
    zsh applies neither expansion to those characters, so they are never a finding. Heredoc bodies
    and comments are consumed and never yielded.
    """
    words, chars, mask = [], [], []
    quote = None            # None | "'" | '"'
    depth = 0               # [[ ... ]] nesting; EQUALS does not apply inside
    heredocs = []           # [(delimiter, strip_leading_tabs)] awaiting the next newline
    started = False
    i, n = 0, len(cmd)
    prev = ""

    def flush():
        nonlocal chars, mask, started, prev, depth
        if started:
            w = "".join(chars)
            if w == "[[":
                depth += 1
            elif w == "]]":
                depth = max(0, depth - 1)
            else:
                words.append((w, list(mask), prev, depth))
            prev = w
            chars, mask, started = [], [], False

    while i < n:
        c = cmd[i]
        if quote is None and c == "\\":
            if i + 1 < n:
                chars.append(cmd[i + 1]); mask.append(True); started = True
                i += 2
                continue
            i += 1
            continue
        if quote is None and c == "#" and not started:
            while i < n and cmd[i] != "\n":
                i += 1
            continue
        if quote is None and c == "$" and i + 1 < n and cmd[i + 1] == "'":
            quote = "'"; started = True; i += 2
            continue
        if quote is None and c in "'\"":
            quote = c; started = True; i += 1
            continue
        if quote is not None:
            if c == quote:
                quote = None; i += 1
                continue
            if quote == '"' and c == "\\" and i + 1 < n:
                chars.append(cmd[i + 1]); mask.append(True)
                i += 2
                continue
            chars.append(c); mask.append(True)
            i += 1
            continue
        if c == "<" and i + 1 < n and cmd[i + 1] == "<":
            flush()
            i += 2
            strip = False
            if i < n and cmd[i] == "-":
                strip = True; i += 1
            if i < n and cmd[i] == "<":       # <<< herestring: no body to skip
                i += 1
                continue
            while i < n and cmd[i] in " \t":
                i += 1
            d = []
            while i < n and cmd[i] not in WORD_BREAK:
                if cmd[i] in "'\"":
                    i += 1
                    continue
                d.append(cmd[i]); i += 1
            if d:
                heredocs.append(("".join(d), strip))
            continue
        if c == "\n" and heredocs:
            flush()
            i += 1
            for delim, strip in heredocs:
                while i < n:
                    j = cmd.find("\n", i)
                    line = cmd[i:] if j < 0 else cmd[i:j]
                    i = n if j < 0 else j + 1
                    if (line.lstrip("\t") if strip else line).rstrip() == delim:
                        break
            heredocs = []
            continue
        if c in WORD_BREAK:
            flush()
            i += 1
            continue
        chars.append(c); mask.append(False); started = True
        i += 1

    flush()
    return words


def findings(cmd):
    out = []
    for word, mask, prev, depth in scan(cmd):
        if not word:
            continue
        if word[0] == "=" and not mask[0] and depth == 0:
            out.append((
                "EQUALS expansion", word,
                "a word beginning with `=` is resolved to a command's path -- this either errors and "
                "ABORTS THE WHOLE SCRIPT (even across `;`), or silently substitutes a path",
                'quote it (echo "===") or use a different separator (echo ---); inside a test, use [[ ]] '
                "rather than [ ]",
            ))
            continue
        if word[0] == "-" and not mask[0] and "=" in word:
            eq = next((k for k, ch in enumerate(word) if ch == "=" and not mask[k]), -1)
            if eq >= 0 and any(word[k] in GLOB and not mask[k] for k in range(eq + 1, len(word))):
                out.append((
                    "NOMATCH on a tool-destined glob", word,
                    "this glob is meant for the tool, but zsh expands it first and ERRORS when nothing "
                    "matches -- the command never runs, while the script's exit code can stay 0",
                    "quote the pattern: " + word[:eq + 1] + "'" + word[eq + 1:] + "'",
                ))
                continue
        if prev in FIND_OPTS and any(word[k] in GLOB and not mask[k] for k in range(len(word))):
            out.append((
                "NOMATCH on a tool-destined glob", word,
                "zsh expands this before " + prev + " ever sees it, and ERRORS when nothing matches",
                "quote the pattern: " + prev + " '" + word + "'",
            ))
    return out


def report(cmd):
    f = findings(cmd)
    if not f:
        return 0
    lines = ["BLOCKED (zsh-safety): the Bash tool runs `zsh -c`, and this command is not zsh-safe.", ""]
    for rule, word, why, fix in f:
        lines += ["  " + rule + " -- offending word: " + word, "    why: " + why, "    fix: " + fix, ""]
    lines.append("Rewrite and retry. Nothing ran.")
    print("\n".join(lines), file=sys.stderr)
    return 2


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--check":
        sys.exit(report(sys.argv[2]))
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if payload.get("tool_name") != "Bash":
        sys.exit(0)
    cmd = (payload.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str):
        sys.exit(0)
    try:
        sys.exit(report(cmd))
    except Exception:
        sys.exit(0)


if __name__ == "__main__":
    main()
