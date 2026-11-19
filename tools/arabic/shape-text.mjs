import { fileURLToPath } from "node:url";
import { glyphEntries, lamAlef, letterMap } from "./arabic-data.mjs";

const combiningMark = /[\u064B-\u065F\u0670\u06D6-\u06ED]/u;
const ltrChar = /[A-Za-z0-9\[\]!%]/u;

function canJoinBefore(letter) {
  return letter && (letter.join === "D" || letter.join === "R");
}

function canJoinAfter(letter) {
  return letter?.join === "D";
}

function previousLetter(chars, index) {
  for (let i = index - 1; i >= 0; i -= 1) {
    if (combiningMark.test(chars[i])) continue;
    return letterMap.get(chars[i]) ?? null;
  }
  return null;
}

function nextLetter(chars, index) {
  for (let i = index + 1; i < chars.length; i += 1) {
    if (combiningMark.test(chars[i])) continue;
    return letterMap.get(chars[i]) ?? null;
  }
  return null;
}

function shapeLine(line) {
  const chars = Array.from(line.normalize("NFC")).filter((char) => !combiningMark.test(char));
  const shaped = [];

  for (let i = 0; i < chars.length; i += 1) {
    const char = chars[i];
    const letter = letterMap.get(char);
    if (!letter) {
      shaped.push({ char, ltr: ltrChar.test(char) });
      continue;
    }

    const previous = previousLetter(chars, i);
    const joinsPrevious = canJoinAfter(previous) && canJoinBefore(letter);

    if (char === "ل" && lamAlef.has(chars[i + 1])) {
      const forms = lamAlef.get(chars[i + 1]);
      shaped.push({ char: forms[joinsPrevious ? 1 : 0], ltr: false });
      i += 1;
      continue;
    }

    const next = nextLetter(chars, i);
    const joinsNext = canJoinAfter(letter) && canJoinBefore(next);
    let formIndex = 0;
    if (letter.forms.length === 2) formIndex = joinsPrevious ? 1 : 0;
    if (letter.forms.length === 4) {
      formIndex = joinsPrevious && joinsNext ? 3 : joinsPrevious ? 1 : joinsNext ? 2 : 0;
    }
    shaped.push({ char: letter.forms[formIndex], ltr: false });
  }

  shaped.reverse();
  for (let start = 0; start < shaped.length;) {
    if (!shaped[start].ltr) {
      start += 1;
      continue;
    }
    let end = start + 1;
    while (end < shaped.length && shaped[end].ltr) end += 1;
    shaped.splice(start, end - start, ...shaped.slice(start, end).reverse());
    start = end;
  }
  return shaped.map(({ char }) => char).join("");
}

export function shapeArabicText(text) {
  return text.split("\n").map(shapeLine).join("\n");
}

export function charmapFragment() {
  return glyphEntries
    .map(({ char, code }) => `'${char}' = 0x${code.toString(16).toUpperCase().padStart(2, "0")}`)
    .join("\n");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [command, ...rest] = process.argv.slice(2);
  if (command === "--charmap") {
    process.stdout.write(`${charmapFragment()}\n`);
  } else {
    process.stdout.write(`${shapeArabicText(rest.join(" "))}\n`);
  }
}
