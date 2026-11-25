#!/usr/bin/env python3
"""Install a prototype native cheat menu into the PS4 port source.

Run after applying the pinned Arabic patch. The menu uses temporary ASCII
labels; it is not a completed Arabic UI or tested PS4 release.

Use --check to validate all source anchors without writing files.
"""
from pathlib import Path
import sys
import argparse
import json

code=r'''
/* ABSTARS Native Cheats v2 prototype (nonpersistent). */
static unsigned char sAbstarsCheatFlags[6] = {0};
static int sAbstarsCheatMenuOpen = 0, sAbstarsCheatSelection = 0;
static const char *sAbstarsCheatLabels[6] = {
    "INFINITE HEALTH", "99 LIVES", "99 COINS",
    "CAP TIMER", "MOON JUMP", "SUPER SPEED"
};
void abstars_native_cheats_apply(struct MarioState *m) {
    if (!m) return;
    if (sAbstarsCheatFlags[0]) { m->health = 0x880; m->hurtCounter = 0; }
    if (sAbstarsCheatFlags[1]) m->numLives = 99;
    if (sAbstarsCheatFlags[2] && m->numCoins < 99) m->numCoins = 99;
    if (sAbstarsCheatFlags[3] && m->capTimer > 0 && m->capTimer < 900)
        m->capTimer = 900;
    if (sAbstarsCheatFlags[4] && m->controller &&
        (m->controller->buttonDown & A_BUTTON) && m->vel[1] < 30.0f)
        m->vel[1] = 30.0f;
    /* Only adjust positive forward velocity to avoid backwards-motion bugs. */
    if (sAbstarsCheatFlags[5] && m->forwardVel > 5.0f &&
        m->forwardVel < 48.0f) m->forwardVel = 48.0f;
}
static int abstars_native_cheats_pause(void) {
    const u16 pressed = gPlayer3Controller->buttonPressed;
    int i;
    char line[80];
    if (!sAbstarsCheatMenuOpen) {
        /* The pause-screen activation keeps normal Mario controls intact. */
        if (pressed & L_TRIG) { sAbstarsCheatMenuOpen = 1; return 1; }
        return 0;
    }
    if (pressed & (L_TRIG | B_BUTTON)) {
        sAbstarsCheatMenuOpen = 0;
        return 1;
    }
    if (pressed & U_JPAD) sAbstarsCheatSelection =
        (sAbstarsCheatSelection + 5) % 6;
    if (pressed & D_JPAD) sAbstarsCheatSelection =
        (sAbstarsCheatSelection + 1) % 6;
    if (pressed & A_BUTTON) sAbstarsCheatFlags[sAbstarsCheatSelection] ^= 1;
    shade_screen();
#ifdef ENABLE_ARABIC
    /* Arabic strings are pre-rasterized by the existing localization pipeline. */
    gSPDisplayList(gDisplayListHead++, dl_ia_text_begin);
    gDPSetEnvColor(gDisplayListHead++, 255, 232, 150, 255);
    render_arabic_ui_text_centered(ARABIC_UI_CHEAT_TITLE, 160, 206);
    for (i = 0; i < 6; i++) {
        static const s16 labels[6] = {
            ARABIC_UI_CHEAT_HEALTH, ARABIC_UI_CHEAT_LIVES,
            ARABIC_UI_CHEAT_COINS, ARABIC_UI_CHEAT_CAP,
            ARABIC_UI_CHEAT_JUMP, ARABIC_UI_CHEAT_SPEED
        };
        s16 y = 180 - i * 23;
        if (i == sAbstarsCheatSelection)
            gDPSetEnvColor(gDisplayListHead++, 255, 220, 90, 255);
        else
            gDPSetEnvColor(gDisplayListHead++, 250, 250, 250, 255);
        render_arabic_ui_text_at(labels[i], 290 - arabic_ui_text_width[labels[i]], y);
        render_arabic_ui_text_at(
            sAbstarsCheatFlags[i] ? ARABIC_UI_CHEAT_ON : ARABIC_UI_CHEAT_OFF,
            26, y);
    }
    gDPSetEnvColor(gDisplayListHead++, 255, 255, 255, 255);
    render_arabic_ui_text_centered(ARABIC_UI_CHEAT_HELP, 160, 20);
    gSPDisplayList(gDisplayListHead++, dl_ia_text_end);
#else
    print_text(65, 24, "ABSTARS CHEAT MENU");
    print_text(35, 42, "UP/DOWN SELECT  A TOGGLE  B BACK");
    for (i = 0; i < 6; i++) {
        snprintf(line, sizeof(line), "%c %s : %s",
            i == sAbstarsCheatSelection ? '>' : ' ',
            sAbstarsCheatLabels[i], sAbstarsCheatFlags[i] ? "ON" : "OFF");
        print_text(55, 64 + i * 19, line);
    }
#endif
    return 1;
}
'''

