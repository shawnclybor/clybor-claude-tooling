# Decision & change log

Newest-first. One entry per non-obvious decision or change whose rationale would not
survive in a commit message alone. Keep entries free of workspace UUIDs, denylist
identifier prefixes, and client/person names — this repo is public and the pre-commit
gate scans staged content.

---

## 2026-08-25 — availability gate promoted: the rule and the hook, together

**What.** A PreToolUse Write|Edit validator that fires when text asserts something is blocked,
unreachable, missing, or owed by someone else without probe evidence nearby, plus the
Pre-Flight-Checklist rule it enforces. Both were live in a client repo; neither existed here.

**Why it is universal.** "Do not record an unavailability claim you never tested" is not
domain-specific. The failure it prevents recurred four times in one week on one engagement, always
the same shape: an assumption never probed, surviving because it kept being copied forward. Two of
the four were caught only because a human challenged the premise. **None were caught by review** —
a confident unavailability claim reads exactly like a finding, and reviewers check prose, not
whether a probe ran. That is what makes it worth a mechanical gate rather than a habit.

**Generalised on the way in:**
- Incident examples de-identified — the shapes are kept because they teach the pattern; the names
  are not needed to teach it.
- The probe-evidence list hardcoded two of that project's gate-script names. Widened to
  `(verify|check)[-_]\w+`, which matches any project's own gate scripts and is the more honest
  rule anyway — the signal is "a gate script ran", not which one.
- Connector tool names (`sharepoint_search`, `outlook_email_search`, `notion-fetch`, …) were kept.
  They are standard across anyone using those connectors and are the strongest probe signal;
  the anti-pattern is porting project *IDs*, not tool names.

**Ships report-only.** `REPORT_ONLY = True` until backtested against a real corpus. A gate that
fires wrongly on day one gets disabled on day two.

**Wired, not just added:** `settings.json.template` PreToolUse Write|Edit, the hooks README, and the
Availability-gate rule in `routing-protocol.md`. A hook without its rule is an enforcement mechanism
nobody can explain.

**Validated behaviourally, six cases:** a bare claim flags; a claim with probe evidence nearby
passes; `NOT PROBED` passes (it is the compliant form); the `<!-- probe-ok: -->` override passes;
an exempt vendored path passes; and a generic gate-script name passes, exercising the widened
pattern.

⚠️ **Two checker blind spots surfaced while doing this.** `check-promotion.sh` scans
`.claude/{skills,hooks,commands,agents}` — **`.claude/rules/` is not scanned at all**, so rule
drift between master and a consuming repo is invisible. Separately, it skips any skill the master
carries as an asset. Neither is wrong on its own terms; together they cover more ground than the
"tooling drift is checked" framing suggests. Not changed here.

**Downstream:** repos initialised before today do not auto-update. Any repo wanting this gate needs
the hook file, the `settings.json` wiring, and the rule text.

---

## 2026-08-25 — check-knowledge.sh parsed frontmatter with a fixed line count

**The bug.** Wiki frontmatter was extracted with `head -n 12`. A folded `description: >-` block
pushes later keys past that window, so a well-formed article was rejected for a missing key that
was present two lines below the cutoff. It fails **closed**, so nothing bad shipped — but a gate
that rejects correct input teaches people to reach for `--no-verify`, and a gate routinely
overridden is not a gate.

**The fix.** Extract the block between the opening `---` and its closing `---`. Four fixtures ran
before the patch: long frontmatter with description ahead of sources passes; a genuinely missing
key fails; a key present only in the BODY fails; no frontmatter at all fails. The third fixture is
the one that matters — it proves the fix is not a whole-file grep, which would have made the gate
pass files whose keys are merely mentioned in prose.

**Generalisable.** Any parser with a hardcoded window over variable-length structured text has this
bug latent. The tell is a constant chosen from what the data looked like on the day it was written.
Prefer the delimiter the format actually defines.

**Discovered from a consuming repo, not here.** The defect existed identically in both copies, which
is the second time in one session that shared tooling was found broken in both places at once. The
promotion check compares copies, so it cannot see a defect they agree on. Worth remembering when
judging what that check does and does not cover.

---

## 2026-08-25 — notion-governance drops token fill entirely; the overlay writes itself

**Supersedes the 2026-08-05 decision below.** That change moved the six shared workspace database
IDs out of the skill body and into `{{DB_*_ID}}` tokens, filled at bootstrap from a gitignored local
file. The skill has since moved further — to a per-repo `.claude/notion-project-ids.md` overlay that
carries both the database IDs and the consuming repo's own Project and Client record IDs. The token
layer became dead weight in between: `assets/` still shipped the placeholder form while `.claude/`
had already moved on, so **every newly bootstrapped project inherited the superseded design** and
nothing surfaced it.

