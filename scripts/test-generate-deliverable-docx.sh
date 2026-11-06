#!/usr/bin/env bash
# test-generate-deliverable-docx.sh — fixture tests for generate-deliverable-docx.js.
# Why (2026-11-06): the generator shipped with a logo path from a dead cloud session and no installed
# docx package, and it silently fell back to a text header. These cases pin the brand file, the loud
# failures, and the page size. Synthetic fixtures only.
# Exit 0 = all pass, 1 = a case diverged.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GEN="$HERE/generate-deliverable-docx.js"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
[ -d "$HERE/node_modules/docx" ] || { echo "FAIL precondition: docx not installed; run npm install --prefix \"$HERE\""; exit 1; }
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

printf '# Title\n\n## Section\n\nSome **bold** text.\n\n| a | b |\n|---|---|\n| 1 | 2 |\n' > "$T/in.md"
python3 -c "import base64,sys; open(sys.argv[1],'wb').write(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='))" "$T/logo.png"
cat > "$T/brand.json" <<'EOF'
{"name": "Test Firm", "color": "6262C0", "font": "Aptos", "page": "A4", "logo": "logo.png", "preparedBy": "Prepared by Test Firm for Example Client"}
EOF
xml() { unzip -p "$1" word/document.xml 2>/dev/null; }

# 1. No brand: plain document, Letter size, no image.
node "$GEN" "$T/in.md" "$T/plain.docx" --plain >/dev/null 2>&1 && [ -f "$T/plain.docx" ] || bad "plain run"
if xml "$T/plain.docx" | grep -q 'w:w="12240"' && ! unzip -l "$T/plain.docx" | grep -q 'word/media/'; then ok "no brand: Letter page, no logo"; else bad "no brand: Letter page, no logo"; fi

# 2. Brand: logo embedded, A4, prepared-by line, brand font.
node "$GEN" "$T/in.md" "$T/brand.docx" --brand "$T/brand.json" --title "T" >/dev/null 2>&1 || bad "brand run"
unzip -l "$T/brand.docx" | grep -q 'word/media/' && ok "brand: logo embedded" || bad "brand: logo embedded"
xml "$T/brand.docx" | grep -q 'w:w="11906"' && ok "brand: A4 page" || bad "brand: A4 page"
xml "$T/brand.docx" | grep -q 'Prepared by Test Firm for Example Client' && ok "brand: prepared-by line" || bad "brand: prepared-by line"
xml "$T/brand.docx" | grep -q 'Aptos' && ok "brand: font" || bad "brand: font"

# 3. --prepared overrides the brand line.
node "$GEN" "$T/in.md" "$T/over.docx" --brand "$T/brand.json" --prepared "Prepared by A for B" >/dev/null 2>&1
if xml "$T/over.docx" | grep -q 'Prepared by A for B' && ! xml "$T/over.docx" | grep -q 'Example Client'; then ok "--prepared overrides brand"; else bad "--prepared overrides brand"; fi

# 4. Missing logo fails loudly (exit 2), no output file.
sed 's/logo.png/missing.png/' "$T/brand.json" > "$T/brand-missing.json"
node "$GEN" "$T/in.md" "$T/miss.docx" --brand "$T/brand-missing.json" >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && [ ! -f "$T/miss.docx" ] && ok "missing logo: exit 2" || bad "missing logo: exit $rc"

# 5. Missing docx package fails loudly (exit 2) with the install hint.
mkdir -p "$T/iso" && cp "$GEN" "$T/iso/"
out=$(cd "$T/iso" && NODE_PATH= node ./generate-deliverable-docx.js "$T/in.md" "$T/iso.docx" --plain 2>&1); rc=$?
[ "$rc" = 2 ] && echo "$out" | grep -q "npm install" && ok "missing docx: exit 2 with hint" || bad "missing docx: exit $rc"

# 5b. Neither --brand nor --plain, or an unknown option: exit 2, nothing written.
node "$GEN" "$T/in.md" "$T/none.docx" >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && [ ! -f "$T/none.docx" ] && ok "no --brand or --plain: exit 2" || bad "no --brand or --plain: exit $rc"
node "$GEN" "$T/in.md" "$T/typo.docx" --plain --titel X >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "unknown option: exit 2" || bad "unknown option: exit $rc"

# 5c. Sidebar: a full-height image behind the text, at the page's left edge.
cp "$T/logo.png" "$T/side.png"
python3 -c "import json,sys; b=json.load(open(sys.argv[1])); b['sidebar']={'image':'side.png','widthIn':0.62}; json.dump(b,open(sys.argv[2],'w'))" "$T/brand.json" "$T/brand-side.json"
node "$GEN" "$T/in.md" "$T/side.docx" --brand "$T/brand-side.json" >/dev/null 2>&1
hdr=$(unzip -p "$T/side.docx" 'word/header*.xml' 2>/dev/null)
echo "$hdr" | grep -q 'behindDoc="1"' && echo "$hdr" | grep -q 'relativeFrom="page"' && ok "sidebar: anchored to the page, behind text" || bad "sidebar: anchored to the page, behind text"

# 6. Tables: empty cells keep their column, an empty header row means "no header", "\|" stays in its cell.
printf '# T\n\n| | |\n|---|---|\n| k | v |\n\n| a | b | c |\n|---|---|---|\n| 1 |  | 3 |\n| x \\| y | z | w |\n' > "$T/tab.md"
node "$GEN" "$T/tab.md" "$T/tab.docx" --plain >/dev/null 2>&1; rc=$?
cells=$(unzip -p "$T/tab.docx" word/document.xml 2>/dev/null | python3 -c "
import re,sys
x=sys.stdin.read()
rows=[[''.join(re.findall(r'<w:t[^>]*>([^<]*)</w:t>',c)) for c in re.findall(r'<w:tc>(.*?)</w:tc>',r)] for r in re.findall(r'<w:tr[ >].*?</w:tr>',x)]
print(rows)")
[ "$rc" = 0 ] && ok "tables: empty header row does not crash" || bad "tables: empty header row crashed (exit $rc)"
echo "$cells" | grep -q "\['1', '', '3'\]" && ok "tables: empty cell keeps its column" || bad "tables: empty cell keeps its column ($cells)"
echo "$cells" | grep -q "\['x | y', 'z', 'w'\]" && ok "tables: escaped pipe stays in its cell" || bad "tables: escaped pipe stays in its cell ($cells)"
echo "$cells" | grep -q "\['k', 'v'\]" && ok "tables: headerless table keeps its first row" || bad "tables: headerless table keeps its first row ($cells)"

[ "$fail" = 0 ] && echo "all passed" || echo "some cases FAILED"
exit $fail
