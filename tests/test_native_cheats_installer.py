"""Dependency-free checks for native cheat installer (no ROM or PS4 SDK required)."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "native_cheats_installer", ROOT / "tools/native_cheats_installer.py")
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)

MENU_SOURCE = '#include <ultra64.h>\n\ns16 render_pause_courses_and_castle(void) {\n return 0;\n}\n'
MARIO_SOURCE = ('s32 execute_mario_action(UNUSED struct Object *o) {\n'
                '        update_mario_health(gMarioState);\n return 0;\n}\n')

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.addCleanup(self.t.cleanup)
        self.root = Path(self.t.name)
        (self.root / "src/game").mkdir(parents=True)
        (self.root / "text/ar").mkdir(parents=True)
        (self.root / "src/game/ingame_menu.c").write_text(MENU_SOURCE, encoding="utf-8")
        (self.root / "src/game/mario.c").write_text(MARIO_SOURCE, encoding="utf-8")
        (self.root / "text/ar/ui.json").write_text("{}", encoding="utf-8")

    def test_check_only_does_not_write(self):
        before = [(p, p.read_bytes()) for p in self.root.rglob("*") if p.is_file()]
        mod.main(self.root, check_only=True)
        self.assertEqual(before, [(p, p.read_bytes()) for p in self.root.rglob("*") if p.is_file()])

    def test_installs_and_remains_idempotent(self):
        mod.main(self.root)
        m = (self.root / "src/game/ingame_menu.c").read_text(encoding="utf-8")
        c = (self.root / "src/game/mario.c").read_text(encoding="utf-8")
        self.assertEqual(m.count("ABSTARS Native Cheats v2"), 1)
        self.assertIn("ABSTARS_CHEAT_COUNT 12", m)
        self.assertEqual(c.count("abstars_native_cheats_apply(gMarioState);"), 1)
        self.assertNotIn("X_BUTTON", m)
        ui = json.loads((self.root / "text/ar/ui.json").read_text(encoding="utf-8"))
        self.assertEqual(len(mod.CHEAT_LABELS), 18)
        self.assertEqual(ui["cheat_title"]["text"], "قائمة الغش")
        self.assertIn("cheat_wing", ui)
        self.assertIn("cheat_page2", ui)
        mod.main(self.root)
        self.assertEqual(m, (self.root / "src/game/ingame_menu.c").read_text(encoding="utf-8"))

    def test_requires_localization_and_source_anchors(self):
        (self.root / "text/ar/ui.json").unlink()
        with self.assertRaisesRegex(RuntimeError, "Arabic localization"):
            mod.main(self.root, check_only=True)

if __name__ == "__main__":
    unittest.main()
