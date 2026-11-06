#!/usr/bin/env node
/**
 * generate-deliverable-docx.js — Markdown to a branded Word document.
 *
 * Usage:
 *   node generate-deliverable-docx.js <input.md> <output.docx> [--brand brand.json] [options]
 *
 * Options (each overrides the brand file's "defaults"):
 *   --title "Readiness Assessment"     --subtitle "Scorecard and gaps"
 *   --meta "Client · Project"          --deliverable "Deliverable 3"
 *   --date "March 2026"                --prepared "Prepared by X for Y"
 *   --stats '[{"value":"124","label":"dbt Models","color":"accent"}]'   (accent, green, yellow, red)
 *
 * Brand file (JSON; every key optional; relative paths resolve from the brand file's folder):
 *   { "name": "Firm", "color": "6262C0", "tableHeaderBg": "EAE8F5", "statBg": "EAE8F5", "statFg": "4A4A9E",
 *     "font": "Aptos", "page": "A4" | "Letter", "logo": "logo.png", "logoSize": [155, 116],
 *     "preparedBy": "Prepared by ...", "defaults": { "title": "...", "meta": "..." } }
 *   Optional "sidebar": { "image": "sidebar.png", "widthIn": 0.62 } draws a full-height strip at the page's left edge.
 * One of --brand or --plain is required; --plain gives Arial, US Letter, blue accent, no logo.
 *
 * Fails loudly (exit 2) when the docx package is missing or the brand's logo file does not exist,
 * instead of silently dropping the logo. Brand files and logos stay in private repos.
 */

const fs = require("fs");
const path = require("path");
let docx;
try {
  docx = require("docx");
} catch (e) {
  console.error(`The docx package is not installed. Run: npm install --prefix "${__dirname}" docx@9`);
  process.exit(2);
}
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, ImageRun,
  Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType, ShadingType,
  LevelFormat, PageBreak, PageNumber, HorizontalPositionRelativeFrom, VerticalPositionRelativeFrom
} = docx;

// --- BRAND ---
function argValue(name) {
  const i = process.argv.indexOf("--" + name);
  return i > -1 ? process.argv[i + 1] : undefined;
}
const DEFAULT_BRAND = {
  name: "", color: "2E5F8A", tableHeaderBg: "E8EEF4", statBg: "E8EEF4", statFg: "2E5F8A",
  font: "Arial", page: "Letter", logo: null, logoSize: [155, 116], sidebar: null, preparedBy: "", defaults: {}
};
function loadBrand() {
  // No silent fallback: a branded deliverable that quietly comes out plain looks like another firm's.
  const p = argValue("brand");
  if (!p && !process.argv.includes("--plain")) {
    console.error("Pass --brand <brand.json>, or --plain for an unbranded document.");
    process.exit(2);
  }
  if (!p) return DEFAULT_BRAND;
  const b = { ...DEFAULT_BRAND, ...JSON.parse(fs.readFileSync(p, "utf-8")) };
  if (!["A4", "Letter"].includes(b.page)) {
    console.error(`Brand page must be "A4" or "Letter", not ${JSON.stringify(b.page)} (brand file ${p})`);
    process.exit(2);
  }
  for (const key of ["logo", "sidebarImage"]) {
    const rel = key === "logo" ? b.logo : b.sidebar && b.sidebar.image;
    if (!rel) continue;
    const abs = path.resolve(path.dirname(p), rel);
    if (!fs.existsSync(abs)) {
      console.error(`${key === "logo" ? "Logo" : "Sidebar image"} not found: ${abs} (from brand file ${p})`);
      process.exit(2);
    }
    if (key === "logo") b.logo = abs;
    else b.sidebar = { ...b.sidebar, image: abs };
  }
  return b;
}
const BRAND = loadBrand();

// --- BRAND COLORS ---
const PURPLE = BRAND.color; // brand accent colour (name kept from the original template)
const GRAY = "666666";
const LIGHT_GRAY = "cccccc";
const FOOTER_GRAY = "7F7F7F";
const CODE_BG = "f5f5f5";
const TABLE_HEADER_BG = BRAND.tableHeaderBg;

const STAT_COLORS = {
  accent: { bg: BRAND.statBg, fg: BRAND.statFg },
  purple: { bg: BRAND.statBg, fg: BRAND.statFg }, // older name for accent
  green:  { bg: "dafbe1", fg: "27864a" },
  yellow: { bg: "fff8c5", fg: "d4880f" },
  red:    { bg: "ffebe9", fg: "c0392b" },
};

