#!/usr/bin/env bash
# polish.sh -- the three mechanical steps of build-polish that a sentence in a skill did not hold.
#   pin  <slug> [--repin]   pin the Phase 0 done definition and its golden hashes, or verify both
#                           and report whether the latest snapshot measured the code as it stands
#   run  <slug> <round> --driver PAT... --keep PATH... -- CMD...
#                           one serialized run of the core function into a read-only snapshot
#   seen <slug> <text>      every place the text already appears, each line labelled VERDICT
#                           (ledgers, state, evaluate) or LEAD (memories, the parking lot)
# Exit: 0 ok | 1 pin or golden moved, or no verdict seen | 2 refused or usage | 3 no fresh
# snapshot, or a driver outlived its run. For macOS /bin/bash 3.2: no "${@:N}", empty arrays
# guarded, and every $(...) that can die is checked by its caller.
set -uo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "polish: not inside a git repository" >&2; exit 2; }
SNAPROOT="${POLISH_SNAPSHOTS:-$HOME/.cache/build-polish}"

die() { echo "polish: $1" >&2; exit "${2:-2}"; }

slug_paths() {
  PRP="$ROOT/.claude/PRPs/$1"
  LEDGER="$PRP/review/review-polish-audit.md"
  STATE="$PRP/state.json"
  [ -d "$PRP" ] || die "no slug directory $PRP"
  [ -f "$STATE" ] || die "no $STATE -- polish runs after build-execute"
}

# The ledger's "## Phase 0" section: its heading up to the next "## " heading.
phase0_body() {
  [ -f "$LEDGER" ] || die "no ledger at $LEDGER -- write Phase 0 first"
  local body
  body="$(awk '/^## Phase 0/{on=1; print; next} on && /^## /{exit} on{print}' "$LEDGER")"
  [ -n "$body" ] || die "the ledger has no '## Phase 0' section"
  printf '%s\n' "$body"
}

# Verify the "hash  path" lines Phase 0 records for its goldens, oracles and witness programs.
goldens_ok() {
  local lines out
  lines="$(printf '%s\n' "$1" | grep -E '^[0-9a-f]{64}  .')"
  [ -n "$lines" ] || { echo "Phase 0 records no sha256 lines for its goldens and witness programs" >&2; return 2; }
  out="$(cd "$ROOT" && printf '%s\n' "$lines" | shasum -a 256 -c 2>&1)" \
    || { printf '%s\n' "$out" | grep -v ': OK$' >&2; return 1; }
  echo "goldens unchanged ($(printf '%s\n' "$lines" | wc -l | tr -d ' ') files)"
}

# The code as it stands: HEAD, the tracked diff, and the untracked files' names and contents. The
# two files polish writes itself are left out, or every ledger row would make the snapshot stale.
fingerprint() {
  local skip_state=":(exclude)${STATE#"$ROOT"/}" skip_ledger=":(exclude)${LEDGER#"$ROOT"/}"
  { git -C "$ROOT" rev-parse HEAD
    git -C "$ROOT" diff HEAD --binary -- . "$skip_state" "$skip_ledger"
    git -C "$ROOT" ls-files --others --exclude-standard -- . "$skip_state" "$skip_ledger"
    git -C "$ROOT" ls-files -z --others --exclude-standard -- . "$skip_state" "$skip_ledger" \
      | xargs -0 git -C "$ROOT" hash-object --
  } | shasum -a 256 | cut -d' ' -f1
}

state_get() {
  python3 - "$STATE" "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if sys.argv[2] == "#decisions":
    v = d.get("decisions")
    print(len(v) if isinstance(v, (list, dict)) else 0)
else:
    p = d.get("polish")
    print((p if isinstance(p, dict) else {}).get(sys.argv[2], ""))
PY
}

