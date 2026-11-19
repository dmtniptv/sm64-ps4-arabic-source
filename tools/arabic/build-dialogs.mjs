import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { shapeArabicText } from "./shape-text.mjs";

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(toolDirectory, "../..");
const sourcePath = path.join(repository, "text/us/dialogs.h");
const translationsPath = path.join(repository, "text/ar/translations.json");
const outputPath = path.join(repository, "text/ar/dialogs.h");

const translations = JSON.parse(fs.readFileSync(translationsPath, "utf8"));
let output = fs.readFileSync(sourcePath, "utf8");

function cString(text) {
  // Full-line dialog textures render the PS4 Square symbol. Keep the hidden
  // fallback byte stream compatible with SM64's original charmap so the text
  // compiler can still parse it and drive line/page timing.
  return shapeArabicText(text.replaceAll("×", "[A]").replaceAll("□", "[B]").replaceAll("؛", ","))
    .split("\n")
    .map((line) => `${line.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}\\n\\`)
    .join("\n")
    .replace(/\\n\\$/u, "");
}

for (const [id, logicalText] of Object.entries(translations.dialogs)) {
  const marker = `DEFINE_DIALOG(${id},`;
  const start = output.indexOf(marker);
  if (start < 0) throw new Error(`Could not find ${id} in ${sourcePath}`);
  const next = output.indexOf("DEFINE_DIALOG(DIALOG_", start + marker.length);
  const end = next < 0 ? output.length : next;
  const original = output.slice(start, end);
  const header = original.match(/^DEFINE_DIALOG\((DIALOG_\d{3}),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),/u);
  if (!header) throw new Error(`Could not parse metadata for ${id}`);
  const [, dialogId, unused, linesPerBox, leftOffset, width] = header;
  const replacement = `DEFINE_DIALOG(${dialogId}, ${unused}, ${linesPerBox}, ${leftOffset}, ${width}, _("\\\n${cString(logicalText)}"))\n\n`;
  output = output.slice(0, start) + replacement + output.slice(end);
}

fs.writeFileSync(outputPath, output.trimEnd() + "\n", "utf8");
console.log(`Generated ${outputPath} with ${Object.keys(translations.dialogs).length} Arabic dialogs`);