const FONT = BRAND.font;
const FONT_MONO = "Courier New";

const BORDER = { style: BorderStyle.SINGLE, size: 1, color: LIGHT_GRAY };
const BORDERS = { top: BORDER, bottom: BORDER, left: BORDER, right: BORDER };
const CELL_MARGINS = { top: 80, bottom: 80, left: 120, right: 120 };

// Page size in DXA (1440 DXA = 1 inch)
const PAGE = BRAND.page === "A4" ? { w: 11906, h: 16838 } : { w: 12240, h: 15840 };
const PAGE_WIDTH = PAGE.w;
const PAGE_HEIGHT = PAGE.h;
const MARGIN = 1440;        // 1 inch
const CONTENT_WIDTH = PAGE_WIDTH - (2 * MARGIN); // ~9026 DXA

// --- LOGO ---
const LOGO_PATH = BRAND.logo;

// --- MARKDOWN PARSER ---
function parseMarkdown(md) {
  const lines = md.split("\n");
  const elements = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    // Skip --- horizontal rules
    if (/^---+\s*$/.test(line)) { i++; continue; }

    // Skip the # title line (replaced by title page)
    if (/^# /.test(line) && !line.startsWith("## ")) { i++; continue; }

    // Code block
    if (line.startsWith("```")) {
      const codeLines = [];
      i++;
      while (i < lines.length && !lines[i].startsWith("```")) {
        codeLines.push(lines[i]);
        i++;
      }
      i++; // skip closing ```
      elements.push({ type: "code", content: codeLines.join("\n") });
      continue;
    }

    // Heading 2: ## → H1 in doc
    if (/^## /.test(line)) {
      elements.push({ type: "h2", content: line.replace(/^## /, "").trim() });
      i++; continue;
    }

    // Heading 3: ### → H2 in doc
    if (/^### /.test(line)) {
      elements.push({ type: "h3", content: line.replace(/^### /, "").trim() });
      i++; continue;
    }

    // Heading 4: #### → H3 in doc
    if (/^#### /.test(line)) {
      elements.push({ type: "h4", content: line.replace(/^#### /, "").trim() });
      i++; continue;
    }

    // Heading 5: ##### → H4 in doc (italic)
    if (/^##### /.test(line)) {
      elements.push({ type: "h5", content: line.replace(/^##### /, "").trim() });
      i++; continue;
    }

    // Table
    if (line.includes("|") && i + 1 < lines.length && /^\|[\s:-]+\|/.test(lines[i + 1])) {
      // Keep empty cells in place (dropping them shifted later values left) and honour "\|".
      const splitRow = l => {
        let t = l.trim();
        if (t.startsWith("|")) t = t.slice(1);
        if (t.endsWith("|") && !t.endsWith("\\|")) t = t.slice(0, -1);
        return t.split(/(?<!\\)\|/).map(c => c.trim().replace(/\\\|/g, "|"));
      };
      const tableRows = [splitRow(line)];
      i++; // skip header
      i++; // skip separator
      while (i < lines.length && lines[i].includes("|") && lines[i].trim().startsWith("|")) {
        tableRows.push(splitRow(lines[i]));
        i++;
      }
      const header = tableRows[0].some(c => c); // an all-empty header row means "no header"
      if (!header) tableRows.shift();
      elements.push({ type: "table", rows: tableRows, header });
      continue;
    }

    // Bullet list
    if (/^[\-\*] /.test(line)) {
      const items = [];
      while (i < lines.length && /^[\-\*] /.test(lines[i])) {
        items.push(lines[i].replace(/^[\-\*] /, "").trim());
        i++;
      }
      elements.push({ type: "bullets", items });
      continue;
    }

    // Numbered list
    if (/^\d+\.\s/.test(line)) {
      const items = [];
      while (i < lines.length && /^\d+\.\s/.test(lines[i])) {
        items.push(lines[i].replace(/^\d+\.\s/, "").trim());
        i++;
      }
      elements.push({ type: "numbered", items });
      continue;
    }

    // Empty line
    if (!line.trim()) { i++; continue; }

    // Regular paragraph
    let para = line;
    i++;
    elements.push({ type: "para", content: para.trim() });
    continue;
  }

  return elements;
}

// --- INLINE FORMATTING ---
function formatInline(text, fontSize) {
  const size = fontSize || 22; // 11pt default body
  const codeSize = fontSize ? fontSize - 2 : 18;
  const runs = [];
  const regex = /(\*\*(.+?)\*\*)|(`(.+?)`)/g;
  let lastIndex = 0;
  let match;

  while ((match = regex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      runs.push(new TextRun({ text: text.slice(lastIndex, match.index), font: FONT, size }));
    }
    if (match[2]) {
      runs.push(new TextRun({ text: match[2], bold: true, font: FONT, size }));
    } else if (match[4]) {
      runs.push(new TextRun({
        text: match[4], font: FONT_MONO, size: codeSize,
        shading: { fill: CODE_BG, type: ShadingType.CLEAR }
      }));
    }
    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < text.length) {
    runs.push(new TextRun({ text: text.slice(lastIndex), font: FONT, size }));
  }

  return runs.length ? runs : [new TextRun({ text, font: FONT, size })];
}

// --- DOCX BUILDERS ---
function buildTitlePage(config) {
  const children = [];

  // Spacer
  for (let i = 0; i < 6; i++) {
    children.push(new Paragraph({ spacing: { after: 60 }, children: [] }));
  }

  // Title
  children.push(new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 80 },
    children: [new TextRun({ text: config.title, bold: true, font: FONT, size: 56, color: PURPLE })]
  }));

  // Subtitle
  children.push(new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 60 },
    children: [new TextRun({ text: config.subtitle, font: FONT, size: 28, color: GRAY })]
  }));

  // Meta
  children.push(new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 60 },
    children: [new TextRun({ text: config.meta, font: FONT, size: 24, color: GRAY })]
  }));

  // Deliverable line
  children.push(new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 200 },
    children: [new TextRun({ text: config.deliverable, font: FONT, size: 24, color: GRAY })]
  }));

  // Spacer
  children.push(new Paragraph({ spacing: { after: 60 }, children: [] }));

  // Stats table (if provided)
  if (config.stats && config.stats.length > 0) {
    const colWidth = Math.floor(CONTENT_WIDTH / config.stats.length);
    const statCells = config.stats.map(s => {
      const colors = STAT_COLORS[s.color] || STAT_COLORS.purple;
      return new TableCell({
        borders: BORDERS,
        width: { size: colWidth, type: WidthType.DXA },
        shading: { fill: colors.bg, type: ShadingType.CLEAR },
        margins: { top: 100, bottom: 100, left: 60, right: 60 },
        children: [
          new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new TextRun({ text: s.value, bold: true, font: FONT, size: 36, color: colors.fg })]
          }),
          new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new TextRun({ text: s.label, font: FONT, size: 14, color: GRAY })]
          })
        ]
      });
    });

    children.push(new Table({
      width: { size: CONTENT_WIDTH, type: WidthType.DXA },
      columnWidths: config.stats.map(() => colWidth),
      rows: [new TableRow({ children: statCells })]
    }));
  }

  // Spacers
  children.push(new Paragraph({ spacing: { after: 60 }, children: [] }));
  children.push(new Paragraph({ spacing: { after: 60 }, children: [] }));

  // Attribution
  if (config.prepared) {
    children.push(new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { after: 40 },
      children: [new TextRun({ text: config.prepared, font: FONT, size: 22, color: GRAY })]
    }));
  }
  children.push(new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: config.date, font: FONT, size: 22, color: GRAY })]
  }));

  // Page break after title page
  children.push(new Paragraph({ children: [new PageBreak()] }));

  return children;
}