def replace_once(s, a, b, name):
    if s.count(a) != 1:
        raise RuntimeError(f"{name}: expected one anchor, found {s.count(a)}")
    return s.replace(a, b, 1)

CHEAT_LABELS = {
    "cheat_title": {"text": "قائمة الغش", "width": 160, "height": 20, "fontSize": 13},
    "cheat_health": {"text": "صحة لا نهائية", "width": 178, "height": 20, "fontSize": 12},
    "cheat_lives": {"text": "تسع وتسعون حياة", "width": 178, "height": 20, "fontSize": 12},
    "cheat_coins": {"text": "تسع وتسعون قطعة نقدية", "width": 178, "height": 20, "fontSize": 12},
    "cheat_cap": {"text": "مدة القبعة بلا حدود", "width": 178, "height": 20, "fontSize": 12},
    "cheat_jump": {"text": "قفزة عالية", "width": 178, "height": 20, "fontSize": 12},
    "cheat_speed": {"text": "سرعة خارقة", "width": 178, "height": 20, "fontSize": 12},
    "cheat_on": {"text": "تشغيل", "width": 56, "height": 20, "fontSize": 12},
    "cheat_off": {"text": "إيقاف", "width": 56, "height": 20, "fontSize": 12},
    "cheat_help": {"text": "الأسهم: اختيار   أ: تبديل   ب: رجوع", "width": 260, "height": 20, "fontSize": 11},
}

def main(root, check_only=False):
    menu_file=root/"src/game/ingame_menu.c"
    mario_file=root/"src/game/mario.c"
    menu=menu_file.read_text(encoding="utf-8")
    mario=mario_file.read_text(encoding="utf-8")
    ui_file=root/"text/ar/ui.json"
    if not ui_file.is_file():
        raise RuntimeError("Arabic localization must be applied first (missing text/ar/ui.json)")
    ui=json.loads(ui_file.read_text(encoding="utf-8"))
    for key, entry in CHEAT_LABELS.items():
        if key in ui and ui[key] != entry:
            raise RuntimeError(f"Conflicting Arabic UI label: {key}")
        ui[key]=entry
    if "ABSTARS Native Cheats v2 prototype" in menu:
        print("Already installed")
        return
    menu=replace_once(menu, "#include <ultra64.h>",
        "#include <ultra64.h>\n#include <stdio.h>", "stdio")
    menu=replace_once(menu, "s16 render_pause_courses_and_castle(void) {",
        code+"\ns16 render_pause_courses_and_castle(void) {\n"
        "    if (abstars_native_cheats_pause()) return 0;", "pause")
    mario=replace_once(mario, "s32 execute_mario_action(UNUSED struct Object *o) {",
        "extern void abstars_native_cheats_apply(struct MarioState *m);\n\n"
        "s32 execute_mario_action(UNUSED struct Object *o) {", "declaration")
    mario=replace_once(mario, "        update_mario_health(gMarioState);",
        "        update_mario_health(gMarioState);\n"
        "        abstars_native_cheats_apply(gMarioState);", "health hook")
    if check_only:
        print("CHECK PASSED: all required source anchors found; no changes written.")
        return
    menu_file.write_text(menu, encoding="utf-8")
    mario_file.write_text(mario, encoding="utf-8")
    ui_file.write_text(json.dumps(ui, ensure_ascii=False, indent=2)+"\\n", encoding="utf-8")
    print("Native cheats and Arabic UI labels inserted; texture regeneration and compile required.")
    print("Pause -> L to open, D-pad, A toggle, B back.")

if __name__=="__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("--check", action="store_true",
                        help="validate source anchors without writing changes")
    args = parser.parse_args()
    main(args.source_dir, check_only=args.check)
