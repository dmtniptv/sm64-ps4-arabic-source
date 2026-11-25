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
/* ABSTARS Native Cheats v2.1 — session-only, nonpersistent. */
#define ABSTARS_CHEAT_COUNT 12
#define ABSTARS_CHEATS_PER_PAGE 6
static unsigned char sAbstarsCheatFlags[ABSTARS_CHEAT_COUNT] = { 0 };
static int sAbstarsCheatMenuOpen = 0, sAbstarsCheatSelection = 0;
#ifndef ENABLE_ARABIC
static const char *sAbstarsCheatLabels[ABSTARS_CHEAT_COUNT] = {
    "INFINITE HEALTH", "99 LIVES", "99 COINS", "EXTENDED CAPS",
    "MOON JUMP", "SUPER SPEED", "INVINCIBILITY", "SLOW FALL",
    "METAL CAP", "VANISH CAP", "WING CAP", "NO FALL DAMAGE"
};
#endif

/* Cheats apply while Mario is executing ordinary gameplay only. */
void abstars_native_cheats_apply(struct MarioState *m) {
    if (!m) return;
    if (sAbstarsCheatFlags[0]) {
        m->health = 0x880;
        m->hurtCounter = 0;
    }
    if (sAbstarsCheatFlags[1]) m->numLives = 99;
    /* Avoid repeating the 100-coin-star trigger. Collect one coin normally. */
    if (sAbstarsCheatFlags[2] && m->numCoins < 99) m->numCoins = 99;
    if (sAbstarsCheatFlags[3] && m->capTimer > 0 && m->capTimer < 900)
        m->capTimer = 900;
    if (sAbstarsCheatFlags[4] && m->controller &&
        (m->controller->buttonDown & A_BUTTON) && m->vel[1] < 30.0f)
        m->vel[1] = 30.0f;
    if (sAbstarsCheatFlags[5] && m->forwardVel > 5.0f &&
        m->forwardVel < 48.0f) m->forwardVel = 48.0f;
    if (sAbstarsCheatFlags[6] && m->invincTimer < 20)
        m->invincTimer = 20;
    if (sAbstarsCheatFlags[7] && m->vel[1] < -12.0f)
        m->vel[1] = -12.0f;
    if (sAbstarsCheatFlags[8]) {
        m->flags |= MARIO_METAL_CAP | MARIO_CAP_ON_HEAD;
        if (m->capTimer < 900) m->capTimer = 900;
    }
    if (sAbstarsCheatFlags[9]) {
        m->flags |= MARIO_VANISH_CAP | MARIO_CAP_ON_HEAD;
        if (m->capTimer < 900) m->capTimer = 900;
    }
    if (sAbstarsCheatFlags[10]) {
        m->flags |= MARIO_WING_CAP | MARIO_CAP_ON_HEAD;
        if (m->capTimer < 900) m->capTimer = 900;
    }
    if (sAbstarsCheatFlags[11])
        m->peakHeight = m->pos[1];
}

/* Called only from the paused game menu — no GoldHEN hook required.
 * L opens; D-pad navigates; A toggles; B/L returns; hold R and press Z to clear all.
 * Page moves automatically with selection. Reset toggles on game restart.
 */
