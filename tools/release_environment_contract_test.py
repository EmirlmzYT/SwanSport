import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRODUCTION_REF = 'gokkimnokigqxmbppvle'


class ReleaseEnvironmentContractTest(unittest.TestCase):
    def test_source_and_release_workflows_have_no_live_backend_fallback(self):
        targets = (
            ROOT / 'packages/swansport_core/lib/config/supabase_config.dart',
            ROOT / '.github/workflows/build_ios.yml',
            ROOT / '.github/workflows/build_console_web.yml',
        )
        for path in targets:
            with self.subTest(path=path):
                self.assertNotIn(PRODUCTION_REF, path.read_text(encoding='utf-8'))

    def test_staging_workflow_is_manual_and_environment_scoped(self):
        workflow = (ROOT / '.github/workflows/staging_acceptance.yml').read_text(encoding='utf-8')
        self.assertIn('workflow_dispatch:', workflow)
        self.assertNotIn("push:\n", workflow)
        self.assertGreaterEqual(workflow.count('environment: staging'), 3)
        self.assertIn('python tools/staging_target.py', workflow)
        self.assertIn('db push --dry-run', workflow)
        self.assertIn("inputs.apply_migrations == true", workflow)
        self.assertIn('STAGING_GOOGLE_SERVICES_JSON_BASE64', workflow)
        self.assertIn('validate_android_staging_firebase.py', workflow)
        self.assertIn('IOS_FIREBASE_ENABLED=false', workflow)


if __name__ == '__main__':
    unittest.main()
