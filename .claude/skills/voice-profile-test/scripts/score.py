#!/usr/bin/env python3
"""Unblind and score a voice profile test (rig helper; chat users fill the table in prompts.md by hand).

Reads <work>/judges/<judge>/PNN.md for every judge folder, and the key. Reports:
- per judge, per profile: THINKING and SOUND per run, mean and range over runs;
- with two or more judges: per item (one question in one set) whether the first two judges agree
  within 1 point on thinking (0-6) and sound (0-2), agreed means per profile with run range, and
  every disagreement listed;
- per packet: rows parsed, quoted lines found (a presence count only), and whether the judge's own
  THINKING/SOUND totals match its table.

usage: score.py <work>
"""
import argparse, json, re, statistics as st
from collections import defaultdict
from pathlib import Path

ROW = re.compile(r"^\|\s*\**\s*Q?(\d+)\s*\**\s*\|\s*(\d)\s*\|\s*(\d)\s*\|\s*(\d)\s*\|\s*(\d)\s*\|")

ap = argparse.ArgumentParser()
ap.add_argument("work", type=Path)
W = ap.parse_args().work
key = json.loads((W / "KEY-do-not-open/key.json").read_text())
judges = sorted(d.name for d in (W / "judges").iterdir() if d.is_dir())
profiles = sorted({k["profile"] for k in key.values()})
nq = next(iter(key.values()))["questions"]


def parse(path):
    text = path.read_text()
    rows = {int(m.group(1)): tuple(int(g) for g in m.groups()[1:])
            for m in (ROW.match(l.strip()) for l in text.splitlines()) if m}
    quotes = sum(1 for l in text.splitlines() if not l.strip().startswith("|") and re.search(r"[\"“][^\"”]{3,}[\"”]", l))
    tot = {k: int(v) for k, v in re.findall(r"(THINKING|SOUND):\s*\**\s*(\d+)", text)}
    return rows, quotes, tot


scores = {}
for j in judges:
    for pid, k in sorted(key.items()):
        f = W / f"judges/{j}/{pid}.md"
        if not f.exists():
            print(f"MISSING {j} {pid}")
            continue
        rows, quotes, tot = parse(f)
        t, s = sum(sum(v[:3]) for v in rows.values()), sum(v[3] for v in rows.values())
        check = "" if not tot or (tot.get("THINKING") == t and tot.get("SOUND") == s) else f", judge totals {tot} vs table {t}/{s}"
        miss = [n for n in range(1, nq + 1) if n not in rows]
        print(f"{j} {pid}: {len(rows)}/{nq} rows, {quotes} quoted lines ({4 * nq} asked){check}" + (f", MISSING Q{miss}" if miss else ""))
        for n, v in rows.items():
            scores[(j, pid, n)] = v


def fmt(xs):
    return f"{' / '.join(f'{x:g}' for x in xs)} | {st.mean(xs):.1f} | {min(xs):g}–{max(xs):g}"


print()
for j in judges:
    print(f"## Judge: {j}\n| profile | thinking per run | mean | range | sound per run | mean | range |\n|---|---|---|---|---|---|---|")
    for p in profiles:
        per = {}
        for pid, k in key.items():
            rows = [scores.get((j, pid, n)) for n in range(1, nq + 1)]
            if k["profile"] == p and None not in rows:
                per[k["run"]] = (sum(sum(r[:3]) for r in rows), sum(r[3] for r in rows))
        if not per:
            print(f"| {p} | no data |||||")
            continue
        print(f"| {p} | {fmt([per[r][0] for r in sorted(per)])} | {fmt([per[r][1] for r in sorted(per)])} |")
    print()

if len(judges) >= 2:
    a_, b_ = judges[:2]
    print(f"## Agreement: {a_} vs {b_} (item = one question in one set; within 1 point)")
    agree = defaultdict(lambda: {"t": [], "s": [], "rt": defaultdict(list)})
    dis, hi = [], 0
    for pid, k in sorted(key.items()):
        p = k["profile"]
        for n in range(1, nq + 1):
            x, y = scores.get((a_, pid, n)), scores.get((b_, pid, n))
            if not x or not y:
                continue
            tx, ty = sum(x[:3]), sum(y[:3])
            if abs(tx - ty) <= 1:
                agree[p]["t"].append((tx + ty) / 2)
                agree[p]["rt"][k["run"]].append((tx + ty) / 2)
            else:
                hi += ty > tx
                dis.append(f"{pid} {p} run{k['run']} Q{n}: thinking {a_} {tx} vs {b_} {ty}")
            if abs(x[3] - y[3]) <= 1:
                agree[p]["s"].append((x[3] + y[3]) / 2)
            else:
                dis.append(f"{pid} {p} run{k['run']} Q{n}: sound {a_} {x[3]} vs {b_} {y[3]}")
    items = sum(1 for k in key.values() if k["profile"] == profiles[0]) * nq
    print("| profile | agreed thinking items | mean /6 | run range /6 | agreed sound items | mean /2 |\n|---|---|---|---|---|---|")
    for p in profiles:
        g = agree[p]
        rr = [st.mean(v) for _, v in sorted(g["rt"].items())]
        print(f"| {p} | {len(g['t'])}/{items} | {st.mean(g['t']):.2f} | "
              f"{(f'{min(rr):.2f}–{max(rr):.2f}' if rr else '-')} | {len(g['s'])}/{items} | {st.mean(g['s']):.2f} |"
              if g["t"] and g["s"] else f"| {p} | {len(g['t'])}/{items} | - | - | {len(g['s'])}/{items} | - |")
    print(f"\n## Disagreements ({len(dis)}; thinking items where {b_} is higher: {hi})")
    print("\n".join(dis) or "none")