static int abstars_native_cheats_pause(void) {
    const u16 pressed = gPlayer3Controller->buttonPressed;
    int page, first, last, i;
#ifndef ENABLE_ARABIC
    char line[80];
#endif
    if (!sAbstarsCheatMenuOpen) {
        if (pressed & L_TRIG) {
            sAbstarsCheatMenuOpen = 1;
            sAbstarsCheatSelection = 0;
            return 1;
        }
        return 0;
    }
    if (pressed & (L_TRIG | B_BUTTON)) {
        sAbstarsCheatMenuOpen = 0;
        return 1;
    }
    if (pressed & U_JPAD)
        sAbstarsCheatSelection =
            (sAbstarsCheatSelection + ABSTARS_CHEAT_COUNT - 1)
            % ABSTARS_CHEAT_COUNT;
    if (pressed & D_JPAD)
        sAbstarsCheatSelection =
            (sAbstarsCheatSelection + 1) % ABSTARS_CHEAT_COUNT;
    if (pressed & A_BUTTON) {
        sAbstarsCheatFlags[sAbstarsCheatSelection] ^= 1;
        /* Exclusive special caps: avoid conflicting Mario cap flags. */
        if (sAbstarsCheatFlags[sAbstarsCheatSelection] &&
            sAbstarsCheatSelection >= 8 && sAbstarsCheatSelection <= 10) {
            for (i = 8; i <= 10; ++i) {
                if (i != sAbstarsCheatSelection) sAbstarsCheatFlags[i] = 0;
            }
        }
    }
    if ((gPlayer3Controller->buttonDown & R_TRIG) && (pressed & Z_TRIG))
        for (i = 0; i < ABSTARS_CHEAT_COUNT; ++i)
            sAbstarsCheatFlags[i] = 0;

    page = sAbstarsCheatSelection / ABSTARS_CHEATS_PER_PAGE;
    first = page * ABSTARS_CHEATS_PER_PAGE;
    last = first + ABSTARS_CHEATS_PER_PAGE;
    if (last > ABSTARS_CHEAT_COUNT) last = ABSTARS_CHEAT_COUNT;
    shade_screen();
#ifdef ENABLE_ARABIC
    {
        static const s16 labels[ABSTARS_CHEAT_COUNT] = {
            ARABIC_UI_CHEAT_HEALTH, ARABIC_UI_CHEAT_LIVES,
            ARABIC_UI_CHEAT_COINS, ARABIC_UI_CHEAT_CAP,
            ARABIC_UI_CHEAT_JUMP, ARABIC_UI_CHEAT_SPEED,
            ARABIC_UI_CHEAT_INVINCIBLE, ARABIC_UI_CHEAT_SLOW_FALL,
            ARABIC_UI_CHEAT_METAL, ARABIC_UI_CHEAT_VANISH,
            ARABIC_UI_CHEAT_WING, ARABIC_UI_CHEAT_NO_FALL
        };
        gSPDisplayList(gDisplayListHead++, dl_ia_text_begin);
        gDPSetEnvColor(gDisplayListHead++, 255, 232, 150, 255);
        render_arabic_ui_text_centered(ARABIC_UI_CHEAT_TITLE, 160, 209);
        render_arabic_ui_text_centered(
            page ? ARABIC_UI_CHEAT_PAGE2 : ARABIC_UI_CHEAT_PAGE1, 160, 192);
        for (i = first; i < last; ++i) {
            s16 y = 164 - (i - first) * 23;
            if (i == sAbstarsCheatSelection) {
                gDPSetEnvColor(gDisplayListHead++, 255, 220, 90, 255);
            } else {
                gDPSetEnvColor(gDisplayListHead++, 250, 250, 250, 255);
            }
            render_arabic_ui_text_at(labels[i],
                295 - arabic_ui_text_width[labels[i]], y);
            render_arabic_ui_text_at(
                sAbstarsCheatFlags[i] ? ARABIC_UI_CHEAT_ON : ARABIC_UI_CHEAT_OFF,
                16, y);
        }
        gDPSetEnvColor(gDisplayListHead++, 255, 255, 255, 255);
        render_arabic_ui_text_centered(ARABIC_UI_CHEAT_HELP, 160, 13);
        gSPDisplayList(gDisplayListHead++, dl_ia_text_end);
    }
#else
    print_text(72, 215, "ABSTARS CHEAT MENU");
    print_text(114, 194, page ? "PAGE 2 / 2" : "PAGE 1 / 2");
    for (i = first; i < last; ++i) {
        snprintf(line, sizeof(line), "%c %s : %s",
            i == sAbstarsCheatSelection ? '>' : ' ',
            sAbstarsCheatLabels[i], sAbstarsCheatFlags[i] ? "ON" : "OFF");
        print_text(32, 160 - (i - first) * 23, line);
    }
    print_text(30, 16, "UP/DOWN, A TOGGLE, R+Z RESET, B BACK");
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
    "cheat_lives": {"text": "99 حياة", "width": 178, "height": 20, "fontSize": 12},
    "cheat_coins": {"text": "99 قطعة نقدية", "width": 178, "height": 20, "fontSize": 12},
    "cheat_cap": {"text": "مدة القبعة بلا حدود", "width": 178, "height": 20, "fontSize": 12},
    "cheat_jump": {"text": "قفزة القمر", "width": 178, "height": 20, "fontSize": 12},
    "cheat_speed": {"text": "السرعة الخارقة", "width": 178, "height": 20, "fontSize": 12},
    "cheat_invincible": {"text": "حصانة ضد الأعداء", "width": 178, "height": 20, "fontSize": 12},
    "cheat_slow_fall": {"text": "سقوط بطيء", "width": 178, "height": 20, "fontSize": 12},
    "cheat_metal": {"text": "قبعة المعدن", "width": 178, "height": 20, "fontSize": 12},
    "cheat_vanish": {"text": "قبعة الاختفاء", "width": 178, "height": 20, "fontSize": 12},
    "cheat_wing": {"text": "قبعة الطيران", "width": 178, "height": 20, "fontSize": 12},
    "cheat_no_fall": {"text": "منع ضرر السقوط", "width": 178, "height": 20, "fontSize": 12},
    "cheat_page1": {"text": "الصفحة 1 من 2", "width": 130, "height": 20, "fontSize": 11},
    "cheat_page2": {"text": "الصفحة 2 من 2", "width": 130, "height": 20, "fontSize": 11},
    "cheat_on": {"text": "مفعل", "width": 56, "height": 20, "fontSize": 12},
    "cheat_off": {"text": "معطل", "width": 56, "height": 20, "fontSize": 12},
    "cheat_help": {"text": "الأسهم: اختيار   أ: تبديل   آر مع زد: تصفير   ب: رجوع", "width": 290, "height": 20, "fontSize": 10},
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
    if "ABSTARS Native Cheats v2" in menu:
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
    ui_file.write_text(json.dumps(ui, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("Native cheats and Arabic UI labels inserted; texture regeneration and compile required.")
    print("Pause -> L to open, D-pad Up/Down, A toggle, B return, hold R + tap Z to reset.")

if __name__=="__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("--check", action="store_true",
                        help="validate source anchors without writing changes")
    args = parser.parse_args()
    main(args.source_dir, check_only=args.check)
