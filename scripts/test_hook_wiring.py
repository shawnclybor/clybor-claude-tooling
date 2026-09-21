#!/usr/bin/env python3
"""Regression suite for the hook-wiring gate (check_hook_wiring.py).

Two properties are load-bearing, and the rest of the cases exist to keep them honest:

  1. A hook naming a script that is not present FAILS.
  2. A command whose path cannot be parsed is UNVERIFIED, never a pass. A gate that hides its
     own blind spot reproduces the failure it exists to catch.

The remaining cases pin the boundaries that keep the gate usable: an empty config is reported
rather than passed, a healthy hook never vouches for a broken sibling, and a CLAUDE_PROJECT_DIR
holding no .claude/ is a note rather than a failure once the commands recover the root, so the
gate does not fire on every correctly-configured session.

Run: python3 scripts/test_hook_wiring.py
"""
import importlib.util
import json
import os
import tempfile
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("c", os.path.join(HERE, "check_hook_wiring.py"))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

CPD = "CLAUDE_PROJECT_DIR"
CONFIG_NAME = c.SETTINGS.name          # taken from the module, so the test cannot drift from it
OLD_FORM = 'bash "$' + CPD + '"/.claude/hooks/ralph-stop.sh'
NEW_FORM = 'bash "$R"/.claude/hooks/ralph-stop.sh'


def build(hooks, make_scripts=()):
    """Throwaway repo root carrying a hook config; returns its Path."""
    root = Path(tempfile.mkdtemp())
    (root / ".claude").mkdir()
    for rel in make_scripts:
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("#!/bin/sh\n")
    (root / ".claude" / CONFIG_NAME).write_text(json.dumps({"hooks": hooks}))
    return root


def run_gate(root, env=None):
    """Point the module at `root`, run main(), restore module and environment state."""
    old_root, old_settings = c.ROOT, c.SETTINGS
    old_env = os.environ.get(CPD)
    c.ROOT = root
    c.SETTINGS = root / ".claude" / CONFIG_NAME
    os.environ.pop(CPD, None)
    if env is not None:
        os.environ[CPD] = env
    try:
        return c.main([])
    finally:
        c.ROOT, c.SETTINGS = old_root, old_settings
        os.environ.pop(CPD, None)
        if old_env is not None:
            os.environ[CPD] = old_env


def run(name, fn):
    try:
        fn()
        print(f"  PASS  {name}")
        return True
    except AssertionError as e:
        print(f"  FAIL  {name}\n          {e}")
        return False


def case_missing_script_fails():
    """A hook naming a script that is not present fails; it does not pass quietly."""
    root = build({"Stop": [{"hooks": [{"command": OLD_FORM}]}]})
    assert run_gate(root) == 1, "a missing hook script did not fail the gate"


def case_unparseable_is_not_a_pass():
    """LOAD-BEARING: a command with no parseable path is UNVERIFIED, never a silent pass."""
    root = build({"Stop": [{"hooks": [{"command": "some-opaque-binary --flag"}]}]})
    assert run_gate(root) == 1, "an unparseable command passed; the gate hid its own blind spot"


def case_healthy_config_passes():
    root = build({"Stop": [{"hooks": [{"command": NEW_FORM}]}]},
                 make_scripts=[".claude/hooks/ralph-stop.sh"])
    assert run_gate(root) == 0, "a healthy config did not pass"


def case_no_hooks_is_reported_not_passed():
    root = build({})
    assert run_gate(root) == 2, "an empty hook config returned a pass instead of being reported"


def case_missing_config_is_reported_not_passed():
    root = Path(tempfile.mkdtemp())
    (root / ".claude").mkdir()
    old_root, old_settings = c.ROOT, c.SETTINGS
    c.ROOT, c.SETTINGS = root, root / ".claude" / CONFIG_NAME
    try:
        assert c.main([]) == 2, "a missing config file returned a pass"
    finally:
        c.ROOT, c.SETTINGS = old_root, old_settings


def case_healthy_sibling_does_not_vouch():
    """One resolving hook must not cover for a broken one in the same group."""
    root = build({"PreToolUse": [{"matcher": "Write", "hooks": [
        {"command": 'python3 "$R"/.claude/hooks/present.py'},
        {"command": 'python3 "$R"/.claude/hooks/absent.py'}]}]},
        make_scripts=[".claude/hooks/present.py"])
    assert run_gate(root) == 1, "a broken hook was masked by a healthy sibling"


def case_recovered_root_is_not_a_failure():
    """A CLAUDE_PROJECT_DIR holding no .claude/ is a note once the command recovers the root.

    Without this the gate would fire on every session launched from a subdirectory, and a gate
    that fires constantly is already disabled.
    """
    root = build({"Stop": [{"hooks": [{"command": NEW_FORM}]}]},
                 make_scripts=[".claude/hooks/ralph-stop.sh"])
    assert run_gate(root, env=tempfile.mkdtemp()) == 0, \
        "a recovered root was failed anyway; the gate would fire constantly"


def case_multiple_events_all_scanned():
    """Every event is scanned, not just the first -- a break in a later event still fails."""
    root = build({
        "SessionStart": [{"hooks": [{"command": 'bash "$R"/.claude/hooks/present.sh'}]}],
        "Stop": [{"hooks": [{"command": 'bash "$R"/.claude/hooks/absent.sh'}]}]},
        make_scripts=[".claude/hooks/present.sh"])
    assert run_gate(root) == 1, "a break in a later event was not scanned"


def main():
    ok = all([
        run("missing hook script fails", case_missing_script_fails),
        run("LOAD-BEARING: unparseable command is UNVERIFIED, not a pass",
            case_unparseable_is_not_a_pass),
        run("healthy config passes", case_healthy_config_passes),
        run("no hooks is reported, not passed", case_no_hooks_is_reported_not_passed),
        run("missing config file is reported, not passed",
            case_missing_config_is_reported_not_passed),
        run("a healthy sibling does not vouch for a broken hook",
            case_healthy_sibling_does_not_vouch),
        run("recovered root is a note, not a failure", case_recovered_root_is_not_a_failure),
        run("every event is scanned, not just the first", case_multiple_events_all_scanned),
    ])
    print("\n" + ("ALL PASS" if ok else "FAILURES"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
