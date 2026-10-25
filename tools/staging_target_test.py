import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'tools/staging_target.py'
STAGING_REF = 'abcdefghijklmnopqrst'


class StagingTargetTest(unittest.TestCase):
    def run_validator(self, **values):
        env = os.environ.copy()
        env.update(values)
        return subprocess.run(
            [sys.executable, str(SCRIPT)],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_accepts_matching_non_production_project(self):
        result = self.run_validator(
            STAGING_SUPABASE_URL=f'https://{STAGING_REF}.supabase.co',
            STAGING_SUPABASE_ANON_KEY='sb_publishable_test_value',
            STAGING_PROJECT_ID=STAGING_REF,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), f'staging target ok: {STAGING_REF}')

    def test_rejects_production_project(self):
        production = 'gokkimnokigqxmbppvle'
        result = self.run_validator(
            STAGING_SUPABASE_URL=f'https://{production}.supabase.co',
            STAGING_SUPABASE_ANON_KEY='sb_publishable_hidden',
            STAGING_PROJECT_ID=production,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('production project', result.stderr)
        self.assertNotIn('sb_publishable_hidden', result.stderr)

    def test_rejects_missing_malformed_or_mismatched_target(self):
        cases = (
            {},
            {
                'STAGING_SUPABASE_URL': 'http://example.test',
                'STAGING_SUPABASE_ANON_KEY': 'hidden',
                'STAGING_PROJECT_ID': STAGING_REF,
            },
            {
                'STAGING_SUPABASE_URL': f'https://{STAGING_REF}.supabase.co',
                'STAGING_SUPABASE_ANON_KEY': 'hidden',
                'STAGING_PROJECT_ID': 'zyxwvutsrqponmlkjihg',
            },
        )
        for values in cases:
            with self.subTest(values=values):
                result = self.run_validator(**values)
                self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
