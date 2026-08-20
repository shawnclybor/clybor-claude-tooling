#!/usr/bin/env python3
"""Regression suite for the probe-visibility gate (check_grep_blindspots.py).

Case 1 is the founding case, and case 2 is the bug found while building this gate:
the first version measured blindness by planting a canary and running grep via
subprocess. It reported ALL CLEAR, because subprocess invokes the real grep binary,
not Claude Code's shell-function shim. A gate that fails OPEN on its own founding
example is worse than no gate — so the suite now pins the declarative contract and
explicitly forbids the subprocess-measurement approach coming back.

Run: python3 scripts/test_grep_blindspots.py
"""
import importlib.util
import os
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "c", os.path.join(HERE, "check_grep_blindspots.py")
)
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)


def mkrepo(tmp, ignore_lines, files):
    """Throwaway git repo. `files` is {relpath: content}."""
    subprocess.run(["git", "init", "-q", tmp], check=True)
    with open(os.path.join(tmp, ".gitignore"), "w") as fh:
        fh.write("\n".join(ignore_lines) + "\n")
    for rel, content in files.items():
        p = os.path.join(tmp, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as fh:
            fh.write(content)
    subprocess.run(["git", "-C", tmp, "add", ".gitignore"], check=True)
    return tmp


def run(name, fn):
    try:
        fn()
        print(f"  PASS  {name}")
        return True
    except AssertionError as e:
        print(f"  FAIL  {name}\n          {e}")
        return False


def case_founding():
    """Ignored content file is on disk, holds the string, and IS reported blind."""
    with tempfile.TemporaryDirectory() as tmp:
        mkrepo(tmp, ["raw/*"], {"raw/inv.txt": "Manheim Dealer_Battlecard\n"})
        assert "Manheim" in open(os.path.join(tmp, "raw/inv.txt")).read()
        zones = c.blind_zones(c.ignored_files(tmp))
        assert "raw" in zones, f"blind zone not detected; got {zones}"
        assert c.is_ignored(tmp, "raw/inv.txt"), "is_ignored missed an ignored file"


def case_directory_blind_zone():
    """REGRESSION: `raw/*` ignores the CONTENTS, not the directory entry.

    `git check-ignore raw` returns 'not ignored', so testing the bare directory
    reported this repo's single most important blind zone as reachable."""
    with tempfile.TemporaryDirectory() as tmp:
        mkrepo(tmp, ["raw/*"], {"raw/inv.txt": "content\n"})
        assert c.is_ignored(tmp, "raw"), \
            "directory blind zone reported reachable — the --paths fail-open bug"
        assert c.is_ignored(tmp, "raw/"), "trailing slash not handled"
        assert not c.is_ignored(tmp, "."), "repo root reported blind"


def case_cache_only_dir_not_blind():
    """REGRESSION: a directory whose ONLY ignored files are derived caches is not
    a blind zone. `scripts/` false-positived off `scripts/__pycache__/*.pyc`."""
    with tempfile.TemporaryDirectory() as tmp:
        mkrepo(tmp, ["__pycache__/"],
               {"scripts/real.py": "code\n", "scripts/__pycache__/x.pyc": "junk"})
        assert not c.is_ignored(tmp, "scripts"), \
            "directory with only cached junk reported as a blind zone"


def case_no_subprocess_measurement():
    """REGRESSION: the gate must not try to measure the shim from a child process.

    subprocess/zsh -i both bypass the shell-function shim, so any such measurement
    returns a false ALL CLEAR. Detection must stay declarative."""
    src = open(os.path.join(HERE, "check_grep_blindspots.py")).read()
    body = src.split('"""', 2)[-1]  # skip the module docstring, which discusses it
    for banned in ("tempfile.mkstemp", "CANARY", '"grep"', "'grep'"):
        assert banned not in body, (
            f"{banned!r} is back in the gate body — the canary approach fails OPEN. "
            "See the module docstring.")


def case_tracked_path_not_flagged():
    """A tracked directory must not be reported blind — no false alarm."""
    with tempfile.TemporaryDirectory() as tmp:
        mkrepo(tmp, ["raw/*"], {"raw/inv.txt": "x\n", "docs/a.md": "y\n"})
        assert not c.is_ignored(tmp, "docs/a.md"), "tracked file reported as ignored"
        zones = c.blind_zones(c.ignored_files(tmp))
        assert "docs" not in zones, f"tracked dir reported blind: {zones}"


def case_derived_and_empty_excluded():
    """__pycache__ and zero-byte files are noise, not hidden findings."""
    with tempfile.TemporaryDirectory() as tmp:
        mkrepo(tmp, ["raw/*", "__pycache__/"],
               {"raw/real.txt": "content\n", "__pycache__/x.pyc": "junk"})
        open(os.path.join(tmp, "raw", "zero.txt"), "w").close()
        zones = c.blind_zones(c.ignored_files(tmp))
        assert "__pycache__" not in zones, "derived cache reported as blind zone"
        files = c.ignored_files(tmp)
        assert not any(f.endswith("zero.txt") for f in files), \
            "zero-byte file reported as hiding content"
        assert any(f.endswith("real.txt") for f in files), "real content missed"


def case_clean_repo():
    """No ignored content -> no blind zone."""
    with tempfile.TemporaryDirectory() as tmp:
        mkrepo(tmp, ["*.log"], {"a.md": "hello\n"})
        assert c.blind_zones(c.ignored_files(tmp)) == {}, "clean repo reported a zone"


def case_shim_detection():
    """shim_active() keys off CLAUDE_CODE_EXECPATH, both directions."""
    saved = os.environ.pop("CLAUDE_CODE_EXECPATH", None)
    try:
        assert c.shim_active() is False, "shim reported active with env unset"
        os.environ["CLAUDE_CODE_EXECPATH"] = "/x/claude"
        assert c.shim_active() is True, "shim not detected with env set"
    finally:
        os.environ.pop("CLAUDE_CODE_EXECPATH", None)
        if saved is not None:
            os.environ["CLAUDE_CODE_EXECPATH"] = saved


def main():
    print("check_grep_blindspots.py — regression suite\n")
    ok = all([
        run("FOUNDING: ignored content is detected as a blind zone", case_founding),
        run("REGRESSION: directory blind zone (raw/* ignores contents)", case_directory_blind_zone),
        run("REGRESSION: cache-only dir is not blind", case_cache_only_dir_not_blind),
        run("REGRESSION: no subprocess measurement (fails OPEN)", case_no_subprocess_measurement),
        run("tracked path is not flagged (no false alarm)", case_tracked_path_not_flagged),
        run("derived caches and empty files excluded", case_derived_and_empty_excluded),
        run("clean repo reports no blind zone", case_clean_repo),
        run("shim detection keys off CLAUDE_CODE_EXECPATH", case_shim_detection),
    ])
    print("\n" + ("ALL PASS" if ok else "FAILURES"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
