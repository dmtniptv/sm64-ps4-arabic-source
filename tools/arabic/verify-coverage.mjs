import assert from "node:assert/strict";
import fs from "node:fs";

const file = (name) => fs.readFileSync(new URL(`../../${name}`, import.meta.url), "utf8");
const json = (name) => JSON.parse(file(`text/ar/${name}.json`));
const ids = [...file("text/us/dialogs.h").matchAll(/^DEFINE_DIALOG\((DIALOG_\d+),/gm)].map((m) => m[1]);
const { dialogs } = json("translations");
const { courses, secretCourses, castleSecretStars, extra } = json("courses");
const { entries } = json("credits");
assert.equal(ids.length, 170);
assert.deepEqual(Object.keys(dialogs), ids);
assert.equal(courses.length, 15);
assert.equal(secretCourses.length, 10);
assert.equal(entries.length, 20);
assert.ok(courses.every(({ acts }) => acts.length === 6));
assert.ok(secretCourses.slice(0, 9).every(({ name }) => name.length > 0));
assert.equal(extra.length, 7);
const strings = [
  ...Object.values(dialogs),
  ...courses.flatMap(({ name, acts }) => [name, ...acts]),
  ...secretCourses.slice(0, 9).map(({ name }) => name),
  castleSecretStars, extra[0],
  ...Object.values(json("strings").strings),
  ...Object.values(json("ui")).map(({ text }) => text),
  ...entries.flatMap(({ roles, names }) => [...roles, ...names]),
];
for (const str of strings) {
  assert.match(str, /\p{Script=Arabic}/u);
  const visible = str === "ترجمة ABSTARS" ? "ترجمة" : str;
  assert.doesNotMatch(visible.replace(/\b(?:L1|R1|OPTIONS)\b/g, ""), /[A-Za-z]/u);
}
const charmap = file("charmap.txt");
for (const name of ["dialogs.h", "courses.h", "generated/text_strings.h"]) {
  const characters = new Set(file(`text/ar/${name}`));
  for (const character of characters) {
    if (character.codePointAt(0) > 127) {
      assert.ok(charmap.includes(`'${character}'`), `${name}: unmapped character ${character}`);
    }
  }
}
console.log("Arabic source coverage verified: 170 dialogs, 90 acts, 24 named stages and 20 credit cards");