function buildContent(elements) {
  const children = [];

  for (const el of elements) {
    switch (el.type) {
      case "h2":
        children.push(new Paragraph({
          heading: HeadingLevel.HEADING_1,
          keepNext: true,
          keepLines: true,
          children: [new TextRun({ text: el.content, font: FONT })]
        }));
        break;

      case "h3":
        children.push(new Paragraph({
          heading: HeadingLevel.HEADING_2,
          keepNext: true,
          keepLines: true,
          children: [new TextRun({ text: el.content, font: FONT })]
        }));
        break;

      case "h4":
        children.push(new Paragraph({
          heading: HeadingLevel.HEADING_3,
          keepNext: true,
          keepLines: true,
          children: [new TextRun({ text: el.content, font: FONT })]
        }));
        break;

      case "h5":
        children.push(new Paragraph({
          spacing: { before: 40, after: 100 },
          keepNext: true,
          keepLines: true,
          children: [new TextRun({ text: el.content, font: FONT, size: 24, italics: true })]
        }));
        break;

      case "para":
        children.push(new Paragraph({
          spacing: { after: 120, line: 276 },
          children: formatInline(el.content)
        }));
        break;

      case "bullets":
        for (const item of el.items) {
          children.push(new Paragraph({
            numbering: { reference: "bullets", level: 0 },
            spacing: { after: 60, line: 276 },
            children: formatInline(item)
          }));
        }
        break;

      case "numbered":
        for (const item of el.items) {
          children.push(new Paragraph({
            numbering: { reference: "numbers", level: 0 },
            spacing: { after: 60, line: 276 },
            children: formatInline(item)
          }));
        }
        break;

      case "code":
        for (const codeLine of el.content.split("\n")) {
          children.push(new Paragraph({
            spacing: { after: 0 },
            shading: { fill: CODE_BG, type: ShadingType.CLEAR },
            indent: { left: 360 },
            children: [new TextRun({ text: codeLine || " ", font: FONT_MONO, size: 18 })]
          }));
        }
        children.push(new Paragraph({ spacing: { after: 120 }, children: [] }));
        break;

      case "table": {
        const numCols = Math.max(1, ...el.rows.map(r => r.length));
        const colWidth = Math.floor(CONTENT_WIDTH / numCols);
        const rows = el.rows.map((row, rowIdx) => {
          const cells = row.map(cellText =>
            new TableCell({
              borders: BORDERS,
              width: { size: colWidth, type: WidthType.DXA },
              shading: el.header && rowIdx === 0 ? { fill: TABLE_HEADER_BG, type: ShadingType.CLEAR } : undefined,
              margins: CELL_MARGINS,
              children: [new Paragraph({
                children: el.header && rowIdx === 0
                  ? [new TextRun({ text: cellText, bold: true, font: FONT, size: 20 })]
                  : formatInline(cellText, 20)
              })]
            })
          );
          // Pad if row has fewer cells
          while (cells.length < numCols) {
            cells.push(new TableCell({
              borders: BORDERS,
              width: { size: colWidth, type: WidthType.DXA },
              margins: CELL_MARGINS,
              children: [new Paragraph({ children: [new TextRun({ text: "", font: FONT, size: 20 })] })]
            }));
          }
          return new TableRow({ children: cells, cantSplit: true });
        });

        children.push(new Table({
          width: { size: CONTENT_WIDTH, type: WidthType.DXA },
          columnWidths: Array(numCols).fill(colWidth),
          rows
        }));
        children.push(new Paragraph({ spacing: { after: 120 }, children: [] }));
        break;
      }
    }
  }

  return children;
}

