import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { shapeArabicText } from "./shape-text.mjs";

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(toolDirectory, "../..");
const inputPath = path.join(repository, "text/ar/strings.json");
const outputPath = path.join(repository, "text/ar/generated/text_strings.h");
const data = JSON.parse(fs.readFileSync(inputPath, "utf8"));
const lines = ["// Generated from text/ar/strings.json. Do not edit by hand.", "#ifdef ENABLE_ARABIC"];

for (const [name, logical] of Object.entries(data.strings)) {
  const compatible = logical.replaceAll("؟", "?").replaceAll("،", ",");
  const visual = shapeArabicText(compatible).replaceAll("\\", "\\\\").replaceAll('"', '\\"');
  lines.push(`#undef ${name}`);
  lines.push(`#define ${name} _("${visual}")`);
}
lines.push("#endif", "");
fs.writeFileSync(outputPath, lines.join("\n"), "utf8");
console.log(`Generated ${outputPath} with ${Object.keys(data.strings).length} Arabic strings`);
