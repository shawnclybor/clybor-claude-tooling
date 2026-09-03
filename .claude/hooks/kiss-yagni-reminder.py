#!/usr/bin/env python3
"""
HOOK: kiss-yagni-reminder.py
TRIGGER: PreToolUse on Write or Edit
PURPOSE: One-line KISS/YAGNI checkpoint printed to stderr when writing code files.

Reminds — does not block. Exit 0 always.

Covers common code-file extensions across languages. If your project uses a
less common language, add the extension to CODE_EXTS below.
"""
import json
import sys

try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)

tool = data.get("tool_name", "")
if tool not in ("Write", "Edit"):
    sys.exit(0)

# A present-but-null key returns None from .get(<default>), and None.endswith raises.
# A reminder that crashes is worse than no reminder: the traceback reads as a real
# failure and the checkpoint never prints. Coerce, don't assume.
tool_input = data.get("tool_input") or {}
if not isinstance(tool_input, dict):
    sys.exit(0)
path = tool_input.get("file_path") or ""
if not isinstance(path, str):
    sys.exit(0)

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
