# ABSTARS Super Mario 64 PS4 — Native Cheats v2 (WORK IN PROGRESS)

**Not a compiled or tested PS4 PKG.** This branch preserves Arabic v1.0 on `main`.

## Integrated source modifications

`tools/native_cheats_installer.py` patches the already localized PS4 port source and adds:
- Native pause-screen cheat menu logic (L opens while paused; Up/Down, A toggle, B close)
- Infinite health; 99 lives; minimum 99 coins; extended current special-cap timer
- Experimental moon-jump and forward speed boosts
- Arabic right-to-left screen labels using **the existing generated Arabic UI texture system**, not direct UTF-8 rendering.
- No save editor, permanent 120-star grant, level unlock, or settings persistence.

Arabic labels cover the menu heading, six cheat options, on/off states, and control instructions. The existing `tools/arabic/generate-ui-textures.ps1` must be run after installing the changes to update `text/ar/generated/ui_textures.inc.c` and `ui_text_ids.h`.

## Build instructions

1. Set up OpenOrbis 0.5, the original US `baserom.us.z64` from your own copy, Git, Python 3 and PowerShell with System.Drawing support. Obtain a Unicode Arabic font you are licensed to use. Do not upload your ROM to a public repository.
2. Clone the upstream PS4 port and switch to the pinned revision:

```sh
git clone --branch ps4 --recurse-submodules https://github.com/OsirizX/sm64-port.git
cd sm64-port
git checkout --detach 05356eef0b5b8bd595c35bdf0061eb22f54e9b4e
git submodule update --init --recursive
```

3. Clone this Arabic repo at `native-cheats-v2` in a sibling directory, then apply `sm64-ps4-arabic.patch` to the upstream port with `git apply --check` followed by `git apply`.
4. Validate and apply the menu installer:

```sh
python3 ../sm64-ps4-arabic-source/tools/native_cheats_installer.py --check .
python3 ../sm64-ps4-arabic-source/tools/native_cheats_installer.py .
```

5. Regenerate **Arabic UI textures** from the updated JSON (PowerShell on Windows, with a valid local font path):

```powershell
powershell -ExecutionPolicy Bypass -File tools/arabic/generate-ui-textures.ps1 -FontPath "C:\\path\\to\\your\\licensed-arabic-font.ttf" -OutputDirectory text/ar/generated
```

6. Check `text/ar/generated/ui_text_ids.h` contains `ARABIC_UI_CHEAT_TITLE`, `ARABIC_UI_CHEAT_HEALTH`, and the other menu IDs. Verify the generated images/textures are valid using the existing Arabic validators where supported.
7. Put `baserom.us.z64` in the source root and build:

```sh
make -j2 VERSION=us TARGET_PS4=1 ARABIC=1 pkg
```

**Do not install a build without testing it first.**

## Still to verify

- That the C sources compile and the generated texture tables link correctly.
- That the PS4 controller maps the pause-menu L button as expected and the menu works across pause modes.
- Visual RTL alignment, texture contrast and readability on TV.
- Safety of movement cheats during warps, death, cutscenes and water levels.
- Correct game save handling and compatibility with the installed PKG.
- Build output, launch and stability on PS4 firmware 9.00.

This is *development source*, not a final release or finished package. The exact blocked build prerequisites in this session are a runnable OpenOrbis environment, the legal ROM input, Arabic font path, and a PS4 runtime test.
