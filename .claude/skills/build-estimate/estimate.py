#!/usr/bin/env python3
"""build-estimate — project a build's remaining effort onto the calendar from MEASURED rates.

    estimate.py project <spec.json>            hours + finish dates + fit verdict vs target
    estimate.py calibrate <record.json>        append a measured run to calibration.json
    estimate.py rates                          print the ledger and the rate each profile resolves to

Every number this prints is traceable: a rate is either MEASURED (from a ledger record) or
ASSUMED (a multiplier written in the ledger with basis "assumed"), and the output says which.
An estimate for a profile with no measured record is printed with a loud UNCALIBRATED line
rather than silently using someone's guess as if it were data.

Units: one *task unit* is one median task landed under the calibrated process — the whole loop,
review rounds and repairs included. Task kinds scale that unit; task status scales what is left.

Spec (project):
{
  "slug": "settlement-verifier",
  "process": "intensive",                     # a profile in calibration.json
  "start": "2026-08-28", "start_hours_left": 4,
  "target": "2026-09-02",                     # optional
  "hours_per_day": 7, "holidays": ["2026-09-01"],
  "tasks":    [{"id": "43", "kind": "test-layer", "status": "staged", "note": "..."}],
  "fixed":    [{"id": "build-evaluate", "minutes": 60}],
  "optional": [{"id": "65", "kind": "check-logic"}]      # reported as a second scenario
}

Record (calibrate):
{
  "project": "legal-client-a", "slug": "settlement-verifier", "process": "intensive",
  "window": "2026-08-27T15:52 -> 2026-08-28T16:57, overnight excluded",
  "iterations": 23, "tasks": 21, "hours": 15.5,
  "task_minutes": {"low": 30, "high": 75},    # optional: fastest / slowest observed task
  "note": "what made this run typical or not"
}
"""
import json
import sys
from datetime import date, timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
LEDGER = HERE / "calibration.json"


def load_ledger():
    with open(LEDGER) as f:
        return json.load(f)


def profile_rate(ledger, process):
    """Minutes per task unit for a process, as (low, mid, high, basis, n_records)."""
    prof = ledger["profiles"].get(process)
    if prof is None:
        sys.exit(f"unknown process profile '{process}'. Known: {', '.join(ledger['profiles'])}")
    recs = [r for r in ledger["records"] if r["process"] == process]
    if recs:
        hours = sum(r["hours"] for r in recs)
        tasks = sum(r["tasks"] for r in recs)
        mid = hours * 60 / tasks
        lows = [r["task_minutes"]["low"] for r in recs if r.get("task_minutes")]
        highs = [r["task_minutes"]["high"] for r in recs if r.get("task_minutes")]
        low = min(lows) if lows else mid * 0.7
        high = max(highs) if highs else mid * 1.6
        return low, mid, high, "MEASURED", len(recs)
    # No measured record: scale the nearest measured profile by the assumed multiplier.
    base = prof.get("scales_from")
    if base and base != process:
        blow, bmid, bhigh, bbasis, n = profile_rate(ledger, base)
        m = prof["multiplier"]
        return blow * m, bmid * m, bhigh * m, f"ASSUMED x{m} of {base} ({bbasis})", n
    sys.exit(f"profile '{process}' has no measured record and nothing to scale from")


def task_units(ledger, t):
    kinds, statuses = ledger["task_kinds"], ledger["task_status"]
    k = kinds.get(t["kind"])
    if k is None:
        sys.exit(f"task {t.get('id')}: unknown kind '{t['kind']}'. Known: {', '.join(kinds)}")
    s = statuses.get(t.get("status", "not-started"))
    if s is None:
        sys.exit(f"task {t.get('id')}: unknown status '{t.get('status')}'. Known: {', '.join(statuses)}")
    return k["units"] * s["remaining"], k.get("uncertainty", 1.0), k["basis"]


def add_workdays(start, start_hours_left, hours, hours_per_day, holidays):
    """Walk the calendar: today's remaining hours first, then whole working days."""
    d = start
    left = hours
    left -= max(start_hours_left, 0.0)
    if left <= 0:
        return d
    while True:
        d += timedelta(days=1)
        if d.weekday() >= 5 or d.isoformat() in holidays:
            continue
        left -= hours_per_day
        if left <= 0:
            return d


def workdays_between(a, b, holidays):
    n, d = 0, a
    while d < b:
        d += timedelta(days=1)
        if d.weekday() < 5 and d.isoformat() not in holidays:
            n += 1
    return n


def scenario(ledger, spec, tasks, label, rate):
    low_r, mid_r, high_r, _, _ = rate
    rows, h_low = [], 0.0
    h_mid = h_high = 0.0
    for t in tasks:
        units, unc, basis = task_units(ledger, t)
        lo, mi, hi = units * low_r / 60, units * mid_r / 60, units * high_r * unc / 60
        h_low, h_mid, h_high = h_low + lo, h_mid + mi, h_high + hi
        rows.append((str(t.get("id")), t["kind"], t.get("status", "not-started"), units, lo, mi, hi, basis))
    return rows, h_low, h_mid, h_high


