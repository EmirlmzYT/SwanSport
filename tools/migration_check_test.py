"""A syntax failure must fail CI, rather than merely print an error."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class MigrationExitStatusTest(unittest.TestCase):
    def test_valid_sql_succeeds_and_invalid_sql_fails(self):
        script = Path(__file__).with_name('check_migrations.py')
        with tempfile.TemporaryDirectory() as folder:
            sql = Path(folder) / 'fixture.sql'
            sql.write_text('select 1;')
            good = subprocess.run([sys.executable, str(script), str(sql)], capture_output=True, text=True)
            self.assertEqual(good.returncode, 0, good.stdout + good.stderr)
            sql.write_text('create table broken (;')
            bad = subprocess.run([sys.executable, str(script), str(sql)], capture_output=True, text=True)
            self.assertNotEqual(bad.returncode, 0)
            self.assertIn('sorunlu dosya: 1', bad.stdout)


if __name__ == '__main__':
    unittest.main()
