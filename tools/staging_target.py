#!/usr/bin/env python3
"""Fail-closed validation for the dedicated SwanSport staging backend."""

import os
import re
import sys
from urllib.parse import urlparse

PRODUCTION_PROJECT_REF = 'gokkimnokigqxmbppvle'
PROJECT_REF = re.compile(r'^[a-z0-9]{20}$')


def validate(url: str, anon_key: str, project_id: str) -> str:
    if not url or not anon_key or not project_id:
        raise ValueError('staging URL, publishable key and project id are required')
    if not PROJECT_REF.fullmatch(project_id):
        raise ValueError('staging project id must be a 20-character Supabase ref')
    parsed = urlparse(url)
    expected_host = f'{project_id}.supabase.co'
    if parsed.scheme != 'https' or parsed.hostname != expected_host or parsed.path not in ('', '/'):
        raise ValueError('staging URL must match https://<project-id>.supabase.co')
    if project_id == PRODUCTION_PROJECT_REF:
        raise ValueError('production project is forbidden in the staging workflow')
    return project_id


def main() -> int:
    try:
        project_id = validate(
            os.environ.get('STAGING_SUPABASE_URL', '').strip(),
            os.environ.get('STAGING_SUPABASE_ANON_KEY', '').strip(),
            os.environ.get('STAGING_PROJECT_ID', '').strip(),
        )
    except ValueError as error:
        print(f'staging target rejected: {error}', file=sys.stderr)
        return 2
    print(f'staging target ok: {project_id}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
