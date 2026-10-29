import importlib.util
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('release_matrix', Path(__file__).with_name('release_matrix.py'))


class ReleaseMatrixTest(unittest.TestCase):
    def load(self):
        module = importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(module)
        return module

    def test_source_inventory_does_not_invent_deployed_or_device_acceptance(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'apps/swansport_app').mkdir(parents=True)
            (root / 'apps/swansport_app/pubspec.yaml').write_text('version: 1.0.4+61\n')
            (root / 'supabase/migrations').mkdir(parents=True)
            (root / 'supabase/migrations/0001_first.sql').write_text('select 1;')
            result = module.source_matrix(root, git_info={'commit': 'fixture', 'dirty': True})
            self.assertEqual(result['application_version'], '1.0.4+61')
            self.assertEqual(result['migrations'][0]['file'], '0001_first.sql')
            self.assertEqual(len(result['migrations'][0]['sha256']), 64)
            self.assertIsNone(result['production']['current_migration'])
            self.assertEqual(result['acceptance']['physical_device'], 'not_verified')
            self.assertEqual(result['git'], {'commit': 'fixture', 'dirty': True})

    def test_migration_content_change_is_detectable_without_a_rename(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'apps/swansport_app').mkdir(parents=True)
            (root / 'apps/swansport_app/pubspec.yaml').write_text('version: 1.2.3+4\n')
            (root / 'supabase/migrations').mkdir(parents=True)
            sql = root / 'supabase/migrations/0001_first.sql'
            sql.write_text('select 1;')
            first = module.source_matrix(root, git_info={})
            sql.write_text('select 2;')
            second = module.source_matrix(root, git_info={})
            self.assertNotEqual(first['migrations'], second['migrations'])


if __name__ == '__main__':
    unittest.main()
