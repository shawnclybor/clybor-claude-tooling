#!/usr/bin/env python3
"""Track adversarial-review runs against a target and flag drift in the REVIEW, not the target.

A review process that always finds at least one critical is not measuring the target — it is
measuring how hard someone looked. Observed for real: one plan reviewed four times in a day,
each round clearing ~30 findings and introducing 2-3, the reported must-fix count going 9 → 46
while zero product code was written. Four mechanisms did that, and this catches all four.

  1 RATCHET        every round finds >=1 must-fix, indefinitely
  2 INFLATION      must-fix count rising on a target whose content barely changed
  3 SELF-INFLICTED a large share of findings were introduced by the previous round's fixes
  4 RE-GRADE       findings against text that has not changed since it was accepted

Usage:
  review-drift.py record <target> --must N --should N --note N [--self-inflicted N] [--round-note "..."]
  review-drift.py check  <target>          exit 1 if drift is detected
  review-drift.py log    <target>          print the run history

State lives beside the target in .review-history.json, keyed by target path.
"""
import hashlib
import json
import os
import sys

STATE = ".review-history.json"
ROUND_CAP = 3
DEFAULT_RUBRIC = ".claude/skills/adversarial-review/rubric.md"


def _state_path(target):
    return os.path.join(os.path.dirname(os.path.abspath(target)) or ".", STATE)


def _load(target):
    p = _state_path(target)
    if not os.path.exists(p):
        return {}
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception:
        return {}


def _save(target, data):
    json.dump(data, open(_state_path(target), "w", encoding="utf-8"), indent=2, sort_keys=True)


def _digest(target):
    h = hashlib.sha256()
    with open(target, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()[:12]


def _key(target):
    return os.path.basename(os.path.abspath(target))


def _rubric_hash(path):
    """Hash the rubric so a silent change of standard is visible. The bar moving without
    anyone saying so is the root drift mechanism — every other signal is downstream of it."""
    try:
        return _digest(path)
    except Exception:
        return ""


def record(target, must, should, note, self_inflicted, round_note, rubric=DEFAULT_RUBRIC):
    data = _load(target)
    runs = data.setdefault(_key(target), [])
    runs.append({
        "round": len(runs) + 1,
        "digest": _digest(target),
        "rubric_hash": _rubric_hash(rubric),
        "must": must, "should": should, "note": note,
        "self_inflicted": self_inflicted,
        "round_note": round_note or "",
    })
    _save(target, data)
    print(f"recorded round {len(runs)} for {_key(target)}: "
          f"must={must} should={should} note={note} self_inflicted={self_inflicted}")
    return 0


def check(target):
    runs = _load(target).get(_key(target), [])
    if len(runs) < 2:
        print(f"{len(runs)} round(s) recorded — need 2 before drift can be assessed.")
        return 0

    problems = []
    last, prev = runs[-1], runs[-2]

    # 1 RATCHET — every round finds at least one must-fix, three rounds running
    if len(runs) >= 3 and all(r["must"] >= 1 for r in runs[-3:]):
        problems.append(
            "RATCHET: the last 3 rounds each found >=1 must-fix "
            f"({', '.join(str(r['must']) for r in runs[-3:])}). A review that never comes back "
            "clean is measuring effort, not the target. Re-read the must-fix definition and "
            "reclassify, or stop reviewing and build.")

    # 2 INFLATION — count rising while the target barely moved
    if last["must"] > prev["must"] and last["digest"] == prev["digest"]:
        problems.append(
            f"INFLATION: must-fix rose {prev['must']} -> {last['must']} on an UNCHANGED target "
            f"(digest {last['digest']}). The target did not get worse; the standard moved. That "
            "is a rubric change and belongs in rubric.md, not in a findings list.")
    elif last["must"] > prev["must"] * 2 and prev["must"] > 0:
        problems.append(
            f"INFLATION: must-fix more than doubled ({prev['must']} -> {last['must']}). Confirm "
            "each new finding names a false pass, a wrong deliverable, or wasted days.")

    # 3 SELF-INFLICTED — the review is generating its own workload
    if last["must"] and last["self_inflicted"] / max(last["must"], 1) > 0.33:
        problems.append(
            f"SELF-INFLICTED: {last['self_inflicted']} of {last['must']} must-fix were introduced "
            "by the previous round's fixes. The loop is producing its own findings. Fix them, but "
            "do not count them as the target degrading.")

    # 4 RE-GRADE — unchanged target, still finding must-fix
    if last["digest"] == prev["digest"] and last["must"] > 0:
        problems.append(
            f"RE-GRADE: the target is byte-identical to round {prev['round']} "
            f"(digest {last['digest']}) and still returned {last['must']} must-fix. Nothing about "
            "the artifact changed, so these are re-grades against a stricter bar.")

    # 5 RUBRIC MOVED — the bar changed with no note saying so
    base_rh = runs[0].get("rubric_hash", "")
    last_rh = last.get("rubric_hash", "")
    if base_rh and last_rh and base_rh != last_rh and not last.get("round_note"):
        problems.append(
            f"RUBRIC MOVED: rubric.md has changed since round 1 ({base_rh} -> {last_rh}) with no "
            "reason recorded. Every count in this history was produced against a different "
            "standard, so the trend is not comparable. Changing the rubric is allowed — say so "
            "with --round-note and expect the counts to move for that reason alone.")

    # round cap
    if len(runs) > ROUND_CAP:
        note = last.get("round_note", "")
        if not note:
            problems.append(
                f"CAP: round {len(runs)} exceeds the {ROUND_CAP}-round cap with no written reason. "
                "A further round needs a stated change to the target or the rubric; absent that, "
                "it is drift. Build the thing and watch it run instead.")
        else:
            print(f"note: round {len(runs)} is past the cap, reason given: {note}")

    hist = " -> ".join(f"r{r['round']}:{r['must']}m" for r in runs)
    print(f"history: {hist}")
    if problems:
        print()
        for p in problems:
            print("DRIFT  " + p)
            print()
        print(f"FAIL: {len(problems)} drift signal(s)")
        return 1
    print("PASS: no drift detected")
    return 0


def log(target):
    runs = _load(target).get(_key(target), [])
    if not runs:
        print("no runs recorded")
        return 0
    print(f"{'rd':>3}  {'digest':<12} {'must':>4} {'shld':>4} {'note':>4} {'self':>4}  round-note")
    for r in runs:
        print(f"{r['round']:>3}  {r['digest']:<12} {r['must']:>4} {r['should']:>4} "
              f"{r['note']:>4} {r['self_inflicted']:>4}  {r.get('round_note','')}")
    return 0


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        print(__doc__)
        return 2
    cmd, target = a[0], a[1]
    if not os.path.exists(target):
        print(f"target not found: {target}")
        return 2

    def opt(name, default=0):
        return int(a[a.index(name) + 1]) if name in a else default

    if cmd == "record":
        rn = a[a.index("--round-note") + 1] if "--round-note" in a else ""
        rub = a[a.index("--rubric") + 1] if "--rubric" in a else DEFAULT_RUBRIC
        return record(target, opt("--must"), opt("--should"), opt("--note"),
                      opt("--self-inflicted"), rn, rub)
    if cmd == "check":
        return check(target)
    if cmd == "log":
        return log(target)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
