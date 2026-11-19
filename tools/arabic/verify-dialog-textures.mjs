import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(toolDirectory, "../..");
const generatedDirectory = path.join(repository, "text/ar/generated");
const translations = JSON.parse(fs.readFileSync(path.join(repository, "text/ar/translations.json"), "utf8"));
const manifest = JSON.parse(fs.readFileSync(path.join(generatedDirectory, "dialog_line_manifest.json"), "utf8"));
const source = fs.readFileSync(path.join(generatedDirectory, "dialog_line_textures.inc.c"), "utf8");
const previewPath = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(generatedDirectory, "dialog-line-preview.svg");

const textures = new Map();
for (const match of source.matchAll(/ALIGNED8 static const u8 (texture_arabic_dialog_\d+_line_\d+)\[\]\s*=\s*\{([^}]*)\}/gu)) {
  textures.set(match[1], [...match[2].matchAll(/0x([0-9A-F]{2})/gu)].map((value) => Number.parseInt(value[1], 16)));
}

function sha256(bytes) {
  return crypto.createHash("sha256").update(Uint8Array.from(bytes)).digest("hex");
}

assert.equal(manifest.format, "IA8");
assert.equal(manifest.height, 16);
assert.deepEqual(Object.keys(manifest.dialogs), Object.keys(translations.dialogs), "Dialog texture manifest coverage differs from translations.json");

let verifiedLines = 0;
for (const [id, logicalText] of Object.entries(translations.dialogs)) {
  const dialog = manifest.dialogs[id];
  const logicalLines = logicalText.split("\n");
  assert.equal(dialog.lines.length, logicalLines.length, `${id} line count mismatch`);
  assert.ok(dialog.lines.length <= 32, `${id} exceeds the generated line table capacity`);
  assert.equal(dialog.textureWidth % 8, 0, `${id} texture width must be a multiple of 8`);
  for (let index = 0; index < logicalLines.length; index += 1) {
    const line = dialog.lines[index];
    assert.equal(line.text, logicalLines[index], `${id} line ${index + 1} text mismatch`);
    assert.ok(line.measuredWidth <= dialog.width, `${id} line ${index + 1} exceeds its ${dialog.width}px box`);
    const bytes = textures.get(line.texture);
    assert.ok(bytes, `Missing ${line.texture}`);
    assert.equal(bytes.length, dialog.textureWidth * (dialog.textureHeight ?? manifest.height), `${line.texture} byte size mismatch`);
    assert.equal(bytes.length, line.textureBytes, `${line.texture} manifest byte size mismatch`);
    assert.equal(sha256(bytes), line.textureSha256, `${line.texture} hash mismatch`);
    for (const byte of bytes) assert.equal(byte >> 4, 0x0f, `${line.texture} contains a non-white IA8 intensity`);
    if (logicalLines[index].replaceAll("/", "").trim() !== "") {
      assert.ok(bytes.some((byte) => (byte & 0x0f) !== 0), `${line.texture} is blank`);
      const firstRow = bytes.slice(0, dialog.textureWidth);
      const lastRow = bytes.slice(-dialog.textureWidth);
      assert.ok(firstRow.every((byte) => (byte & 0x0f) === 0), `${line.texture} touches the top edge`);
      assert.ok(lastRow.every((byte) => (byte & 0x0f) === 0), `${line.texture} touches the bottom edge`);
    }
    verifiedLines += 1;
  }
}
assert.equal(textures.size, verifiedLines, "Generated texture count differs from translated line count");

const scale = 4;
const panelWidth = 220;
const dialogEntries = Object.entries(manifest.dialogs);
const previewIds = new Set(["DIALOG_000", "DIALOG_005", "DIALOG_020", "DIALOG_033", "DIALOG_034", "DIALOG_167"]);
const previewEntries = dialogEntries.filter(([id]) => previewIds.has(id));
const panelHeights = previewEntries.map(([, dialog]) => 32 + dialog.lines.length * 18);
const totalHeight = panelHeights.reduce((sum, height) => sum + height, 0);
const svg = [
  `<svg xmlns="http://www.w3.org/2000/svg" width="${panelWidth * scale}" height="${totalHeight * scale}" viewBox="0 0 ${panelWidth * scale} ${totalHeight * scale}">`,
  '<rect width="100%" height="100%" fill="#f5f0dc"/>',
];

let panelTop = 0;
for (let panel = 0; panel < previewEntries.length; panel += 1) {
  const [id, dialog] = previewEntries[panel];
  const panelHeight = panelHeights[panel];
  svg.push(`<text x="${2 * scale}" y="${10 * scale}" transform="translate(0 ${panelTop * scale})" font-family="sans-serif" font-size="${8 * scale}" fill="#8b1e3f">${id}</text>`);
  svg.push(`<rect x="${3 * scale}" y="${(panelTop + 14) * scale}" width="${dialog.width * scale}" height="${(dialog.lines.length * 18 + 2) * scale}" fill="none" stroke="#c8ae7b"/>`);
  for (let lineIndex = 0; lineIndex < dialog.lines.length; lineIndex += 1) {
    const line = dialog.lines[lineIndex];
    const bytes = textures.get(line.texture);
    const originX = 4;
    const originY = panelTop + 15 + lineIndex * 18;
    const textureHeight = dialog.textureHeight ?? manifest.height;
    const pixel = scale * manifest.height / textureHeight;
    for (let y = 0; y < textureHeight; y += 1) {
      for (let x = 0; x < dialog.textureWidth; x += 1) {
        const alpha = bytes[y * dialog.textureWidth + x] & 0x0f;
        if (alpha === 0) continue;
        svg.push(`<rect x="${originX * scale + x * pixel}" y="${originY * scale + y * pixel}" width="${pixel}" height="${pixel}" fill="#111" fill-opacity="${(alpha / 15).toFixed(3)}"/>`);
      }
    }
  }
  svg.push(`<line x1="0" y1="${(panelTop + panelHeight - 1) * scale}" x2="${panelWidth * scale}" y2="${(panelTop + panelHeight - 1) * scale}" stroke="#d8ceb8"/>`);
  panelTop += panelHeight;
}
svg.push("</svg>");

fs.mkdirSync(path.dirname(previewPath), { recursive: true });
fs.writeFileSync(previewPath, `${svg.join("\n")}\n`, "utf8");
console.log(`Arabic dialog textures verified: ${dialogEntries.length} dialogs, ${verifiedLines} complete lines`);
console.log(`Exact compiled-texture preview: ${previewPath}`);
