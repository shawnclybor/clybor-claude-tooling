import re, shutil, subprocess, sys, tempfile, os
SRC = ".claude/hooks/check-empty-prose.py"
orig = open(SRC, encoding="utf-8").read()

def empty_list(name):
    # turn `NAME = [` into `NAME = []` followed by a dead list
    return lambda s: s.replace(f"{name} = [", f"{name} = []\n_DEAD_{name} = [", 1)

def drop_line(substr):
    def f(s):
        out=[]
        for ln in s.split("\n"):
            out.append("        pass" if substr in ln and ln.strip().startswith("text =") else ln)
        return "\n".join(out)
    return f

MUTATIONS = [
    ("empty SLOGAN list",       "M1", empty_list("SLOGAN")),
    ("empty GRANDIOSITY list",  "M2", empty_list("GRANDIOSITY")),
    ("empty FILLER list",       "M3", empty_list("FILLER")),
    ("empty INSIDER list",      "M4", empty_list("INSIDER")),
    ("empty FLOURISH list",     "M5", empty_list("FLOURISH")),
    ("drop inline-code exempt", "C2", drop_line('r"`[^`\\n]+`"')),
    ("drop fenced-code exempt", "C3", drop_line('r"```.*?```"')),
    ("drop frontmatter exempt", "C4", drop_line('r"\\A---\\n.*?\\n---\\n"')),
    ("drop suppression region",  "C6", drop_line('empty-prose:\\s*off')),
]

d = tempfile.mkdtemp()
caught = survived = 0
for name, expect, fn in MUTATIONS:
    mutated = fn(orig)
    if mutated == orig:
        print(f"  ERROR      {name:<26} -> patch was a no-op"); survived += 1; continue
    path = os.path.join(d, "mut.py")
    open(path, "w", encoding="utf-8").write(mutated)
    env = dict(os.environ, GATE=path)
    r = subprocess.run(["bash", ".claude/hooks/test-empty-prose.sh"],
                       capture_output=True, text=True, env=env)
    if re.search(rf"FAIL {expect}\b", r.stdout):
        print(f"  caught     {name:<26} -> {expect} fails"); caught += 1
    else:
        print(f"  SURVIVED   {name:<26} -> {expect} still passes"); survived += 1

shutil.rmtree(d)
print(f"\ncaught {caught}, survived {survived}")
sys.exit(1 if survived else 0)
