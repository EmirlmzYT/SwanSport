import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'tools/validate_android_staging_firebase.py'


class AndroidStagingFirebaseTest(unittest.TestCase):
    def validate(self, project_id='swansport-staging', package='com.swansport.app'):
        config = {
            'project_info': {'project_id': project_id},
            'client': [{'client_info': {'android_client_info': {'package_name': package}}}],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'google-services.json'
            path.write_text(json.dumps(config), encoding='utf-8')
            return subprocess.run(
                [sys.executable, str(SCRIPT), str(path)], text=True,
                capture_output=True, check=False,
            )

    def test_accepts_separate_staging_project_for_app_package(self):
        result = self.validate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'Android staging Firebase config ok')

    def test_rejects_production_project_or_wrong_package(self):
        self.assertNotEqual(self.validate(project_id='swanspor').returncode, 0)
        self.assertNotEqual(self.validate(package='com.example.other').returncode, 0)


if __name__ == '__main__':
    unittest.main()