def cmd_project(path):
    ledger = load_ledger()
    with open(path) as f:
        spec = json.load(f)
    process = spec["process"]
    rate = profile_rate(ledger, process)
    low_r, mid_r, high_r, basis, n = rate
    start = date.fromisoformat(spec["start"])
    hpd = float(spec.get("hours_per_day", 7))
    hol = set(spec.get("holidays", []))
    start_left = float(spec.get("start_hours_left", hpd))
    target = date.fromisoformat(spec["target"]) if spec.get("target") else None
    fixed = spec.get("fixed", [])
    fixed_h = sum(f["minutes"] for f in fixed) / 60

    print(f"# build-estimate — {spec.get('slug', path)}")
    print(f"process: {process}  rate per task unit: low {low_r:.0f} / mid {mid_r:.0f} / high {high_r:.0f} min  [{basis}, {n} record(s)]")
    if basis != "MEASURED":
        print("UNCALIBRATED: no measured record for this profile. Treat every figure below as a guess scaled from another process.")
    print(f"calendar: start {start} ({start_left:g} h left today), {hpd:g} h/day, weekends off, holidays {sorted(hol) or 'none'}"
          + (f", target {target}" if target else ""))
    print()

    scenarios = [("required", list(spec.get("tasks", [])))]
    if spec.get("optional"):
        scenarios.append(("required + optional", list(spec.get("tasks", [])) + list(spec["optional"])))

    for label, tasks in scenarios:
        rows, h_low, h_mid, h_high = scenario(ledger, spec, tasks, label, rate)
        h_low, h_mid, h_high = h_low + fixed_h, h_mid + fixed_h, h_high + fixed_h
        print(f"## {label}")
        print(f"| task | kind | status | units | low h | mid h | high h | basis |")
        print(f"|---|---|---|---|---|---|---|---|")
        for tid, kind, status, units, lo, mi, hi, kb in rows:
            print(f"| {tid} | {kind} | {status} | {units:.2f} | {lo:.1f} | {mi:.1f} | {hi:.1f} | {kb} |")
        for f in fixed:
            print(f"| {f['id']} | fixed | — | — | {f['minutes']/60:.1f} | {f['minutes']/60:.1f} | {f['minutes']/60:.1f} | fixed minutes |")
        print(f"| **total** | | | | **{h_low:.1f}** | **{h_mid:.1f}** | **{h_high:.1f}** | |")
        fin = {k: add_workdays(start, start_left, h, hpd, hol) for k, h in (("low", h_low), ("mid", h_mid), ("high", h_high))}
        print(f"working days: low {h_low/hpd:.1f} / mid {h_mid/hpd:.1f} / high {h_high/hpd:.1f}")
        print(f"finish: low {fin['low']} / mid {fin['mid']} / high {fin['high']}")
        if target:
            avail = start_left + hpd * workdays_between(start, target, hol)
            if h_high <= avail:
                verdict = "FITS at the high estimate"
            elif h_mid <= avail:
                verdict = "MARGINAL — fits at mid, not at high"
            else:
                verdict = "DOES NOT FIT at the mid estimate"
            print(f"vs target {target}: {avail:.1f} h available → {verdict}")
        print()

    print("## assumptions carried")
    for k, v in ledger["task_kinds"].items():
        if any(t["kind"] == k for _, ts in scenarios for t in ts):
            print(f"- kind `{k}` = {v['units']} units, uncertainty x{v.get('uncertainty', 1.0)} on the high side — {v['basis']}")
    for k, v in ledger["task_status"].items():
        if any(t.get("status", "not-started") == k for _, ts in scenarios for t in ts):
            print(f"- status `{k}` leaves {v['remaining']:.0%} of the work — {v['basis']}")
    print("- a task unit includes its adversarial review rounds and repairs; do not add a review line on top")
    print("- no allowance for interruptions, meetings, or a second build sharing the day; scale `hours_per_day` for that")


def cmd_calibrate(path):
    ledger = load_ledger()
    with open(path) as f:
        rec = json.load(f)
    for k in ("project", "process", "iterations", "tasks", "hours", "window"):
        if k not in rec:
            sys.exit(f"record missing '{k}'")
    if rec["process"] not in ledger["profiles"]:
        sys.exit(f"unknown process '{rec['process']}' — add the profile to calibration.json first")
    ledger["records"].append(rec)
    with open(LEDGER, "w") as f:
        json.dump(ledger, f, indent=2)
        f.write("\n")
    low, mid, high, basis, n = profile_rate(ledger, rec["process"])
    print(f"appended record for {rec['project']}/{rec.get('slug', '?')} ({rec['process']}): "
          f"{rec['tasks']} tasks in {rec['hours']} h → {rec['hours']*60/rec['tasks']:.0f} min/task")
    print(f"profile '{rec['process']}' now resolves to low {low:.0f} / mid {mid:.0f} / high {high:.0f} min per task unit over {n} record(s)")
    print(f"ledger: {LEDGER} — promote it so the canonical copy carries the new record")


def cmd_rates():
    ledger = load_ledger()
    print(f"ledger: {LEDGER}\n")
    for p, v in ledger["profiles"].items():
        low, mid, high, basis, n = profile_rate(ledger, p)
        print(f"{p:10s} low {low:5.0f} / mid {mid:5.0f} / high {high:5.0f} min per task unit  [{basis}, {n} record(s)]")
        print(f"{'':10s} {v['description']}")
    print("\nrecords:")
    for r in ledger["records"]:
        print(f"- {r['project']}/{r.get('slug','?')} ({r['process']}): {r['tasks']} tasks, {r['iterations']} iterations, "
              f"{r['hours']} h → {r['hours']*60/r['tasks']:.0f} min/task — {r['window']}")


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0)
    cmd, rest = args[0], args[1:]
    if cmd == "project" and len(rest) == 1:
        cmd_project(rest[0])
    elif cmd == "calibrate" and len(rest) == 1:
        cmd_calibrate(rest[0])
    elif cmd == "rates":
        cmd_rates()
    else:
        print(__doc__)
        sys.exit(2)