# state_set key value [key value ...] -- writes state.json -> polish.<key>, keeping non-ASCII text.
# A null "polish" counts as absent; any other non-object value is refused, never overwritten.
state_set() {
  python3 - "$STATE" "$@" <<'PY'
import json, os, sys
path, kv = sys.argv[1], sys.argv[2:]
d = json.load(open(path))
p = d.get("polish")
if p is None:
    p = d["polish"] = {}
elif not isinstance(p, dict):
    sys.exit("polish: state.json -> polish is a %s, not an object; fix it by hand" % type(p).__name__)
for k, v in zip(kv[::2], kv[1::2]):
    p[k] = v
tmp = path + ".polish-tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
PY
}

# Live processes matching any --driver pattern. Lines naming polish.sh are skipped, since this
# script's own command line (and the shell that launched it) carries the patterns as arguments --
# which is also why this reads ps rather than pgrep -f, which would match those lines.
live() {
  # shellcheck disable=SC2009
  ps -ww -eo pid=,command= | grep -v 'polish\.sh' | while read -r pid cmd; do
    for p in ${DRIVERS[@]+"${DRIVERS[@]}"}; do
      case "$cmd" in *"$p"*) echo "  $pid $cmd"; break ;; esac
    done
  done
}

cmd_pin() {
  [ $# -ge 1 ] || die "usage: pin <slug> [--repin]"
  local slug="$1" repin="${2:-}" body h pin head nd pd snap was now
  slug_paths "$slug"
  body="$(phase0_body)" || exit 2
  h="$(printf '%s\n' "$body" | shasum -a 256 | cut -d' ' -f1)"
  pin="$(state_get pin)"; head="$(git -C "$ROOT" rev-parse HEAD)"
  if [ -z "$pin" ] || [ "$repin" = "--repin" ]; then
    nd="$(state_get '#decisions')" || die "cannot read $STATE"
    if [ -n "$pin" ]; then
      pd="$(state_get pin_decisions)"
      [ "$nd" -gt "${pd:-0}" ] \
        || die "a re-pin needs the owner's answer recorded in state.json -> decisions first ($nd entries, $pd at the last pin)"
      echo "polish: re-pinning $slug on a recorded owner decision (decisions ${pd:-0} -> $nd)"
    fi
    goldens_ok "$body" || die "not pinned: Phase 0's sha256 lines must be present and match the files"
    state_set pin "$h" pin_head "$head" pin_decisions "$nd" state pinned || die "could not write the pin to $STATE"
    echo "polish: pinned $slug  phase0 $h  head ${head:0:12}"
    exit 0
  fi
  [ "$h" = "$pin" ] || { echo "PIN MOVED: the Phase 0 definition changed after the owner confirmed it" >&2; exit 1; }
  echo "pin OK  pin_head $(state_get pin_head)"
  goldens_ok "$body" || { echo "GOLDEN MOVED: a golden, oracle or witness file changed after the pin" >&2; exit 1; }
  snap="$(state_get last_snapshot)"
  { [ -n "$snap" ] && [ -f "$snap/manifest.txt" ]; } || { echo "no snapshot yet"; exit 3; }
  was="$(sed -n 's/^# head [0-9a-f]* code //p' "$snap/manifest.txt")"
  now="$(fingerprint)"
  if [ "$was" = "$now" ]; then echo "snapshot fresh: $snap"; exit 0; fi
  echo "snapshot STALE: the code changed after $snap was taken -- run again" >&2
  exit 3
}

cmd_run() {
  [ $# -ge 2 ] || die "usage: run <slug> <round> --driver PAT... --keep PATH... -- CMD..."
  local slug="$1" round="$2" pin h l stamp snap log rc started k dest fp
  shift 2
  slug_paths "$slug"
  DRIVERS=(); KEEP=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --driver) [ $# -ge 2 ] || die "--driver needs a pattern"; DRIVERS+=("$2"); shift 2 ;;
      --keep)   [ $# -ge 2 ] || die "--keep needs a path";      KEEP+=("$2");    shift 2 ;;
      --)       shift; break ;;
      *)        die "unknown argument: $1" ;;
    esac
  done
  [ $# -gt 0 ] || die "no command after --"
  [ "${#DRIVERS[@]}" -gt 0 ] || die "name at least one --driver pattern: what counts as a live run"
  [ "${#KEEP[@]}" -gt 0 ] || die "name at least one --keep path: what the snapshot copies"

  pin="$(state_get pin)"
  [ -n "$pin" ] || die "no pin: Phase 0 is not confirmed. Run: polish.sh pin $slug"
  h="$(phase0_body | shasum -a 256 | cut -d' ' -f1)" || exit 2
  [ "$h" = "$pin" ] \
    || die "the Phase 0 definition changed after it was pinned -- only the owner moves it (pin $slug --repin)"
  l="$(live)"
  [ -z "$l" ] || { printf 'polish: a driver is already running -- one at a time:\n%s\n' "$l" >&2; exit 2; }

  stamp="$(date +%Y%m%dT%H%M%S)"
  snap="$SNAPROOT/$slug/r$round-$stamp"
  mkdir -p "$snap" || die "cannot create $snap"
  log="$snap/run.log"
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  trap 'echo "polish: interrupted -- check ps for the driver before the next run" >&2; exit 130' INT
  trap 'echo "polish: terminated -- check ps for the driver before the next run" >&2; exit 143' TERM
  echo "polish: round $round -- running: $*"
  "$@" 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}

  l="$(live)"
  if [ -n "$l" ]; then
    printf 'polish: the command exited but a driver is still running -- no snapshot taken:\n%s\n' "$l" >&2
    exit 3
  fi
  # -L copies what a link points at, so the snapshot holds content and never a pointer back into
  # a tree the next run will rewrite.
  for k in "${KEEP[@]}"; do
    if [ -e "$k" ]; then
      dest="$snap/tree$(cd "$(dirname "$k")" && pwd)"
      mkdir -p "$dest" || die "cannot create $dest"
      cp -RL "$k" "$dest/" || die "copy failed: $k"
    else
      echo "MISSING $k" >> "$snap/missing.txt"
    fi
  done
  fp="$(fingerprint)"
  {
    echo "# round $round exit $rc started $started ended $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# head $(git -C "$ROOT" rev-parse HEAD) code $fp"
    echo "# command: $*"
    if [ -d "$snap/tree" ]; then
      (cd "$snap" && find tree -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256)
    fi
  } > "$snap/manifest.txt"
  chmod -R a-w "$snap"
  state_set round "$round" last_snapshot "$snap" state running \
    || die "the snapshot $snap was taken, but $STATE was not updated to point at it"
  echo "polish: round $round snapshot $snap -- command exit $rc, $(grep -vc '^#' "$snap/manifest.txt") files$([ -f "$snap/missing.txt" ] && echo ", $(wc -l < "$snap/missing.txt" | tr -d ' ') kept path(s) MISSING")"
}

