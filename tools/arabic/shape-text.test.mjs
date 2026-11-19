import assert from "node:assert/strict";
import fs from "node:fs";
import { glyphByChar, glyphEntries } from "./arabic-data.mjs";
import { charmapFragment, shapeArabicText } from "./shape-text.mjs";

assert.equal(shapeArabicText("مرحبا"), "ﺎﺒﺣﺮﻣ");
assert.equal(shapeArabicText("العربية"), "ﺔﻴﺑﺮﻌﻟﺍ");
assert.equal(shapeArabicText("نجمة 64"), "64 ﺔﻤﺠﻧ");
assert.equal(shapeArabicText("ترجمة Abstars!"), "Abstars! ﺔﻤﺟﺮﺗ");
assert.match(charmapFragment(), /'ﺍ' = 0x[0-9A-F]{2}/u);
assert.equal(new Set(charmapFragment().split("\n")).size, charmapFragment().split("\n").length);
assert.equal(new Set(glyphEntries.map(({ code }) => code)).size, glyphEntries.length);

const translations = JSON.parse(fs.readFileSync(new URL("../../text/ar/translations.json", import.meta.url), "utf8"));
for (const text of Object.values(translations.dialogs)) {
  for (const char of shapeArabicText(text)) {
    if (/\p{Script=Arabic}/u.test(char)) assert.ok(glyphByChar.has(char), `Missing glyph for ${char}`);
  }
}

const glyphSource = fs.readFileSync(new URL("../../text/ar/generated/font_glyphs.inc.c", import.meta.url), "utf8");
for (const match of glyphSource.matchAll(/0x([0-9A-F]{2})/gu)) {
  const byte = Number.parseInt(match[1], 16);
  for (const pixel of [byte >> 4, byte & 0x0f]) {
    assert.ok(pixel === 0 || pixel === 0x0f, `Non-binary IA4 pixel nibble 0x${pixel.toString(16)}`);
  }
}

console.log("Arabic shaping tests passed");
