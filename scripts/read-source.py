#!/usr/bin/env python3
"""read-source.py — read a source document completely, or fail loudly.

  python3 scripts/read-source.py FILE OUTDIR [--min-words 50]

Why (2026-11-05): a session declared a roadmap PDF "unreadable" after two tool failures and used a
five-week-old summary instead. The pages were images and could have been rendered. This script makes
"I couldn't read it" stop being an option: every page or slide gets text, an image, or a failure.

  PDF   text per page (pypdf) + a PNG of every page (pypdf split + macOS `sips`)
  PPTX  text per slide + the pictures each slide uses (read straight from the zip)
  DOCX  text only (no page images: LibreOffice is not assumed)
  XLSX  every non-empty row of every sheet (openpyxl)
  TXT / MD / EML  plain-text originals (transcripts, emails received): copied as they are; .eml keeps
        From, To, Date and Subject above the body

The .txt starts with the line  [read-source] original: <absolute path>  so check-draft.py --strict can
tell an extract of an original from our own notes (2026-11-05: a glossary "checked" against our brief
passed, and was wrong against the client's files). The stamp records which file was read; reading our own
notes through this script stamps them too, so it stops accidents, not a deliberate shortcut.

Writes OUTDIR/<stem>.txt (all text) plus page images, then prints "VIEW THESE IMAGES": every page or
slide with under --min-words of text. The script cannot prove you looked; that list is the next step.

Exit 0 = everything readable. 1 = a low-text page/slide has no image either (unreadable — say so,
never substitute a summary). 2 = bad input.
Test hook: READ_SOURCE_NO_RENDER=1 skips PDF rendering (exercises the exit-1 path).
"""
import os
import re
import subprocess
import sys
import zipfile

MIN_WORDS = 50


def words(t):
    return len(t.split())


def read_pdf(path, out, stem):
    import pypdf
    reader = pypdf.PdfReader(path)
    pages = []
    for i, page in enumerate(reader.pages, 1):
        text = page.extract_text() or ""
        png = os.path.join(out, f"{stem}.p{i}.png")
        if not os.environ.get("READ_SOURCE_NO_RENDER"):
            one = os.path.join(out, f".{stem}.p{i}.pdf")
            w = pypdf.PdfWriter()
            w.add_page(page)
            w.write(one)
            subprocess.run(["sips", "-s", "format", "png", "-Z", "1800", one, "--out", png],
                           capture_output=True)
            os.remove(one)
        pages.append((f"page {i}", text, [png] if os.path.exists(png) else [], []))
    return pages


def read_pptx(path, out, stem):
    z = zipfile.ZipFile(path)
    names = set(z.namelist())
    slides = sorted((n for n in names if re.fullmatch(r"ppt/slides/slide\d+\.xml", n)),
                    key=lambda n: int(re.search(r"(\d+)\.xml$", n).group(1)))
    pages = []
    for n in slides:
        num = re.search(r"(\d+)\.xml$", n).group(1)
        text = " ".join(re.findall(r"<a:t(?:\s[^>]*)?>([^<]*)</a:t>", z.read(n).decode("utf-8", "replace")))
        rels = f"ppt/slides/_rels/slide{num}.xml.rels"
        targets = re.findall(r'Target="([^"]+)"', z.read(rels).decode("utf-8", "replace")) if rels in names else []
        imgs, notes = [], []
        for tg in targets:
            src = "ppt/" + tg.split("../", 1)[1] if tg.startswith("../") else tg.lstrip("/")
            if "/media/" in "/" + src:
                if src not in names:
                    notes.append(f"missing picture {tg}")
                    continue
                dst = os.path.join(out, f"{stem}.s{num}.{os.path.basename(src)}")
                with open(dst, "wb") as f:
                    f.write(z.read(src))
                imgs.append(dst)
            elif "/charts/" in src or "/diagrams/" in src:
                # Charts and SmartArt keep their labels and values as XML: read them (chaos review 2026-11-05).
                if src in names:
                    xml = z.read(src).decode("utf-8", "replace")
                    parts = re.findall(r"<a:t(?:\s[^>]*)?>([^<]*)</a:t>|<c:v>([^<]*)</c:v>", xml)
                    text += " [" + ("chart" if "/charts/" in src else "diagram") + ": " + " ".join(x or y for x, y in parts) + "]"
                notes.append(("chart" if "/charts/" in src else "diagram") + " (labels and values read; view the deck for its shape)")
        pages.append((f"slide {num}", text, imgs, notes))
    return pages


