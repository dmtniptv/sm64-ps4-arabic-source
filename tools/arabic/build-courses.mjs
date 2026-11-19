import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { shapeArabicText } from "./shape-text.mjs";

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(toolDirectory, "../..");
const inputPath = path.join(repository, "text/ar/courses.json");
const outputPath = path.join(repository, "text/ar/courses.h");
const data = JSON.parse(fs.readFileSync(inputPath, "utf8"));

const q = (text) => {
  const compatible = text.replaceAll("؟", "?").replaceAll("،", ",");
  return `_("${shapeArabicText(compatible).replaceAll("\\", "\\\\").replaceAll('"', '\\"')}")`;
};
const qPrefixed = (prefix, text) => {
  const compatible = text.replaceAll("؟", "?").replaceAll("،", ",");
  const visual = `${prefix}${shapeArabicText(compatible)}`;
  return `_("${visual.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}")`;
};
const lines = [];
for (const course of data.courses) {
  if (course.acts.length !== 6) throw new Error(`${course.id} must have exactly six acts`);
  lines.push(`COURSE_ACTS(${course.id}, ${qPrefixed(course.number, course.name)},`);
  lines.push(`       ${course.acts.map(q).join(",\n       ")})`);
  lines.push("");
}
for (const course of data.secretCourses) lines.push(`SECRET_STAR(${course.id}, ${qPrefixed("   ", course.name)})`);
lines.push("");
lines.push(`CASTLE_SECRET_STARS(${qPrefixed("   ", data.castleSecretStars)})`);
lines.push("");
data.extra.forEach((text, index) => lines.push(`EXTRA_TEXT(${index}, ${q(text)})`));
lines.push("");

fs.writeFileSync(outputPath, lines.join("\n"), "utf8");
console.log(`Generated ${outputPath}: ${data.courses.length} courses, ${data.courses.length * 6} acts, ${data.secretCourses.length} secret stages`);
