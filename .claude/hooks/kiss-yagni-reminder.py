#!/usr/bin/env python3
"""
HOOK: kiss-yagni-reminder.py
TRIGGER: PreToolUse on Write or Edit
PURPOSE: One-line KISS/YAGNI checkpoint printed to stderr when writing code files.

Reminds — does not block. Exit 0 always.

Lifted from naf-mentor-dashboard-frontend and generalized to cover common code-file
extensions across languages. If your project uses a less common language, add the
extension to CODE_EXTS below.
"""
import json
import sys

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(0)

tool = data.get("tool_name", "")
if tool not in ("Write", "Edit"):
    sys.exit(0)

path = data.get("tool_input", {}).get("file_path", "")

CODE_EXTS = (
    ".py", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".go", ".rs", ".rb", ".java", ".kt", ".swift", ".cs",
    ".cpp", ".c", ".h", ".hpp", ".m", ".mm",
    ".php", ".vue", ".svelte", ".scala", ".clj", ".cljs",
    ".ex", ".exs", ".erl", ".hs", ".ml", ".dart", ".lua", ".sh",
)

if not path.endswith(CODE_EXTS):
    sys.exit(0)

print(
    "KISS/YAGNI checkpoint: Is this the simplest solution needed RIGHT NOW?",
    file=sys.stderr,
)
sys.exit(0)