function imageType(file) {
  return /\.jpe?g$/i.test(file) ? "jpg" : "png";
}

function buildHeader() {
  const children = [];

  // Sidebar: a solid image anchored to the page's left edge, full height, behind the text.
  if (BRAND.sidebar && BRAND.sidebar.image) {
    const widthPx = Math.round((BRAND.sidebar.widthIn || 0.62) * 96);
    const heightPx = Math.round((PAGE_HEIGHT / 1440) * 96);
    children.push(new Paragraph({
      children: [new ImageRun({
        type: imageType(BRAND.sidebar.image),
        data: fs.readFileSync(BRAND.sidebar.image),
        transformation: { width: widthPx, height: heightPx },
        floating: {
          horizontalPosition: { relative: HorizontalPositionRelativeFrom.PAGE, offset: 0 },
          verticalPosition: { relative: VerticalPositionRelativeFrom.PAGE, offset: 0 },
          behindDocument: true, allowOverlap: true
        },
        altText: { title: "Sidebar", description: "Brand sidebar", name: "sidebar" }
      })]
    }));
  }

  // Logo in header (top-right)
  if (LOGO_PATH) {
    children.push(new Paragraph({
      alignment: AlignmentType.RIGHT,
      children: [new ImageRun({
        type: imageType(LOGO_PATH),
        data: fs.readFileSync(LOGO_PATH),
        transformation: { width: BRAND.logoSize[0], height: BRAND.logoSize[1] },
        altText: { title: BRAND.name || "Logo", description: `${BRAND.name || "Brand"} logo`, name: "logo" }
      })]
    }));
  } else if (BRAND.name) {
    children.push(new Paragraph({
      alignment: AlignmentType.RIGHT,
      children: [new TextRun({ text: BRAND.name, font: FONT, size: 20, color: PURPLE, bold: true })]
    }));
  }

  return new Header({ children });
}

