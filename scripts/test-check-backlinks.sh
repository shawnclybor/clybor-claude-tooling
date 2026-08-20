#!/usr/bin/env bash
# test-check-backlinks.sh — fixture-based parsing tests for check-backlinks.sh
#
# Exercises the awk extraction blocks against three registry-row shapes:
#   1. Plain        — "| **Local folder** | `path/` |"
#   2. Annotated    — "| **Local folder** | `path/` *(annotation with `nested/` backticks)* |"
#   3. Pending      — "| **Local folder** | *Not yet created* |"
#
# Exit codes: 0 = all pass, 1 = at least one fixture diverged from expected output.

set -u

FIXTURE=$(mktemp)
trap 'rm -f "$FIXTURE"' EXIT

cat > "$FIXTURE" <<'EOF'
## Active Projects

### Plain Project
| Key | Value |
|-----|-------|
| **Local folder** | `plain/` |
| **Memory file** | `memory/projects/plain.md` |

### Annotated Project
| Key | Value |
|-----|-------|
| **Local folder** | `annotated/` *(folder note — see `annotated/downloads/`)* |
| **Memory file** | `memory/projects/annotated.md` *(in progress)* |

### Pending Project
| Key | Value |
|-----|-------|
| **Local folder** | `pending/` *(pre-sign; graduates post-sign per rule `abc-123`)* |
| **Memory file** | *Not yet created* |

## Archived Projects

### Should Be Ignored
| Key | Value |
|-----|-------|
| **Local folder** | `should-not-appear/` |
| **Memory file** | `memory/projects/should-not-appear.md` |
EOF

# Mirror the active-section filter from check-backlinks.sh
active=$(awk '
  /^## Active Projects/ { in_active = 1; next }
  /^## / && in_active   { in_active = 0 }
  /^### / && in_active  { sub(/^### /, ""); print }
' "$FIXTURE")

expected_active="Plain Project
Annotated Project
Pending Project"

if [[ "$active" != "$expected_active" ]]; then
  echo "FAIL: Active-section filter"
  diff <(echo "$expected_active") <(echo "$active")
  exit 1
fi
echo "PASS: Active-section filter"

# Local-folder extraction
fol=$(awk '
  /^### / { sub(/^### /, ""); section = $0; next }
  /^## /  { section = "" }
  /\| \*\*Local folder\*\* \|/ {
    if (section != "") {
      if (match($0, /`[^`]+`/)) {
        val = substr($0, RSTART + 1, RLENGTH - 2)
        print section "\t" val
      } else if (match($0, /\*[^*]+\*/)) {
        print section "\t__PENDING__"
      }
    }
  }
' "$FIXTURE")

expected_fol="Plain Project	plain/
Annotated Project	annotated/
Pending Project	pending/
Should Be Ignored	should-not-appear/"

if [[ "$fol" != "$expected_fol" ]]; then
  echo "FAIL: Local-folder extraction"
  diff <(echo "$expected_fol") <(echo "$fol")
  exit 1
fi
echo "PASS: Local-folder extraction (plain + annotated + nested-backtick annotation)"

# Memory-file extraction
mem=$(awk '
  /^### / { sub(/^### /, ""); section = $0; next }
  /^## /  { section = "" }
  /\| \*\*Memory file\*\* \|/ {
    if (section != "") {
      if (match($0, /`[^`]+`/)) {
        val = substr($0, RSTART + 1, RLENGTH - 2)
        print section "\t" val
      } else if (match($0, /\*[^*]+\*/)) {
        print section "\t__PENDING__"
      }
    }
  }
' "$FIXTURE")

expected_mem="Plain Project	memory/projects/plain.md
Annotated Project	memory/projects/annotated.md
Pending Project	__PENDING__
Should Be Ignored	memory/projects/should-not-appear.md"

if [[ "$mem" != "$expected_mem" ]]; then
  echo "FAIL: Memory-file extraction"
  diff <(echo "$expected_mem") <(echo "$mem")
  exit 1
fi
echo "PASS: Memory-file extraction (backtick path + annotated path + italic pending sentinel)"

echo ""
echo "All parsing fixtures passed."
