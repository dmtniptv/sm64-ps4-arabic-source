import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { glyphEntries } from "./arabic-data.mjs";
import { shapeArabicText } from "./shape-text.mjs";

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(toolDirectory, "../..");
const glyphPath = path.join(repository, "text/ar/generated/font_glyphs.inc.c");
const translationsPath = path.join(repository, "text/ar/translations.json");
const previewPath = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(repository, "text/ar/generated/font-preview.svg");

const source = fs.readFileSync(glyphPath, "utf8");
const arrays = new Map();
for (const match of source.matchAll(/texture_font_char_arabic_([0-9A-F]+)\[\]\s*=\s*\{([^}]*)\}/gu)) {
  const codePoint = Number.parseInt(match[1], 16);
  const bytes = [...match[2].matchAll(/0x([0-9A-F]{2})/gu)].map((byte) => Number.parseInt(byte[1], 16));
  assert.equal(bytes.length, 64, `U+${match[1]} must contain exactly 64 IA4 bytes`);
  arrays.set(codePoint, bytes);
}
assert.equal(arrays.size, glyphEntries.length, "Generated glyph count does not match the Arabic manifest");

function decodeGlyph(entry) {
  const bytes = arrays.get(entry.char.codePointAt(0));
  assert.ok(bytes, `Missing generated glyph for ${entry.char}`);
  const pixels = Array.from({ length: 16 }, () => Array(8).fill(false));
  for (let y = 0; y < 16; y += 1) {
    for (let x = 0; x < 8; x += 1) {
      // The US renderer maps logical (x, y) to physical IA4 (s=y, t=7-x).
      const packedPixel = (7 - x) * 16 + y;
      const byte = bytes[Math.floor(packedPixel / 2)];
      const nibble = packedPixel % 2 === 0 ? byte >> 4 : byte & 0x0f;
      assert.ok(nibble === 0 || nibble === 0x0f, `U+${entry.char.codePointAt(0).toString(16)} has non-binary IA4 pixel`);
      pixels[y][x] = nibble === 0x0f;
    }
  }
  return pixels;
}

const entryByChar = new Map(glyphEntries.map((entry) => [entry.char, entry]));
const pixelsByChar = new Map(glyphEntries.map((entry) => [entry.char, decodeGlyph(entry)]));
const joinRows = [14, 15];

for (const entry of glyphEntries) {
  const pixels = pixelsByChar.get(entry.char);
  if (entry.connectLeft) {
    assert.ok(joinRows.some((row) => pixels[row][0]), `U+${entry.char.codePointAt(0).toString(16)} does not reach the left join edge`);
  }
  if (entry.connectRight) {
    assert.ok(joinRows.some((row) => pixels[row][7]), `U+${entry.char.codePointAt(0).toString(16)} does not reach the right join edge`);
  }
}

const translations = JSON.parse(fs.readFileSync(translationsPath, "utf8"));
let checkedConnections = 0;
for (const text of Object.values(translations.dialogs)) {
  for (const line of shapeArabicText(text).split("\n")) {
    const chars = [...line];
    for (let index = 0; index + 1 < chars.length; index += 1) {
      const left = entryByChar.get(chars[index]);
      const right = entryByChar.get(chars[index + 1]);
      if (!left?.connectRight || !right?.connectLeft) continue;
      const leftPixels = pixelsByChar.get(left.char);
      const rightPixels = pixelsByChar.get(right.char);
      assert.ok(
        joinRows.some((row) => leftPixels[row][7] && rightPixels[row][0]),
        `Disconnected shaped pair ${left.char}${right.char}`,
      );
      checkedConnections += 1;
    }
  }
}
assert.ok(checkedConnections > 0, "No connected Arabic pairs were checked");

const scale = 4;
const panelWidth = 320;
const panelHeight = 116;
const dialogEntries = Object.entries(translations.dialogs);
const svg = [
  `<svg xmlns="http://www.w3.org/2000/svg" width="${panelWidth * scale}" height="${panelHeight * scale * dialogEntries.length}" viewBox="0 0 ${panelWidth * scale} ${panelHeight * scale * dialogEntries.length}">`,
  "<rect width=\"100%\" height=\"100%\" fill=\"#f5f0dc\"/>",
];

for (let panel = 0; panel < dialogEntries.length; panel += 1) {
  const [id, text] = dialogEntries[panel];
  const panelTop = panel * panelHeight;
  svg.push(`<text x="${8 * scale}" y="${(panelTop + 12) * scale}" font-family="sans-serif" font-size="${9 * scale}" fill="#8b1e3f">${id}</text>`);
  let y = panelTop + 18;
  for (const line of shapeArabicText(text).split("\n")) {
    let x = 8;
    for (const char of line) {
      const pixels = pixelsByChar.get(char);
      if (pixels) {
        for (let py = 0; py < 16; py += 1) {
          for (let px = 0; px < 8; px += 1) {
            if (pixels[py][px]) svg.push(`<rect x="${(x + px) * scale}" y="${(y + py) * scale}" width="${scale}" height="${scale}" fill="#111"/>`);
          }
        }
        x += 8;
      } else {
        x += char === " " ? 5 : 6;
      }
    }
    y += 18;
  }
  svg.push(`<line x1="0" y1="${(panelTop + panelHeight - 1) * scale}" x2="${panelWidth * scale}" y2="${(panelTop + panelHeight - 1) * scale}" stroke="#c8bea5"/>`);
}
svg.push("</svg>");

fs.mkdirSync(path.dirname(previewPath), { recursive: true });
fs.writeFileSync(previewPath, `${svg.join("\n")}\n`, "utf8");
console.log(`Arabic font verified: ${glyphEntries.length} glyphs, ${checkedConnections} joined pairs`);
console.log(`Exact renderer preview: ${previewPath}`);
