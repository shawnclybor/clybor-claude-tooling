"""check_hook_wiring.py — every configured hook must name a script that exists.

WHAT IT CHECKS
--------------
Reads the project hook config and, for each hook command, resolves the script path it would
invoke and confirms that file is present. Also reports a `CLAUDE_PROJECT_DIR` that holds no
`.claude/`, since hook commands built on that variable resolve relative to it.

A missing hook script is invisible at runtime: the hook errors into a void, nothing routes on
the failure, and a healthy hook from another config source still prints normal startup output.
So the absence of a hook is not self-announcing, and this gate is what announces it.

WHAT IT REFUSES TO DO
---------------------
A command whose script path cannot be parsed is reported as UNVERIFIED, never as passing. An
unreachable check must not look like a clean one, and that applies to this gate's own coverage
first.

WHERE IT RUNS
-------------
SessionStart (via session-context.sh, --quiet) and pre-commit gate 8.

USAGE
    python3 scripts/check_hook_wiring.py           # check; exit 1 if a hook is broken
    python3 scripts/check_hook_wiring.py --quiet   # print only on failure

EXIT CODES
    0  every parsed hook resolves, and nothing is unverified
    1  a hook names a script that does not exist, or a command could not be parsed
    2  no config file, or no hooks configured (an empty check is reported, never passed)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def repo_root() -> Path:
    try:
        out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, check=True).stdout.strip()
        if out:
            return Path(out)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return Path.cwd()


ROOT = repo_root()
SETTINGS = ROOT / ".claude" / "settings.json"

# "$R"/path  or  "$CLAUDE_PROJECT_DIR"/path  -- the two root-relative shapes used here.
ROOT_REF = re.compile(r'"\$(?:R|CLAUDE_PROJECT_DIR)"/(\S+)')
# ${CLYBOR_TOOLING:-$HOME/gits/clybor-claude-tooling}/path
TOOLING_REF = re.compile(r'\$\{CLYBOR_TOOLING:-([^}]+)\}/(\S+)')


def _strip_args(path: str) -> str:
    """Drop trailing shell arguments and quoting from a captured path token."""
    return path.split()[0].strip('"\'')


def resolve(cmd: str) -> list[tuple[str, Path]]:
    """[(raw reference, resolved path)] for one hook command."""
    found: list[tuple[str, Path]] = []
    for m in ROOT_REF.finditer(cmd):
        rel = _strip_args(m.group(1))
        found.append((rel, ROOT / rel))
    for m in TOOLING_REF.finditer(cmd):
        base = m.group(1).replace("$HOME", str(Path.home()))
        rel = _strip_args(m.group(2))
        found.append((f"{base}/{rel}", Path(os.environ.get("CLYBOR_TOOLING", base)) / rel))
    return found


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--quiet", action="store_true", help="print only on failure")
    args = ap.parse_args(argv)

    if not SETTINGS.exists():
        print(f"HOOK WIRING — NO SETTINGS FILE at {SETTINGS}")
        print("  Reported, not passed: this check could not see its target.")
        return 2

    hooks = json.loads(SETTINGS.read_text(encoding="utf-8")).get("hooks", {})
    entries = [(ev, g.get("matcher", "<all>"), hk.get("command", ""))
               for ev, groups in hooks.items() for g in groups for hk in g.get("hooks", [])]
    if not entries:
        print("HOOK WIRING — NO HOOKS CONFIGURED")
        print("  Reported, not passed. If you expected hooks here, the settings file is wrong.")
        return 2

    missing: list[str] = []
    unverified: list[str] = []
    ok = 0
    for event, matcher, cmd in entries:
        refs = resolve(cmd)
        if not refs:
            unverified.append(f"{event}/{matcher}: no script path parsed from: {cmd[:70]}")
            continue
        for raw, path in refs:
            if path.exists():
                ok += 1
            else:
                missing.append(f"{event}/{matcher}: {raw}  ->  {path}")

    # The live hazard, reported whether or not the configured paths resolve. This is the
    # condition that caused the incident, and it is invisible from inside a hook that died.
    cpd = os.environ.get("CLAUDE_PROJECT_DIR")
    hazard = bool(cpd) and not (Path(cpd) / ".claude").is_dir()

    if missing or unverified:
        print("HOOK WIRING — FAILED\n")
        for m in missing:
            print(f"  MISSING     {m}")
        for u in unverified:
            print(f"  UNVERIFIED  {u}")
        if hazard:
            print(f"\n  CLAUDE_PROJECT_DIR={cpd}")
            print("  holds no .claude/ — the 2026-09-21 condition.")
        print(f"\n{len(missing)} missing, {len(unverified)} unverified, {ok} resolved.")
        print("A hook that cannot be found does not announce itself. See")
        print("docs/insights/2026-09-21-probes-blinded-by-path.md")
        return 1

    if hazard and not args.quiet:
        print(f"⚠ CLAUDE_PROJECT_DIR={cpd} holds no .claude/, but every hook still resolves")
        print("  (the commands recover the repo root themselves). A note, not a failure.")
    if not args.quiet:
        print(f"HOOK WIRING — OK  ({ok} hook script(s) resolved from {ROOT})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
