import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(toolDirectory, "../..");
const ui = JSON.parse(fs.readFileSync(path.join(repository, "text/ar/ui.json"), "utf8"));
Object.assign(ui, JSON.parse(fs.readFileSync(path.join(repository, "text/ar/generated/overlay-labels.json"), "utf8")));
const source = fs.readFileSync(path.join(repository, "text/ar/generated/ui_textures.inc.c"), "utf8");

const names = Object.keys(ui);
for (const name of names) {
  const texture = source.match(new RegExp(`ALIGNED8 static const u8 texture_arabic_ui_${name}\\[\\]\\s*=\\s*\\{([^}]*)\\}`, "u"));
  assert.ok(texture, `Missing Arabic UI texture: ${name}`);
  const bytes = [...texture[1].matchAll(/0x([0-9A-F]{2})/gu)].map((match) => Number.parseInt(match[1], 16));
  const resolution = 2;
  const width = Math.ceil(ui[name].width / 8) * 8 * resolution;
  const height = (ui[name].height ?? 16) * resolution;
  assert.equal(bytes.length, width * height, `${name} texture size mismatch`);
  assert.ok(bytes.some((byte) => (byte & 0x0f) !== 0), `${name} texture is blank`);
  for (const byte of bytes) assert.equal(byte >> 4, 0x0f, `${name} has non-white IA8 intensity`);
  assert.ok(bytes.slice(0, width).every((byte) => (byte & 0x0f) === 0), `${name} touches the top edge`);
  assert.ok(bytes.slice(-width).every((byte) => (byte & 0x0f) === 0), `${name} touches the bottom edge`);
  assert.match(source, new RegExp(`static const Gfx dl_arabic_ui_${name}\\[\\]`, "u"));
}

const table = source.match(/const Gfx \*const arabic_ui_text_table\[ARABIC_UI_TEXT_COUNT\]\s*=\s*\{([^}]*)\}/u);
assert.ok(table, "Missing Arabic UI display-list table");
const tableNames = [...table[1].matchAll(/dl_arabic_ui_([a-z_0-9]+)/gu)].map((match) => match[1]);
assert.deepEqual(tableNames, names, "Arabic UI table order differs from ui.json");
assert.ok(fs.existsSync(path.join(repository, "text/ar/generated/ui_text_ids.h")), "Missing generated UI text IDs");
console.log(`Arabic UI textures verified: ${names.length} complete labels`);