**Why nothing surfaced it.** `check-promotion.sh` deliberately skips any skill the master carries as
an asset — *"the skill's job, not an always-on nag."* Sound reasoning for reducing noise, but it
means an asset-carried skill can diverge three ways (canonical, distributed template, installed
instance) and stay invisible indefinitely. Worth remembering when judging what the drift check
does and does not cover.

**Decision: delete the fill rather than reimplement it.** Canonical already told the agent to write
the overlay on first use when absent, so no bootstrap step is needed at all. The asset's
`adaptation_points` drop from eight tokens to `[]`, and the Step 7 `grep -r "{{" .claude/skills/`
gate passes trivially. Canonical, the distributed template, and the one live installed instance are
now byte-identical. `catalog_version` 0.1.0 → 0.2.0 (asset contract change). Accepted cost: a new
project's first Notion session pays an ID lookup instead of arriving pre-filled — cheaper than a
templating layer that silently rots.

⚠️ **The self-healing instruction was circular and had never been exercised.** It resolved a missing
overlay by querying "the Project and Client data sources below" — but that table had already had its
IDs stripped by the earlier change, leaving nothing to query from. Any project reaching that path
would have dead-ended on its first write, in exactly the situation the overlay exists to handle.
Rewritten to bootstrap from a **name**: search the database by title, recover its data-source ID,
then query. Never seed the chain from a remembered ID.

**Also folded in:** the record-type-to-database routing table (present in installed instances but
missing from canonical) and a new § Naming — Knowledge Base titles are type-first, Note titles are
scope-first, neither length-capped. Measured against fifty live titles rather than asserted.

**Generalisable:** a two-copy design (master + rendered instance) fails quietly the moment a third
copy appears. Prefer a skill general enough to need no rendering, with per-repo values in an overlay
the skill itself can create.

---

## 2026-08-05 — notion-governance ships its six workspace DB IDs as tokens, not raw UUIDs

**Decision.** The notion-governance catalog skill referenced the six shared life-CRM
database IDs (Contact/Note/Project/AA-Task/Client/KB) as raw UUIDs in its body. They now
ship as `{{DB_*_ID}}` tokens; the real values live in `scripts/notion-dbs.local.json`
(gitignored, mirrors `denylist.local.json`) and `project-bootstrap` Step 5 fills them at
install. Six tokens added to the skill's `catalog.json` `adaptation_points`.

**Why.** The IDs are **constants of the one shared workspace** — identical across every
install, not per-project. Raw UUIDs in a catalog asset blocked commit two ways at once:
`verify-clean.py`'s UUID-shaped regex net (catches *any* UUID), and the denylist
`identifier` prefixes. Tokenizing keeps the public canonical repo carrying zero workspace
identifiers while installs still get real values — with no hand-typing, since a guessed
UUID silently targets the wrong database (the exact failure the skill exists to prevent).

**Alternatives rejected (quality-review, three lenses).**
- *Allowlist the six UUIDs in `verify-clean.py`.* Rejected: permanently publishes
  private-workspace structure to a public repo (and its git history), and degrades an
  agnostic class-based gate into a per-item risk bet threaded through two independent
  matchers — the realistic shortcut (broadening a denylist prefix) would blind the net to
  other identifiers sharing that root. "Grants no access without auth" is out of scope for
  a gate whose contract is "no private identifiers in the public repo, period."
- *Keep the skill local-only, out of the catalog.* Rejected: discards ~90% reusable
  governance (DB-routing map, relation-replace trap, retrieval routing) to fix six lines,
  and fights the one-canonical-home + drift-gate mandate.

**Deferred (YAGNI).** No auto-fill machinery built. The existing prompted Step-5 fill is
right-sized for a handful of installs/year. Open follow-up, per the repo's own
"Honor-System Gates Fail — Codify as Scripts" rule: the unfilled-`{{token}}` check that
guards an install against shipping half-filled placeholders is currently prose in
`project-bootstrap` Step 7, not a script. Codify it as a fail-loud gate when the pattern
recurs. Already-installed copies (filled inline, in private repos) are exempt from the
promotion drift check by design — they will not auto-adopt the token form; re-sync by hand
if desired.

**Refs.** Commit that tokenizes the asset; `scripts/verify-clean.py` (the gate);
`scripts/notion-dbs.local.json` (gitignored source of truth).
