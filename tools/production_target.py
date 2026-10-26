#!/usr/bin/env python3
"""Fail-closed validation for the SwanSport production backend."""

import os
import sys
from urllib.parse import urlparse

PRODUCTION_PROJECT_REF = 'gokkimnokigqxmbppvle'


def validate(url: str, anon_key: str) -> str:
    if not url or not anon_key:
        raise ValueError('production URL and publishable key are required')

    parsed = urlparse(url)
    expected_host = f'{PRODUCTION_PROJECT_REF}.supabase.co'
    if (
        parsed.scheme != 'https'
        or parsed.hostname != expected_host
        or parsed.path not in ('', '/')
        or parsed.params
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError('target must be the known production project')

    return PRODUCTION_PROJECT_REF


def main() -> int:
    try:
        project_id = validate(
            os.environ.get('SUPABASE_URL', '').strip(),
            os.environ.get('SUPABASE_ANON_KEY', '').strip(),
        )
    except ValueError as error:
        print(f'production target rejected: {error}', file=sys.stderr)
        return 2

    print(f'production target ok: {project_id}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