# A VERDICT is a place where a finding was decided; a LEAD is a place that only mentions it.
cmd_seen() {
  [ $# -ge 2 ] || die "usage: seen <slug> <text>"
  local slug="$1" text="$2" verdicts leads
  slug_paths "$slug"
  verdicts="$(grep -rnF -- "$text" \
      "$ROOT"/.claude/PRPs/*/review/review-polish-audit.md \
      "$ROOT"/.claude/PRPs/*/state.json \
      "$ROOT"/.claude/PRPs/*/evaluate.md 2>/dev/null | sed "s|^$ROOT/|VERDICT |")"
  leads="$(grep -rnF -- "$text" "$ROOT/.serena/memories" "$ROOT/.claude/parking-lot.md" 2>/dev/null \
      | sed "s|^$ROOT/|LEAD    |")"
  [ -z "$verdicts" ] || printf '%s\n' "$verdicts"
  [ -z "$leads" ] || printf '%s\n' "$leads"
  [ -n "$verdicts" ] && exit 0
  echo "no verdict for: $text"
  exit 1
}

case "${1:-}" in
  pin)  shift; cmd_pin "$@" ;;
  run)  shift; cmd_run "$@" ;;
  seen) shift; cmd_seen "$@" ;;
  *)    sed -n '2,12p' "$0"; exit 2 ;;
esac