def read_docx(path, out, stem):
    z = zipfile.ZipFile(path)
    xml = z.read("word/document.xml").decode("utf-8", "replace")
    paras = re.split(r"</w:p>", xml)
    text = "\n".join(" ".join(re.findall(r"<w:t(?:\s[^>]*)?>([^<]*)</w:t>", p)) for p in paras)
    imgs = []
    for m in (n for n in z.namelist() if n.startswith("word/media/")):
        dst = os.path.join(out, f"{stem}.{os.path.basename(m)}")
        with open(dst, "wb") as f:
            f.write(z.read(m))
        imgs.append(dst)
    return [("document", text, imgs, [])]


def read_xlsx(path):
    import warnings
    import openpyxl
    warnings.filterwarnings("ignore")
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    out = []
    for ws in wb.worksheets:
        rows = [" | ".join("" if c is None else str(c) for c in r)
                for r in ws.iter_rows(values_only=True) if any(c is not None for c in r)]
        out.append((f"sheet {ws.title}", "\n".join(rows), None, []))
    return out


TEXT_TYPES = (".txt", ".md", ".eml")
STAMP = "[read-source] original: "


def read_text(path, ext):
    """Plain-text originals: one part, no image. An .eml keeps its headers above the plain-text body."""
    if ext != ".eml":
        raw = open(path, "rb").read()
        enc = "utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"
        text = raw.decode(enc, errors="replace")
        if text.count("\ufffd") > max(3, len(text) // 200):  # not UTF-8/16: unreadable, not garbage
            raise ValueError("text is not UTF-8 or UTF-16; save it as UTF-8 and try again")
        return [("text", text, None, [])]
    import email
    from email import policy
    with open(path, "rb") as f:
        m = email.message_from_binary_file(f, policy=policy.default)
    head = "\n".join(f"{h}: {m[h]}" for h in ("From", "To", "Cc", "Date", "Subject") if m[h])
    att = [a.get_filename() or a.get_content_type() for a in m.iter_attachments()]
    if att:
        head += "\nAttachments (NOT read here; run read-source on each): " + ", ".join(att)
    part = m.get_body(preferencelist=("plain", "html"))
    body = part.get_content() if part is not None else ""
    if part is not None and part.get_content_type() == "text/html":
        import html
        body = re.sub(r"(?is)<(style|script)\b.*?</\1>", " ", body)
        body = html.unescape(re.sub(r"<[^>]+>", " ", body))
    return [("message", head + "\n\n" + body, None, [])]


def main(argv):
    import argparse
    ap = argparse.ArgumentParser(description="Read a source document completely, or fail loudly.")
    ap.add_argument("file")
    ap.add_argument("outdir")
    ap.add_argument("--min-words", type=int, default=MIN_WORDS)
    try:
        a = ap.parse_args(argv)
    except SystemExit:
        return 2
    if not os.path.isfile(a.file):
        print(f"read-source: no such file: {a.file}")
        return 2
    path, out, min_words = a.file, a.outdir, a.min_words
    os.makedirs(out, exist_ok=True)
    stem, ext = os.path.splitext(os.path.basename(path))
    ext = ext.lower()
    readers = {".pdf": lambda: read_pdf(path, out, stem), ".pptx": lambda: read_pptx(path, out, stem),
               ".docx": lambda: read_docx(path, out, stem), ".xlsx": lambda: read_xlsx(path)}
    readers.update({t: (lambda: read_text(path, ext)) for t in TEXT_TYPES})
    if ext not in readers:
        print(f"read-source: unsupported type {ext} (pdf, pptx, docx, xlsx, txt, md, eml)")
        return 2
    target = os.path.join(out, f"{stem}.txt")
    if os.path.realpath(out) == os.path.realpath(os.path.dirname(os.path.abspath(path))) or (
            os.path.exists(target) and os.path.samefile(target, path)):
        print("read-source: OUTDIR is the original's own folder; pick another folder")
        return 2
    if os.path.exists(target):  # replace only an earlier extract of this same original
        first = open(target, encoding="utf-8", errors="replace").readline()
        if first[len(STAMP):].strip() != os.path.abspath(path) or not first.startswith(STAMP):
            print(f"read-source: {target} already exists and is not an extract of this file; use another OUTDIR")
            return 2
    try:
        tracked = subprocess.run(["git", "-C", os.path.dirname(os.path.abspath(path)), "ls-files", "--error-unmatch",
                                  os.path.basename(path)], capture_output=True).returncode == 0
    except OSError:  # no git on this machine: nothing is tracked
        tracked = False
    if tracked and "raw" not in os.path.abspath(path).lower().split(os.sep):
        print(f"read-source: {os.path.basename(path)} is tracked in git, so it is probably our own notes, not an "
              "original. Originals live outside git (a downloads folder) or under a raw/ folder.")
        return 2
    try:
        pages = readers[ext]()
    except Exception as e:  # encrypted, corrupt, truncated: unreadable, never a crash (chaos review 2026-11-05)
        print(f"UNREADABLE {os.path.basename(path)}: {type(e).__name__}: {e}")
        print("Do not substitute a summary. Report the file as unreadable, or get a readable copy.")
        return 1
    if not pages:
        print(f"UNREADABLE {os.path.basename(path)}: no pages, slides or sheets found")
        return 1
    with open(os.path.join(out, f"{stem}.txt"), "w") as f:
        f.write(f"{STAMP}{os.path.abspath(path)}\n")
        for label, text, _, _ in pages:
            f.write(f"--- {label} ---\n{text}\n")
    view, dead, also = [], [], []
    for label, text, imgs, notes in pages:
        n = words(text)
        if imgs is None:  # Excel and plain text: text only; an empty text file is unreadable
            if ext in TEXT_TYPES and n == 0:
                dead.append((label, n))
            continue
        if n < min_words and imgs:
            view.append((label, n, imgs))
        elif ext == ".docx":
            if n == 0:
                dead.append((label, n))
        elif n < min_words:
            dead.append((label, n))
        elif imgs and ext == ".pptx":
            also.append((label, imgs))
        for note in notes:
            also.append((label, [note]))
    print(f"read-source: {os.path.basename(path)} — {len(pages)} {'pages/slides' if ext in ('.pdf', '.pptx') else 'parts'}, "
          f"{sum(words(t) for _, t, _, _ in pages)} words → {os.path.join(out, stem + '.txt')}")
    if ext in (".docx", ".xlsx") + TEXT_TYPES:
        print("  text only (no page images for Word/Excel); embedded pictures are listed below when present.")
    if view:
        print("VIEW THESE IMAGES (little or no text on these pages — the content is in the picture):")
        for label, n, imgs in view:
            print(f"  {label}: {n} words → " + ", ".join(imgs))
    if also:
        print("ALSO CHECK (pictures, charts or diagrams on pages that also have text):")
        for label, items in also:
            print(f"  {label}: " + ", ".join(items))
    if dead:
        print("UNREADABLE (no text and no image — do not substitute a summary; report it):")
        for label, n in dead:
            print(f"  {label}: {n} words, no image")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
