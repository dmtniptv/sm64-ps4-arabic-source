# Arabic translation workspace

`translations.json` stores logical-order UTF-8 Arabic. Run:

```sh
node tools/arabic/build-dialogs.mjs
node tools/arabic/shape-text.test.mjs
```

The generator performs contextual Arabic shaping, lam-alef ligatures, right-to-left visual ordering, and preserves short left-to-right number/controller runs. It creates `dialogs.h` by replacing translated entries in the US table; untranslated entries remain English so IDs never shift.

All 170 US dialog IDs are covered. Course and act titles are in `courses.json`, in-game menu and subtitle text in `strings.json`, and ending credits in `credits.json`. Run `node tools/arabic/build-courses.mjs` and `node tools/arabic/build-strings.mjs` after editing the corresponding files. Diacritics are omitted because the original 8x16 renderer has no combining-mark layer.

The generated glyph bitmaps use Noto Naskh Arabic under the SIL Open Font License in `OFL-NotoNaskhArabic.txt`.
