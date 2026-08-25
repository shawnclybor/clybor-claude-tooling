# Decision & change log

Newest-first. One entry per non-obvious decision or change whose rationale would not
survive in a commit message alone. Keep entries free of workspace UUIDs, denylist
identifier prefixes, and client/person names — this repo is public and the pre-commit
gate scans staged content.

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
