const letters = [
  ["ء", "U", ["\uFE80"]],
  ["آ", "R", ["\uFE81", "\uFE82"]],
  ["أ", "R", ["\uFE83", "\uFE84"]],
  ["ؤ", "R", ["\uFE85", "\uFE86"]],
  ["إ", "R", ["\uFE87", "\uFE88"]],
  ["ئ", "D", ["\uFE89", "\uFE8A", "\uFE8B", "\uFE8C"]],
  ["ا", "R", ["\uFE8D", "\uFE8E"]],
  ["ب", "D", ["\uFE8F", "\uFE90", "\uFE91", "\uFE92"]],
  ["ة", "R", ["\uFE93", "\uFE94"]],
  ["ت", "D", ["\uFE95", "\uFE96", "\uFE97", "\uFE98"]],
  ["ث", "D", ["\uFE99", "\uFE9A", "\uFE9B", "\uFE9C"]],
  ["ج", "D", ["\uFE9D", "\uFE9E", "\uFE9F", "\uFEA0"]],
  ["ح", "D", ["\uFEA1", "\uFEA2", "\uFEA3", "\uFEA4"]],
  ["خ", "D", ["\uFEA5", "\uFEA6", "\uFEA7", "\uFEA8"]],
  ["د", "R", ["\uFEA9", "\uFEAA"]],
  ["ذ", "R", ["\uFEAB", "\uFEAC"]],
  ["ر", "R", ["\uFEAD", "\uFEAE"]],
  ["ز", "R", ["\uFEAF", "\uFEB0"]],
  ["س", "D", ["\uFEB1", "\uFEB2", "\uFEB3", "\uFEB4"]],
  ["ش", "D", ["\uFEB5", "\uFEB6", "\uFEB7", "\uFEB8"]],
  ["ص", "D", ["\uFEB9", "\uFEBA", "\uFEBB", "\uFEBC"]],
  ["ض", "D", ["\uFEBD", "\uFEBE", "\uFEBF", "\uFEC0"]],
  ["ط", "D", ["\uFEC1", "\uFEC2", "\uFEC3", "\uFEC4"]],
  ["ظ", "D", ["\uFEC5", "\uFEC6", "\uFEC7", "\uFEC8"]],
  ["ع", "D", ["\uFEC9", "\uFECA", "\uFECB", "\uFECC"]],
  ["غ", "D", ["\uFECD", "\uFECE", "\uFECF", "\uFED0"]],
  ["ف", "D", ["\uFED1", "\uFED2", "\uFED3", "\uFED4"]],
  ["ق", "D", ["\uFED5", "\uFED6", "\uFED7", "\uFED8"]],
  ["ك", "D", ["\uFED9", "\uFEDA", "\uFEDB", "\uFEDC"]],
  ["ل", "D", ["\uFEDD", "\uFEDE", "\uFEDF", "\uFEE0"]],
  ["م", "D", ["\uFEE1", "\uFEE2", "\uFEE3", "\uFEE4"]],
  ["ن", "D", ["\uFEE5", "\uFEE6", "\uFEE7", "\uFEE8"]],
  ["ه", "D", ["\uFEE9", "\uFEEA", "\uFEEB", "\uFEEC"]],
  ["و", "R", ["\uFEED", "\uFEEE"]],
  ["ى", "R", ["\uFEEF", "\uFEF0"]],
  ["ي", "D", ["\uFEF1", "\uFEF2", "\uFEF3", "\uFEF4"]],
];

export const letterMap = new Map(letters.map(([base, join, forms]) => [base, { base, join, forms }]));

export const lamAlef = new Map([
  ["آ", ["\uFEF5", "\uFEF6"]],
  ["أ", ["\uFEF7", "\uFEF8"]],
  ["إ", ["\uFEF9", "\uFEFA"]],
  ["ا", ["\uFEFB", "\uFEFC"]],
]);

// Keep ASCII, controller icons, spacing, punctuation, and dialog control bytes intact.
const reserved = new Set([
  ...Array.from({ length: 0x40 }, (_, i) => i),
  ...Array.from({ length: 9 }, (_, i) => 0x50 + i),
  0x6e, 0x6f, 0x9e, 0xd0, 0xd1, 0xd2, 0xe0, 0xf0, 0xf1, 0xf2, 0xf3, 0xf4,
  0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff,
]);

const codePool = Array.from({ length: 0x100 }, (_, i) => i).filter((i) => !reserved.has(i));
function contextualForms(forms) {
  if (forms.length === 1) return [{ char: forms[0], connectLeft: false, connectRight: false }];
  if (forms.length === 2) {
    return [
      { char: forms[0], connectLeft: false, connectRight: false },
      { char: forms[1], connectLeft: false, connectRight: true },
    ];
  }
  return [
    { char: forms[0], connectLeft: false, connectRight: false },
    { char: forms[1], connectLeft: false, connectRight: true },
    { char: forms[2], connectLeft: true, connectRight: false },
    { char: forms[3], connectLeft: true, connectRight: true },
  ];
}

const presentationForms = [
  ...letters.flatMap(([, , forms]) => contextualForms(forms)),
  ...Array.from(lamAlef.values()).flatMap((forms) => contextualForms(forms)),
];

if (presentationForms.length > codePool.length) {
  throw new Error(`Arabic glyph table needs ${presentationForms.length} slots; only ${codePool.length} are free`);
}

export const glyphEntries = presentationForms.map(({ char, connectLeft, connectRight }, index) => ({
  char,
  connectLeft,
  connectRight,
  code: codePool[index],
  name: `arabic_${char.codePointAt(0).toString(16).toUpperCase()}`,
}));

export const glyphByChar = new Map(glyphEntries.map((entry) => [entry.char, entry]));
