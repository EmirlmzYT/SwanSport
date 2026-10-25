"""Inventory the current source; never infer production deployment or device UAT."""
import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source_matrix(root: Path, git_info: dict | None = None) -> dict:
    if git_info is None:
        git_info = {
            'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
            'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip()),
        }
    pubspec = (root / 'apps/swansport_app/pubspec.yaml').read_text(encoding='utf-8')
    version = re.search(r'^version:\s*(\S+)', pubspec, re.MULTILINE)
    if version is None:
        raise ValueError('Application version missing')
    migrations = [{'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                  for path in sorted((root / 'supabase/migrations').glob('*.sql'))]
    if not migrations:
        raise ValueError('No migrations found')
    return {
        'schema_version': 1,
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'git': git_info,
        'application_version': version.group(1),
        'migration_count': len(migrations),
        'migrations': migrations,
        'production': {'current_migration': None, 'deployed_commit': None, 'status': 'not_verified'},
        'acceptance': {'real_roles': 'not_verified', 'physical_device': 'not_verified'},
        'note': 'Source inventory only. Attach deployment and acceptance evidence separately.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    serialized = json.dumps(source_matrix(ROOT), ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(serialized, encoding='utf-8')
        print(f'Source inventory written: {args.output}')
    else:
        print(serialized, end='')


if __name__ == '__main__':
    main()
