import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRO_DIR = ROOT / 'apps' / 'swansport_pro'


class ProAppContractTest(unittest.TestCase):
    def test_root_workspace_contains_pro_exactly_once(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        workspace_block = pubspec.split('workspace:')[1].split('\n\n')[0]
        matches = re.findall(r'-\s+apps/swansport_pro\b', workspace_block)
        self.assertEqual(len(matches), 1, "apps/swansport_pro must be in root workspace exactly once")

    def test_pro_pubspec_structure_and_dependencies(self):
        pro_pubspec = PRO_DIR / 'pubspec.yaml'
        self.assertTrue(pro_pubspec.is_file(), "apps/swansport_pro/pubspec.yaml must exist")
        content = pro_pubspec.read_text(encoding='utf-8')

        self.assertRegex(content, r'(?m)^name:\s*swansport_pro\s*$')
        self.assertRegex(content, r'(?m)^version:\s*0\.1\.0\+1\s*$')
        self.assertRegex(content, r'(?m)^resolution:\s*workspace\s*$')

        # Must have required shared/runtime dependencies
        required_deps = [
            'flutter:',
            'flutter_localizations:',
            'flutter_riverpod:',
            'go_router:',
            'supabase_flutter:',
            'swansport_core:',
            'swansport_data:',
            'swansport_design_system:',
        ]
        for dep in required_deps:
            self.assertIn(dep, content)

        # Pro must NOT have firebase or operational dependencies
        forbidden_deps = [
            'firebase_core',
            'firebase_messaging',
            'swansport_branch_engine',
        ]
        for dep in forbidden_deps:
            self.assertNotIn(dep, content)

    def test_android_identity_and_label(self):
        gradle_file = PRO_DIR / 'android' / 'app' / 'build.gradle.kts'
        if not gradle_file.is_file():
            gradle_file = PRO_DIR / 'android' / 'app' / 'build.gradle'
        self.assertTrue(gradle_file.is_file(), "Pro Android build.gradle(.kts) must exist")
        gradle_content = gradle_file.read_text(encoding='utf-8')

        self.assertIn('namespace = "com.swansport.pro"', gradle_content)
        self.assertIn('applicationId = "com.swansport.pro"', gradle_content)

        manifest = PRO_DIR / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
        self.assertTrue(manifest.is_file(), "AndroidManifest.xml must exist")
        manifest_content = manifest.read_text(encoding='utf-8')
        self.assertIn('android:label="SwanSport Pro"', manifest_content)

    def test_ios_identity_and_display_name(self):
        pbxproj = PRO_DIR / 'ios' / 'Runner.xcodeproj' / 'project.pbxproj'
        self.assertTrue(pbxproj.is_file(), "project.pbxproj must exist")
        pbx_content = pbxproj.read_text(encoding='utf-8')

        # Extract all PRODUCT_BUNDLE_IDENTIFIER assigned to the Runner target
        runner_bundle_ids = re.findall(
            r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
            pbx_content,
        )
        self.assertTrue(runner_bundle_ids, "No PRODUCT_BUNDLE_IDENTIFIER found")
        # Every non-test runner bundle ID must equal com.swansport.pro
        non_test_ids = [bid.strip() for bid in runner_bundle_ids if not bid.strip().endswith('Tests')]
        self.assertTrue(non_test_ids, "No non-test bundle identifiers found")
        for bid in non_test_ids:
            self.assertEqual(bid, 'com.swansport.pro')

        info_plist = PRO_DIR / 'ios' / 'Runner' / 'Info.plist'
        self.assertTrue(info_plist.is_file(), "Info.plist must exist")
        plist_content = info_plist.read_text(encoding='utf-8')
        self.assertIn('<key>CFBundleDisplayName</key>\n\t<string>SwanSport Pro</string>', plist_content)

    def test_pro_has_no_firebase_or_push_artifacts(self):
        self.assertFalse(
            (PRO_DIR / 'ios' / 'Runner' / 'GoogleService-Info.plist').exists(),
            "GoogleService-Info.plist must not exist in Pro iOS",
        )
        self.assertFalse(
            (PRO_DIR / 'android' / 'app' / 'google-services.json').exists(),
            "google-services.json must not exist in Pro Android",
        )

        # Ensure no aps-environment in any entitlements
        for ent_file in (PRO_DIR / 'ios').glob('**/*.entitlements'):
            ent_content = ent_file.read_text(encoding='utf-8')
            self.assertNotIn('aps-environment', ent_content)

        # Ensure no firebase references in pubspec or Dart code
        if (PRO_DIR / 'pubspec.yaml').is_file():
            self.assertNotIn('firebase', (PRO_DIR / 'pubspec.yaml').read_text(encoding='utf-8').lower())

        dart_files = list((PRO_DIR / 'lib').glob('**/*.dart'))
        for dart_file in dart_files:
            content = dart_file.read_text(encoding='utf-8')
            self.assertNotIn('firebase_core', content)
            self.assertNotIn('firebase_messaging', content)

    def test_ci_workflow_includes_pro(self):
        ci_yaml = (ROOT / '.github' / 'workflows' / 'ci.yml').read_text(encoding='utf-8')
        self.assertIn('- apps/swansport_pro', ci_yaml)
        self.assertIn('swansport_pro', ci_yaml)

    def test_build_pro_preview_workflow_contract(self):
        preview_workflow = ROOT / '.github' / 'workflows' / 'build_pro_preview.yml'
        self.assertTrue(preview_workflow.is_file(), "build_pro_preview.yml must exist")
        content = preview_workflow.read_text(encoding='utf-8')

        self.assertIn('workflow_dispatch:', content)
        self.assertIn('environment: staging', content)
        self.assertIn('apps/swansport_pro', content)
        self.assertIn('python tools/staging_target.py', content)
        self.assertIn('SwanSport-Pro', content)
        self.assertIn('verify_ios_preview_bundle.py', content)
        self.assertIn('--firebase-enabled false', content)
        self.assertNotIn('aps-environment', content)


if __name__ == '__main__':
    unittest.main()
