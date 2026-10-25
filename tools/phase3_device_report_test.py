import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'tools/phase3_device_report.py'
CHECKS = (
    'install_upgrade', 'cold_start', 'auth_role_switch',
    'navigation_deep_links', 'offline_recovery', 'direct_message_badges',
    'accountant_privacy', 'guardian_child_isolation', 'push_foreground',
    'push_background', 'push_terminated',
)


class Phase3DeviceReportTest(unittest.TestCase):
    def report(self):
        device = lambda platform: {
            'platform': platform,
            'device_alias': f'{platform}-1',
            'os_version': 'test-version',
            'checks': {name: {'status': 'pass', 'evidence': f'{platform}-{name}'} for name in CHECKS},
        }
        return {
            'app_version': '1.0.5+62',
            'backend_environment': 'staging',
            'tester_alias': 'tester-1',
            'observed_at': '2026-10-25T12:00:00+03:00',
            'devices': [device('android'), device('ios')],
        }

    def validate(self, report):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'report.json'
            path.write_text(json.dumps(report), encoding='utf-8')
            return subprocess.run(
                [sys.executable, str(SCRIPT), str(path)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

    def test_accepts_complete_two_platform_report(self):
        result = self.validate(self.report())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('22/22 checks passed', result.stdout)

    def test_rejects_production_backend_blocked_checks_and_free_form_notes(self):
        cases = []
        production = self.report()
        production['backend_environment'] = 'production'
        cases.append(production)
        blocked = self.report()
        blocked['devices'][1]['checks']['push_terminated']['status'] = 'blocked'
        cases.append(blocked)
        notes = self.report()
        notes['notes'] = 'personal data must not be stored here'
        cases.append(notes)
        for report in cases:
            with self.subTest(report=report):
                self.assertNotEqual(self.validate(report).returncode, 0)


if __name__ == '__main__':
    unittest.main()
