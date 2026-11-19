import fs from "node:fs";

const path = (name) => new URL(`../../text/ar/${name}`, import.meta.url);
const read = (name) => JSON.parse(fs.readFileSync(path(name), "utf8"));
const { courses, secretCourses, castleSecretStars, extra } = read("courses.json");
const { strings } = read("strings.json");
const labels = {};
const add = (id, text, width = 128) => {
  labels[`overlay_${id}`] = { text, width, height: 20, fontSize: 10 };
};
courses.forEach(({ name }, i) => add(`course_${i}`, name));
secretCourses.forEach(({ name }, i) => add(`bonus_${i}`, name || "النهاية"));
courses.flatMap(({ acts }) => acts).forEach((name, i) => add(`act_${i}`, name));
add("castle", castleSecretStars);
add("secret", extra[0]);
add("hundred", "نجمة المئة عملة");
for (const [key, text] of Object.entries(strings)) {
  add(key.slice(5).toLowerCase(), text, key.startsWith("TEXT_NORMAL_") || key.startsWith("TEXT_LAKITU_") ? 80 : 128);
}
fs.writeFileSync(path("generated/overlay-labels.json"), JSON.stringify(labels, null, 2) + "\n");
