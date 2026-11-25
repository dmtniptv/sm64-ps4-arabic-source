# Super Mario 64 PS4 — ABSTARS Native Cheats v2.1 (development)

> **Source prototype, not a finished/verified PS4 PKG.** The working Arabic v1.0 remains unchanged on `main`.
>
> Branch: `native-cheats-v2`. Gameplay toggles default OFF and reset when the game restarts. No save editor is installed.

## Current implemented cheat toggles

| # | English description | Arabic label | Effect |
|---|---|---|---|
| 1 | Infinite Health | صحة لا نهائية | Sets health to full each gameplay tick |
| 2 | 99 Lives | 99 حياة | Restores lives to 99 |
| 3 | 99 Coins | 99 قطعة نقدية | Maintains at least 99 coins (get one normally for 100-coin star) |
| 4 | Extend Special Cap | مدة القبعة بلا حدود | Replenishes active special cap timer |
| 5 | Moon Jump | قفزة القمر | Holding jump boosts upward velocity |
| 6 | Super Speed | السرعة الخارقة | Raises positive forward movement speed |
| 7 | Invincibility | حصانة ضد الأعداء | Keeps invincibility timer active |
| 8 | Slow Fall | سقوط بطيء | Limits downward fall speed |
| 9 | Metal Cap | قبعة المعدن | Grants Metal Cap and replenishes timer |
| 10 | Vanish Cap | قبعة الاختفاء | Grants Vanish Cap and replenishes timer |
| 11 | Wing Cap | قبعة الطيران | Grants Wing Cap and replenishes timer |
| 12 | No Fall Damage | منع ضرر السقوط | Resets recorded peak height during gameplay |

Metal, Vanish and Wing are mutually exclusive in the cheat toggles, to prevent two new forced caps from being active at once. Natural cap power-ups may persist when turning a cheat off.

## Controls (prototype, hardware verification needed)

1. Enter a level and press OPTIONS/Start to pause.
2. Press **L** (mapped L shoulder in the port) to open the cheat menu.
3. **D-pad Up/Down** selects. It automatically switches between the two pages.
4. **A** (PS4 Cross in the port's normal mapping) enables/disables a cheat.
5. Hold **R** and press **Z** (R shoulder + Z action, mapping may differ) to disable all cheats.
6. **B** or **L** closes the cheat menu and returns to the ordinary paused screen.

The Arabic menu uses the existing image-backed Arabic UI texture pipeline rather than unsupported direct UTF-8 printing. New label entries are inserted into `text/ar/ui.json`, then texture regeneration is required. Screen alignment/font rendering is not yet hardware-verified.

## Apply in a local licensed build environment

You need an original **US Super Mario 64 ROM from your own copy**, a configured OpenOrbis 0.5 PS4 toolchain, Python 3, PowerShell, and a font you have permission to use. These are NOT in this GitHub repository.

```bash
git clone --branch ps4 --recurse-submodules https://github.com/OsirizX/sm64-port.git
git clone --branch native-cheats-v2 https://github.com/dmtniptv/sm64-ps4-arabic-source.git
cd sm64-port
git checkout --detach 05356eef0b5b8bd595c35bdf0061eb22f54e9b4e
git submodule update --init --recursive
git apply --check ../sm64-ps4-arabic-source/sm64-ps4-arabic.patch
git apply ../sm64-ps4-arabic-source/sm64-ps4-arabic.patch
python3 ../sm64-ps4-arabic-source/tools/native_cheats_installer.py --check .
python3 ../sm64-ps4-arabic-source/tools/native_cheats_installer.py .
```

Regenerate Arabic UI textures with the generator bundled in the applied Arabic localization, using your local licensed Arabic font and its documented parameters. Confirm all newly generated `ARABIC_UI_CHEAT_*` IDs resolve, then build:

```bash
make -j2 VERSION=us TARGET_PS4=1 ARABIC=1 pkg
```

**Do not upload the ROM, toolchain or proprietary SDK content to public GitHub.**

## Source-level checks (no ROM required)

```bash
python3 -m py_compile tools/native_cheats_installer.py tests/test_native_cheats_installer.py
python3 -m unittest discover -s tests -p 'test_native_cheats_installer.py' -v
```

The `native-cheats-check.yml` workflow runs these same tests on branch pushes. Passing these checks is **not** equivalent to compiling or testing the PS4 game.

## Not yet finished

- Verify that the pinned PS4 source plus Arabic patch accepts all inserted C hooks and symbol names.
- Confirm Arabic texture generation and link all 18 new UI strings.
- Compile the real PKG with OpenOrbis and a user-supplied legal ROM.
- Test menus, toggle combinations, title/home-button behavior, death/warps, special-cap activation, saves and stability on PS4 9.00.
- Add any additional complex cheats (stars, teleport, level-select, noclip, free-camera) only with separate, state-aware implementations and safe save-data rules. They are **not** included yet.

The user-requested **final, tested installable PKG has not been produced**. Do not replace the known-working v1.0 release with untested output.