function buildFooter() {
  return new Footer({
    children: [
      new Paragraph({
        alignment: AlignmentType.RIGHT,
        children: [
          new TextRun({ text: "page ", font: FONT, size: 20, color: FOOTER_GRAY }),
          new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 20, color: FOOTER_GRAY })
        ]
      })
    ]
  });
}

// --- CURRENT DATE ---
function getCurrentDate() {
  const months = ["January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"];
  const now = new Date();
  return `${months[now.getMonth()]} ${now.getFullYear()}`;
}

// --- MAIN ---
async function main() {
  const args = process.argv.slice(2);
  const inputPath = args[0];
  const outputPath = args[1];

  if (!inputPath || !outputPath) {
    console.error("Usage: node generate-deliverable-docx.js <input.md> <output.docx> [options]");
    process.exit(1);
  }

  if (!fs.existsSync(inputPath)) {
    console.error(`Input file not found: ${inputPath}`);
    process.exit(1);
  }

  const md = fs.readFileSync(inputPath, "utf-8");
  const elements = parseMarkdown(md);

  const config = {
    title: "Deliverable", subtitle: "", meta: "", deliverable: BRAND.name,
    prepared: BRAND.preparedBy, date: getCurrentDate(), stats: [],
    ...BRAND.defaults
  };

  // Override from CLI args
  for (let i = 2; i < args.length; i += 2) {
    const key = args[i].replace("--", "");
    const val = args[i + 1];
    if (key === "plain") { i -= 1; continue; } // a flag with no value
    if (key === "brand") continue;
    if (!["title", "subtitle", "meta", "deliverable", "date", "prepared", "stats"].includes(key) || val === undefined) {
      console.error(`Unknown option or missing value: ${args[i]}`);
      process.exit(2);
    }
    if (key === "stats") config.stats = JSON.parse(val);
    else config[key] = val;
  }

  const titlePage = buildTitlePage(config);
  const content = buildContent(elements);

  const doc = new Document({
    styles: {
      default: {
        document: {
          run: { font: FONT, size: 22 },  // 11pt
          paragraph: { spacing: { line: 276 } }  // 1.15 line spacing (240 * 1.15)
        }
      },
      paragraphStyles: [
        {
          id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { size: 32, bold: false, font: FONT },
          paragraph: { spacing: { before: 240, after: 200, line: 276 }, keepNext: true, keepLines: true, outlineLevel: 0 }
        },
        {
          id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { size: 26, bold: false, font: FONT },
          paragraph: { spacing: { before: 40, after: 120, line: 276 }, keepNext: true, keepLines: true, outlineLevel: 1 }
        },
        {
          id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { size: 22, bold: false, font: FONT },
          paragraph: { spacing: { before: 40, after: 100, line: 276 }, keepNext: true, keepLines: true, outlineLevel: 2 }
        },
        {
          id: "Heading4", name: "Heading 4", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { size: 22, bold: false, font: FONT, italics: true },
          paragraph: { spacing: { before: 40, after: 100, line: 276 }, keepNext: true, keepLines: true, outlineLevel: 3 }
        },
        {
          id: "Heading5", name: "Heading 5", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { size: 24, bold: false, font: FONT },
          paragraph: { spacing: { before: 40, after: 100 }, keepNext: true, keepLines: true, outlineLevel: 4 }
        },
      ]
    },
    numbering: {
      config: [
        {
          reference: "bullets",
          levels: [{
            level: 0,
            format: LevelFormat.BULLET,
            text: "\u2022",
            alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 720, hanging: 360 } } }
          }]
        },
        {
          reference: "numbers",
          levels: [{
            level: 0,
            format: LevelFormat.DECIMAL,
            text: "%1.",
            alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 720, hanging: 360 } } }
          }]
        }
      ]
    },
    sections: [{
      properties: {
        page: {
          size: { width: PAGE_WIDTH, height: PAGE_HEIGHT },
          margin: { top: MARGIN, right: MARGIN, bottom: MARGIN, left: MARGIN, header: 708, footer: 708 }
        },
        pageNumberStart: 1
      },
      headers: { default: buildHeader() },
      footers: { default: buildFooter() },
      children: [...titlePage, ...content]
    }]
  });

  const buffer = await Packer.toBuffer(doc);
  fs.writeFileSync(outputPath, buffer);
  console.log(`Generated: ${outputPath} (${(buffer.length / 1024).toFixed(1)} KB)`);
}

main().catch(err => { console.error(err); process.exit(1); });
