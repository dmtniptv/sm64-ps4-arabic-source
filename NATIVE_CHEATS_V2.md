# ABSTARS Super Mario 64 PS4 — Native Cheats v2 (EXPERIMENTAL)

**Status: prototype committed, not built, not tested on PS4. This is not a final PKG.**

This branch keeps the existing Arabic v1.0 release on `main` untouched.

## Current code

`tools/native_cheats_installer.py` adds a basic native cheat submenu to the upstream PS4 source by changing `src/game/ingame_menu.c` and `src/game/mario.c`.

The prototype offers six **session-only** options:
- Refill health to 0x880
- Restore 99 lives
- Keep at least 99 coins
- Extend active special cap timer
- Moon Jump (while holding A)
- Increase forward speed

Open the ordinary in-game **pause menu**, then press **L** to open the prototype cheats screen. Use Up/Down to select, A to toggle, and B or L to leave the cheat screen. Options default OFF and reset after relaunch. This interaction is **not tested** on hardware.

**Important**: The prototype displays **English ASCII labels** as placeholders, NOT Arabic RTL. The prior Arabic localization patch covers the ordinary game text, but this extra menu still needs integration with the existing Arabic text renderer/texture assets. No save modification, full level unlock, or 120-star grant has been implemented.

## Reproduce in a licensed build environment

1. Prepare the original US ROM from your own copy as `baserom.us.z64` and the OpenOrbis PS4 toolchain. Neither is provided here.
2. Clone the upstream PS4 branch and check out `05356eef0b5b8bd595c35bdf0061eb22f54e9b4e` as specified in the Arabic edition's README.
3. Apply the Arabic localization patch `sm64-ps4-arabic.patch` from this repo.
4. Run `python3 /path/to/this/repo/tools/native_cheats_installer.py /path/to/sm64-port`.
5. Review the diff carefully for interactions with the Arabic patch.
6. Compile with `make -j2 VERSION=us TARGET_PS4=1 ARABIC=1 pkg`.

The script verifies source anchors before writing, and stops if the source layout differs. Re-run only if you mean to keep the modifications.

## Before a releasable v2.0

- Ensure compilation succeeds with the pinned upstream and Arabic patch.
- Integrate fully joined RTL Arabic strings and navigation/layout.
- Test opening, closing, toggling, pause/unpause and controller inputs on PS4 9.00.
- Validate Moon Jump and speed behavior, including underwater, flying, cutscenes and death.
- Verify save compatibility and avoid modifying permanent collectibles inadvertently.
- Add a code review, game testing and a new release build.

Do not upload or flash an untested game package over the existing working release.
