#!/usr/bin/env python3
"""Build blind judge packets: one per profile per run, filled from Prompt 3 of references/prompts.md.

Rig helper only: a chat user does the same by pasting Prompt 3 once per set of predictions. Packet
numbers are shuffled so a number says nothing; the key (packet -> profile, run) lives apart in
<work>/KEY-do-not-open/key.json. Predictions are <work>/predictions/<name>-r<N>.md with Q1..Qn.

usage: build_packets.py <work> --person "Name" [--runs 3]
"""
import argparse, json, random, re, secrets
from pathlib import Path

PROMPTS = Path(__file__).resolve().parent.parent / "references/prompts.md"


def split_q(text, path):
    parts, cur = {}, None
    for line in text.splitlines():
        m = re.match(r"^\W*Q(\d+)\b\W*(.*)$", line)
        if m:
            cur = int(m.group(1))
            parts[cur] = [m.group(2)] if m.group(2).strip() else []
        elif cur:
            parts[cur].append(line)
    out = {k: "\n".join(v).strip() for k, v in parts.items()}
    assert out and sorted(out) == list(range(1, len(out) + 1)), f"{path}: expected Q1..Qn, got {sorted(out)}"
    return out


ap = argparse.ArgumentParser()
ap.add_argument("work", type=Path)
ap.add_argument("--person", required=True)
ap.add_argument("--runs", type=int, default=3)
a = ap.parse_args()
W, rng = a.work, random.Random(secrets.randbits(64))

text = PROMPTS.read_text()
judge = text[text.index("You are a judge."):text.index("QUESTIONS:\n[PASTE]")].replace("[PERSON]", a.person)
q = (W / "heldout/questions.md").read_text()
questions = "\n".join(l for l in q.splitlines() if not l.startswith(("SETTING:", "LENGTH:"))).strip()
answers = (W / "heldout/SEALED-answers.md").read_text().strip()

profiles = sorted(p.stem for p in (W / "profiles").glob("*.md"))
jobs = [(p, r) for p in profiles for r in range(1, a.runs + 1)]
rng.shuffle(jobs)
(W / "packets").mkdir(exist_ok=True)
(W / "KEY-do-not-open").mkdir(exist_ok=True)
key = {}
for i, (p, r) in enumerate(jobs, 1):
    pid = f"P{i:02d}"
    preds = split_q((W / f"predictions/{p}-r{r}.md").read_text(), f"{p}-r{r}")
    key[pid] = {"profile": p, "run": r, "questions": len(preds)}
    body = (judge + "QUESTIONS:\n" + questions + "\n\nWHAT WAS ACTUALLY SAID OR WRITTEN:\n" + answers
            + "\n\nPREDICTIONS:\n" + "\n\n".join(f"Q{n}\n{t}" for n, t in sorted(preds.items())) + "\n")
    (W / f"packets/{pid}.txt").write_text(body)
    print(pid, len(body), "chars")
assert len({k["questions"] for k in key.values()}) == 1, "prediction sets disagree on question count"
(W / "KEY-do-not-open/key.json").write_text(json.dumps(key, indent=1))
print(f"{len(key)} packets ({len(profiles)} profiles x {a.runs} runs); key written apart")
