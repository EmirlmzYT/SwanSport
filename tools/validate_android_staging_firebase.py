#!/usr/bin/env python3
"""Validate an Android staging Firebase file without printing its contents."""

import json
import sys
from pathlib import Path

PRODUCTION_FIREBASE_PROJECT = 'swanspor'
APP_PACKAGE = 'com.swansport.app'


def validate(config: dict) -> None:
    project_id = config.get('project_info', {}).get('project_id')
    if not isinstance(project_id, str) or not project_id:
        raise ValueError('Firebase project_id missing')
    if project_id == PRODUCTION_FIREBASE_PROJECT:
        raise ValueError('production Firebase project is forbidden for staging')
    packages = {
        client.get('client_info', {}).get('android_client_info', {}).get('package_name')
        for client in config.get('client', [])
        if isinstance(client, dict)
    }
    if APP_PACKAGE not in packages:
        raise ValueError('Firebase config does not contain the SwanSport Android package')


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print('usage: validate_android_staging_firebase.py <google-services.json>', file=sys.stderr)
        return 2
    try:
        config = json.loads(Path(argv[1]).read_text(encoding='utf-8'))
        validate(config)
    except (OSError, json.JSONDecodeError, TypeError, ValueError) as error:
        print(f'Android staging Firebase config rejected: {error}', file=sys.stderr)
        return 2
    print('Android staging Firebase config ok')
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
