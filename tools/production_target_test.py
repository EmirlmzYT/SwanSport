import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'tools/production_target.py'
PRODUCTION_REF = 'gokkimnokigqxmbppvle'
STAGING_REF = 'hsfobmghsbtegiiqphpc'


class ProductionTargetTest(unittest.TestCase):
    def run_validator(self, **values):
        env = os.environ.copy()
        env.pop('SUPABASE_URL', None)
        env.pop('SUPABASE_ANON_KEY', None)
        env.update(values)
        return subprocess.run(
            [sys.executable, str(SCRIPT)],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_accepts_only_the_known_production_project(self):
        result = self.run_validator(
            SUPABASE_URL=f'https://{PRODUCTION_REF}.supabase.co',
            SUPABASE_ANON_KEY='sb_publishable_test_value',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.strip(),
            f'production target ok: {PRODUCTION_REF}',
        )

    def test_rejects_staging_without_printing_the_key(self):
        result = self.run_validator(
            SUPABASE_URL=f'https://{STAGING_REF}.supabase.co',
            SUPABASE_ANON_KEY='sb_publishable_hidden',
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('production project', result.stderr)
        self.assertNotIn('sb_publishable_hidden', result.stderr)

    def test_rejects_missing_or_malformed_target(self):
        cases = (
            {},
            {
                'SUPABASE_URL': 'http://example.test',
                'SUPABASE_ANON_KEY': 'hidden',
            },
        )
        for values in cases:
            with self.subTest(values=values):
                result = self.run_validator(**values)
                self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
