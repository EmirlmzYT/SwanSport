#!/usr/bin/env python3
"""Validate an Android Firebase config without printing secret material."""

import argparse
import json
import re
from pathlib import Path


def validate(config: dict, package_name: str, project_id: str) -> None:
    info = config.get('project_info', {})
    if info.get('project_id') != project_id:
        raise ValueError('Firebase project_id does not match the selected target')
    matching_clients = [
        client
        for client in config.get('client', [])
        if client.get('client_info', {})
        .get('android_client_info', {})
        .get('package_name') == package_name
    ]
    if not matching_clients:
        raise ValueError('Firebase config does not contain the Android package')
    client = matching_clients[0]
    app_id = client.get('client_info', {}).get('mobilesdk_app_id', '')
    api_keys = client.get('api_key', [])
    if not re.fullmatch(r'1:[0-9]+:android:[0-9a-f]+', app_id):
        raise ValueError('Firebase Android app id is invalid')
    if not any(
        re.fullmatch(r'AIza[\w-]{35}', item.get('current_key', ''))
        for item in api_keys
        if isinstance(item, dict)
    ):
        raise ValueError('Firebase Android API key is invalid')


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('config', type=Path)
    parser.add_argument('--package', required=True)
    parser.add_argument('--project-id', required=True)
    args = parser.parse_args()
    try:
        config = json.loads(args.config.read_text(encoding='utf-8'))
        validate(config, args.package, args.project_id)
    except (OSError, json.JSONDecodeError, TypeError, ValueError) as error:
        parser.error(str(error))
    print('Android Firebase config ok')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
