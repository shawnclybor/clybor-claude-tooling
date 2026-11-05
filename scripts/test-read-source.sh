#!/usr/bin/env bash
# test-read-source.sh — fixture tests for read-source.py (2026-11-05: unreadable-PDF fallback).
# Builds its own PDF / PPTX / DOCX / XLSX fixtures in a temp dir; no client data.
# Exit 0 = all pass, 1 = a case diverged.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RS="$HERE/read-source.py"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { # name expected-exit actual-exit [grep-pattern-that-must-appear output]
  if [ "$2" != "$3" ]; then echo "FAIL $1: exit $3, expected $2"; fail=1; return; fi
  if [ -n "${4:-}" ] && ! grep -q -- "$4" <<<"$5"; then echo "FAIL $1: output lacks '$4'"; fail=1; return; fi
  echo "ok   $1"
}

python3 -I - "$T" <<'PY'
import sys, os, zlib, struct, zipfile
t = sys.argv[1]
words = " ".join(f"word{i}" for i in range(60))
# Text PDF, two pages, hand-built so no PDF library is needed.
def pdf(path, texts):
    objs = ["<< /Type /Catalog /Pages 2 0 R >>", None, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    kids = []
    for tx in texts:
        stream = f"BT /F1 9 Tf 20 700 Td ({tx}) Tj ET".encode()
        objs.append(f"<< /Length {len(stream)} >>\nstream\n{stream.decode()}\nendstream")
        objs.append(f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents {len(objs)} 0 R /Resources << /Font << /F1 3 0 R >> >> >>")
        kids.append(f"{len(objs)} 0 R")
    objs[1] = f"<< /Type /Pages /Kids [{' '.join(kids)}] /Count {len(kids)} >>"
    out, offs = b"%PDF-1.4\n", []
    for i, o in enumerate(objs, 1):
        offs.append(len(out)); out += f"{i} 0 obj\n{o}\nendobj\n".encode()
    x = len(out)
    out += f"xref\n0 {len(objs)+1}\n0000000000 65535 f \n".encode() + b"".join(f"{o:010d} 00000 n \n".encode() for o in offs)
    out += f"trailer\n<< /Size {len(objs)+1} /Root 1 0 R >>\nstartxref\n{x}\n%%EOF\n".encode()
    open(path, "wb").write(out)
pdf(f"{t}/text.pdf", [words, words])
# A small PNG (also used as a slide picture).
def png(path, w=40, h=40):
    raw = b"".join(b"\x00" + b"\xcc\x22\x22" * w for _ in range(h))
    def chunk(k, d): return struct.pack(">I", len(d)) + k + d + struct.pack(">I", zlib.crc32(k + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
png(f"{t}/pic.png")
# PPTX: slide 1 has text, slide 2 only a picture, slide 3 nothing at all.
with zipfile.ZipFile(f"{t}/deck.pptx", "w") as z:
    z.writestr("ppt/slides/slide1.xml", f"<p:sld><a:t>{words}</a:t></p:sld>")
    z.writestr("ppt/slides/slide2.xml", "<p:sld></p:sld>")
    z.writestr("ppt/slides/_rels/slide2.xml.rels", '<Relationships><Relationship Target="../media/image1.png"/></Relationships>')
    z.writestr("ppt/slides/slide10.xml", "<p:sld></p:sld>")
    z.write(f"{t}/pic.png", "ppt/media/image1.png")
with zipfile.ZipFile(f"{t}/memo.docx", "w") as z:
    z.writestr("word/document.xml", "<w:document><w:p><w:r><w:t>Hello memo text</w:t></w:r></w:p></w:document>")
import openpyxl
wb = openpyxl.Workbook(); wb.active.append(["ID", "Status"]); wb.active.append(["_001", "Waiting"]); wb.save(f"{t}/list.xlsx")
open(f"{t}/notes.txt", "w").write("plain")
# Chaos review 2026-11-05 fixtures
with zipfile.ZipFile(f"{t}/chart.pptx", "w") as z:
    z.writestr("ppt/slides/slide1.xml", f"<p:sld><a:t>{words}</a:t></p:sld>")
    z.writestr("ppt/slides/_rels/slide1.xml.rels", '<Relationships><Relationship Target="../charts/chart1.xml"/><Relationship Target="../media/gone.png"/></Relationships>')
    z.writestr("ppt/charts/chart1.xml", "<c:chartSpace><a:t>Open items</a:t><c:v>49</c:v></c:chartSpace>")
with zipfile.ZipFile(f"{t}/empty.pptx", "w") as z:
    z.writestr("ppt/presentation.xml", "<p:presentation/>")
with zipfile.ZipFile(f"{t}/picdoc.docx", "w") as z:
    z.writestr("word/document.xml", "<w:document><w:p><w:r><w:drawing/></w:r></w:p></w:document>")
    z.write(f"{t}/pic.png", "word/media/image1.png")
with zipfile.ZipFile(f"{t}/blankdoc.docx", "w") as z:
    z.writestr("word/document.xml", "<w:document><w:p/></w:document>")
open(f"{t}/corrupt.pdf", "wb").write(b"%PDF-1.4 not really")
PY
sips -s format pdf "$T/pic.png" --out "$T/image.pdf" >/dev/null 2>&1

o=$(python3 "$RS" "$T/text.pdf" "$T/o1" 2>&1); check "text PDF reads clean" 0 $? "2 pages/slides" "$o"
grep -q word59 "$T/o1/text.txt" && [ -f "$T/o1/text.p2.png" ] && echo "ok   text PDF writes text + page images" || { echo "FAIL text PDF outputs missing"; fail=1; }
o=$(python3 "$RS" "$T/image.pdf" "$T/o2" 2>&1); check "image-only PDF lists the page to view" 0 $? "VIEW THESE IMAGES" "$o"
[ -s "$T/o2/image.p1.png" ] && echo "ok   image-only PDF page rendered" || { echo "FAIL image-only PDF page not rendered"; fail=1; }
o=$(READ_SOURCE_NO_RENDER=1 python3 "$RS" "$T/image.pdf" "$T/o3" 2>&1); check "image-only PDF without a render fails" 1 $? "UNREADABLE" "$o"
o=$(python3 "$RS" "$T/deck.pptx" "$T/o4" 2>&1); check "PPTX: blank slide fails" 1 $? "slide 10: 0 words, no image" "$o"
grep -q "slide 2: 0 words" <<<"$o" && grep -q "VIEW THESE IMAGES" <<<"$o" && echo "ok   PPTX: picture-only slide listed to view" || { echo "FAIL PPTX picture slide not listed"; fail=1; }
[ "$(grep -o '^--- slide [0-9]*' "$T/o4/deck.txt" | awk '{print $3}' | tr '\n' ' ')" = "1 2 10 " ] && echo "ok   PPTX: slides in numeric order (1, 2, 10)" || { echo "FAIL PPTX slide order"; fail=1; }
o=$(python3 "$RS" "$T/memo.docx" "$T/o5" 2>&1); check "DOCX text" 0 $? "text only" "$o"
grep -q "Hello memo text" "$T/o5/memo.txt" || { echo "FAIL DOCX text missing"; fail=1; }
o=$(python3 "$RS" "$T/list.xlsx" "$T/o6" 2>&1); check "XLSX rows" 0 $? "" "$o"
grep -q "_001 | Waiting" "$T/o6/list.txt" || { echo "FAIL XLSX row missing"; fail=1; }
o=$(python3 "$RS" "$T/missing.pdf" "$T/o7" 2>&1); check "missing file is bad input" 2 $?
o=$(python3 "$RS" "$T/notes.txt" "$T/o8" 2>&1); check "unsupported type is bad input" 2 $?

o=$(python3 "$RS" "$T/chart.pptx" "$T/o9" 2>&1); check "PPTX chart values are read" 0 $? "ALSO CHECK" "$o"
grep -q "chart: Open items 49" "$T/o9/chart.txt" && grep -q "missing picture" <<<"$o" && echo "ok   PPTX chart text + missing picture reported" || { echo "FAIL PPTX chart/missing picture"; fail=1; }
o=$(python3 "$RS" "$T/empty.pptx" "$T/o10" 2>&1); check "PPTX with no slides fails" 1 $? "no pages" "$o"
o=$(python3 "$RS" "$T/picdoc.docx" "$T/o11" 2>&1); check "picture-only DOCX lists its picture" 0 $? "VIEW THESE IMAGES" "$o"
o=$(python3 "$RS" "$T/blankdoc.docx" "$T/o12" 2>&1); check "blank DOCX fails" 1 $? "UNREADABLE" "$o"
o=$(python3 "$RS" "$T/corrupt.pdf" "$T/o13" 2>&1); check "corrupt PDF is unreadable, not a crash" 1 $? "UNREADABLE corrupt.pdf" "$o"
[ $fail -eq 0 ] && echo "test-read-source: all passed" || echo "test-read-source: FAILURES"
exit $fail
