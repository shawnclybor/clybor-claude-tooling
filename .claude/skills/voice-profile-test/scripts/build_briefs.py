#!/usr/bin/env python3
"""Write one Prompt-2 brief per profile: <work>/briefs/<name>.txt.

Every run of a profile uses the same brief. Setting and length come from the SETTING: and optional
LENGTH: lines at the top of <work>/heldout/questions.md.

usage: build_briefs.py <work> --person "Name"
"""
import argparse
from pathlib import Path

PROMPTS = Path(__file__).resolve().parent.parent / "references/prompts.md"

ap = argparse.ArgumentParser()
ap.add_argument("work", type=Path)
ap.add_argument("--person", required=True)
a = ap.parse_args()

text = PROMPTS.read_text()
p2 = text[text.index("You are a ghostwriter"):text.index("PROFILE:\n[PASTE ONE PROFILE HERE]")]

q = (a.work / "heldout/questions.md").read_text()
meta = {l.split(":", 1)[0]: l.split(":", 1)[1].strip() for l in q.splitlines() if l.startswith(("SETTING:", "LENGTH:"))}
assert "SETTING" in meta, "questions.md needs a SETTING: line"
questions = "\n".join(l for l in q.splitlines() if not l.startswith(("SETTING:", "LENGTH:"))).strip()

p2 = (p2.replace("[PERSON]", a.person).replace("[SETTING]", meta["SETTING"])
        .replace("[LENGTH]", meta.get("LENGTH", "80 to 150").replace("–", " to ").replace(" words", "")))
assert "[" not in p2.replace("[figure]", ""), f"unfilled placeholder in:\n{p2}"

profiles = sorted((a.work / "profiles").glob("*.md"))
assert len(profiles) >= 2, "put at least two profiles in <work>/profiles/"
(a.work / "briefs").mkdir(exist_ok=True)
for path in profiles:
    body = p2 + "PROFILE:\n" + path.read_text().strip() + "\n\nQUESTIONS:\n" + questions + "\n"
    (a.work / f"briefs/{path.stem}.txt").write_text(body)
    print(f"{path.stem}: {len(body)} chars, {len(path.read_text().split())} profile words")
print("setting:", meta["SETTING"], "| length:", meta.get("LENGTH", "80 to 150 (default)"))
