// Converts the 16 structured .txt content files into formatted .docx reports
// using docx-js (no Word/COM dependency).
//
// Markup supported per line:
//   # Title       -> Document title (centered, 16pt, bold)
//   ## Heading    -> Heading level 1 (bold, 14pt)
//   ### Heading   -> Heading level 2 (bold italic, 13pt)
//   #### Heading  -> Heading level 3 (bold, 12pt, underline)
//   - bullet text -> Bullet list item (justified)
//   > code line   -> Monospace (Consolas) line, no justify
//   (blank line)  -> Paragraph break
//   anything else -> Justified body paragraph, first-line indent, 1.5 line spacing
//
// Inline markup `**bold**` and `` `code` `` is rendered as real bold / monospace runs.

const fs = require("fs");
const path = require("path");
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  AlignmentType,
  LevelFormat,
  UnderlineType,
} = require("docx");

const INPUT_DIR = "D:\\chess\\Hesabat\\content";
const OUTPUT_DIR = "D:\\chess\\Hesabat";

const STUDENT_INFO_LINES = [
  "AZƏRBAYCAN TEXNİKİ UNİVERSİTETİ",
  "İnformasiya Texnologiyaları və Telekommunikasiya Fakültəsi (İTT)",
  "Qrup: 652a3",
  "Tələbə: Miryusif Məcidov",
];

// twips (1pt = 20 twips)
const MARGIN_TOP = 1416; // 70.8pt
const MARGIN_BOTTOM = 1416;
const MARGIN_LEFT = 1700; // 85.0pt
const MARGIN_RIGHT = 1416;
const FIRST_LINE_INDENT = 708; // 35.4pt
const BULLET_LEFT_INDENT = 566; // 28.3pt
const CODE_LEFT_INDENT = 566; // 28.3pt

function parseInline(text) {
  const segments = [];
  const regex = /(\*\*.+?\*\*|`.+?`)/g;
  let lastIndex = 0;
  let m;
  while ((m = regex.exec(text)) !== null) {
    if (m.index > lastIndex) {
      segments.push({ text: text.slice(lastIndex, m.index), type: "normal" });
    }
    const token = m[0];
    if (token.startsWith("**")) {
      segments.push({ text: token.slice(2, -2), type: "bold" });
    } else {
      segments.push({ text: token.slice(1, -1), type: "code" });
    }
    lastIndex = regex.lastIndex;
  }
  if (lastIndex < text.length) {
    segments.push({ text: text.slice(lastIndex), type: "normal" });
  }
  if (segments.length === 0) segments.push({ text, type: "normal" });
  return segments;
}

function makeRuns(text, base) {
  return parseInline(text).map((seg) => {
    const props = { ...base, text: seg.text };
    if (seg.type === "bold") props.bold = true;
    if (seg.type === "code") props.font = "Consolas";
    return new TextRun(props);
  });
}

function buildChildren(lines) {
  const children = [];

  // Student info header
  for (const l of STUDENT_INFO_LINES) {
    children.push(
      new Paragraph({
        alignment: AlignmentType.CENTER,
        indent: { firstLine: 0 },
        children: [new TextRun({ text: l, bold: true, size: 24 })],
      })
    );
  }
  children.push(
    new Paragraph({
      alignment: AlignmentType.CENTER,
      indent: { firstLine: 0 },
      children: [],
    })
  );

  for (const rawLine of lines) {
    const line = rawLine.replace(/\s+$/, "");
    let m;

    if ((m = line.match(/^# (.+)/))) {
      children.push(
        new Paragraph({
          alignment: AlignmentType.CENTER,
          indent: { firstLine: 0 },
          children: makeRuns(m[1], { size: 32, bold: true }),
        })
      );
      children.push(
        new Paragraph({
          alignment: AlignmentType.CENTER,
          indent: { firstLine: 0 },
          children: [],
        })
      );
    } else if ((m = line.match(/^#### (.+)/))) {
      children.push(
        new Paragraph({
          alignment: AlignmentType.LEFT,
          indent: { firstLine: 0 },
          spacing: { before: 120 },
          children: makeRuns(m[1], {
            size: 24,
            bold: true,
            underline: { type: UnderlineType.SINGLE },
          }),
        })
      );
    } else if ((m = line.match(/^### (.+)/))) {
      children.push(
        new Paragraph({
          alignment: AlignmentType.LEFT,
          indent: { firstLine: 0 },
          spacing: { before: 160 },
          children: makeRuns(m[1], { size: 26, bold: true, italics: true }),
        })
      );
    } else if ((m = line.match(/^## (.+)/))) {
      children.push(
        new Paragraph({
          alignment: AlignmentType.LEFT,
          indent: { firstLine: 0 },
          spacing: { before: 200 },
          children: makeRuns(m[1], { size: 28, bold: true }),
        })
      );
    } else if ((m = line.match(/^- (.+)/))) {
      children.push(
        new Paragraph({
          alignment: AlignmentType.JUSTIFIED,
          numbering: { reference: "bullets", level: 0 },
          children: makeRuns(m[1], { size: 24 }),
        })
      );
    } else if ((m = line.match(/^> (.+)/))) {
      children.push(
        new Paragraph({
          alignment: AlignmentType.LEFT,
          indent: { firstLine: 0, left: CODE_LEFT_INDENT },
          children: [new TextRun({ text: m[1], font: "Consolas", size: 19 })],
        })
      );
    } else if (line.trim() === "") {
      children.push(
        new Paragraph({
          alignment: AlignmentType.JUSTIFIED,
          indent: { firstLine: 0 },
          children: [],
        })
      );
    } else {
      children.push(
        new Paragraph({
          alignment: AlignmentType.JUSTIFIED,
          indent: { firstLine: FIRST_LINE_INDENT },
          children: makeRuns(line, { size: 24 }),
        })
      );
    }
  }

  return children;
}

function main() {
  const files = fs
    .readdirSync(INPUT_DIR)
    .filter((f) => f.endsWith(".txt"))
    .sort();

  for (const file of files) {
    const fullPath = path.join(INPUT_DIR, file);
    const content = fs.readFileSync(fullPath, "utf8");
    let lines = content.split(/\r?\n/);
    if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();

    const doc = new Document({
      styles: {
        default: {
          document: {
            run: { font: "Times New Roman", size: 24 },
            paragraph: { spacing: { line: 360, lineRule: "auto" } },
          },
        },
      },
      numbering: {
        config: [
          {
            reference: "bullets",
            levels: [
              {
                level: 0,
                format: LevelFormat.BULLET,
                text: "•",
                alignment: AlignmentType.LEFT,
                style: {
                  paragraph: {
                    indent: { left: BULLET_LEFT_INDENT + 360, hanging: 360 },
                  },
                },
              },
            ],
          },
        ],
      },
      sections: [
        {
          properties: {
            page: {
              size: { width: 11906, height: 16838 },
              margin: {
                top: MARGIN_TOP,
                bottom: MARGIN_BOTTOM,
                left: MARGIN_LEFT,
                right: MARGIN_RIGHT,
              },
            },
          },
          children: buildChildren(lines),
        },
      ],
    });

    const baseName = path.basename(file, ".txt");
    const outPath = path.join(OUTPUT_DIR, baseName + ".docx");

    Packer.toBuffer(doc).then((buffer) => {
      fs.writeFileSync(outPath, buffer);
      console.log("-> " + outPath);
    });
  }
}

main();
