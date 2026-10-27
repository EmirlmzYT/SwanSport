import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PACKAGE_NAME = "swansport_pro_features"
PACKAGE_DIR = ROOT / "packages" / PACKAGE_NAME


def _yaml_top_level_block(content: str, key: str) -> str:
    lines = content.splitlines()
    start = next(
        (index + 1 for index, line in enumerate(lines) if line == f"{key}:"),
        None,
    )
    if start is None:
        return ""

    body = []
    for line in lines[start:]:
        if line and not line[0].isspace():
            break
        body.append(line)
    return "\n".join(body)


class ProFeaturesContractTest(unittest.TestCase):
    def test_root_workspace_contains_package_exactly_once(self):
        pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        workspace = _yaml_top_level_block(pubspec, "workspace")
        matches = re.findall(
            rf"(?m)^\s*-\s+packages/{PACKAGE_NAME}\s*$",
            workspace,
        )
        self.assertEqual(
            len(matches),
            1,
            f"packages/{PACKAGE_NAME} must be in root workspace exactly once",
        )

    def test_package_has_only_approved_dependencies(self):
        pubspec_path = PACKAGE_DIR / "pubspec.yaml"
        self.assertTrue(pubspec_path.is_file(), f"{pubspec_path} must exist")
        content = pubspec_path.read_text(encoding="utf-8")
        self.assertRegex(content, rf"(?m)^name:\s*{PACKAGE_NAME}\s*$")
        self.assertRegex(content, r"(?m)^resolution:\s*workspace\s*$")

        dependencies = _yaml_top_level_block(content, "dependencies")
        dependency_names = set(
            re.findall(r"(?m)^\s{2}([a-zA-Z0-9_]+):", dependencies)
        )
        approved = {
            "flutter",
            "flutter_riverpod",
            "swansport_core",
            "swansport_data",
            "swansport_models",
            "swansport_branch_engine",
            "qr_flutter",
        }
        self.assertEqual(dependency_names, approved)

    def test_both_apps_depend_on_shared_package(self):
        for app in ("swansport_app", "swansport_pro"):
            content = (ROOT / "apps" / app / "pubspec.yaml").read_text(
                encoding="utf-8"
            )
            dependencies = _yaml_top_level_block(content, "dependencies")
            self.assertRegex(
                dependencies,
                rf"(?m)^\s{{2}}{PACKAGE_NAME}:\s*\^0\.1\.0\s*$",
                f"{app} must depend on {PACKAGE_NAME}",
            )

    def test_ci_and_pro_preview_verify_shared_package_and_host_parity(self):
        ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        preview = (
            ROOT / ".github" / "workflows" / "build_pro_production_preview.yml"
        ).read_text(encoding="utf-8")

        self.assertIn("- packages/swansport_pro_features", ci)
        self.assertIn("packages/swansport_pro_features", preview)
        self.assertIn("tools.pro_features_contract_test", preview)
        self.assertIn("pro_team_directory_host_test.dart", preview)
        self.assertIn("pro_club_panel_host_test.dart", preview)
        self.assertIn("pro_phase2_flags_sql_test.mjs", preview)
        self.assertIn("feature_flag_sync_test.dart", preview)

    def test_shared_sources_do_not_cross_package_boundaries(self):
        lib_dir = PACKAGE_DIR / "lib"
        self.assertTrue(lib_dir.is_dir(), f"{lib_dir} must exist")
        forbidden = {
            "app imports": re.compile(
                r"package:(?:swansport_app|swansport_pro)/"
            ),
            "Supabase singleton": re.compile(r"\bSupabase\.instance\b"),
            "direct table query": re.compile(r"\.from\s*\("),
            "direct RPC": re.compile(r"\.rpc\s*\("),
            "direct auth": re.compile(r"\.auth\b"),
            "app route string": re.compile(
                r"['\"]/(?:teams|takim-kadro|attendance|devam-durumu|"
                r"antrenmanlarim|antrenman-oturumu|antrenman-sonuc|"
                r"antrenman-sablonlari|antrenman-olustur|akis|profil)['\"]"
            ),
        }

        dart_files = sorted(lib_dir.rglob("*.dart"))
        self.assertTrue(dart_files, "shared package must expose Dart sources")
        for dart_file in dart_files:
            content = dart_file.read_text(encoding="utf-8")
            for label, pattern in forbidden.items():
                self.assertIsNone(
                    pattern.search(content),
                    f"{dart_file.relative_to(ROOT)} contains forbidden {label}",
                )


if __name__ == "__main__":
    unittest.main()
