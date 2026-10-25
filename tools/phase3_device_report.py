#!/usr/bin/env python3
"""Validate the privacy-safe Phase 3 physical-device acceptance report."""

import json
import re
import sys
from datetime import datetime
from pathlib import Path

CHECKS = (
    'install_upgrade', 'cold_start', 'auth_role_switch',
    'navigation_deep_links', 'offline_recovery', 'direct_message_badges',
    'accountant_privacy', 'guardian_child_isolation', 'push_foreground',
    'push_background', 'push_terminated',
)
TOP_LEVEL_KEYS = {
    'app_version', 'backend_environment', 'tester_alias', 'observed_at', 'devices',
}
DEVICE_KEYS = {'platform', 'device_alias', 'os_version', 'checks'}
CHECK_KEYS = {'status', 'evidence'}
SAFE_TEXT = re.compile(r'^[A-Za-z0-9._:/#+-]{3,120}$')


def _require_keys(value: dict, expected: set[str], label: str) -> None:
    unknown = set(value) - expected
    missing = expected - set(value)
    if unknown or missing:
        raise ValueError(f'{label} keys invalid; missing={sorted(missing)}, unknown={sorted(unknown)}')


def validate(report: dict) -> int:
    _require_keys(report, TOP_LEVEL_KEYS, 'report')
    if report['backend_environment'] != 'staging':
        raise ValueError('backend_environment must be staging')
    if not SAFE_TEXT.fullmatch(report['app_version']):
        raise ValueError('app_version is invalid')
    if not SAFE_TEXT.fullmatch(report['tester_alias']):
        raise ValueError('tester_alias must be a non-identifying alias')
    datetime.fromisoformat(report['observed_at'])

    devices = report['devices']
    if not isinstance(devices, list) or len(devices) != 2:
        raise ValueError('exactly one Android and one iOS device are required')
    if {device.get('platform') for device in devices} != {'android', 'ios'}:
        raise ValueError('exactly one Android and one iOS device are required')

    passed = 0
    incomplete = []
    for device in devices:
        platform = device.get('platform', 'unknown')
        _require_keys(device, DEVICE_KEYS, f'{platform} device')
        for field in ('device_alias', 'os_version'):
            if not SAFE_TEXT.fullmatch(device[field]):
                raise ValueError(f'{platform} {field} must be privacy-safe text')
        if set(device['checks']) != set(CHECKS):
            raise ValueError(f'{platform} must contain the exact Phase 3 check set')
        for name, check in device['checks'].items():
            _require_keys(check, CHECK_KEYS, f'{platform}.{name}')
            if check['status'] not in {'pass', 'fail', 'blocked', 'pending'}:
                raise ValueError(f'{platform}.{name} has an invalid status')
            if not SAFE_TEXT.fullmatch(check['evidence']):
                raise ValueError(f'{platform}.{name} evidence must be a safe artifact/run id')
            if check['status'] == 'pass':
                passed += 1
            else:
                incomplete.append(f'{platform}.{name}={check["status"]}')
    if incomplete:
        raise ValueError('acceptance incomplete: ' + ', '.join(incomplete))
    return passed


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print('usage: phase3_device_report.py <report.json>', file=sys.stderr)
        return 2
    try:
        report = json.loads(Path(argv[1]).read_text(encoding='utf-8'))
        passed = validate(report)
    except (OSError, json.JSONDecodeError, TypeError, ValueError) as error:
        print(f'Phase 3 device report rejected: {error}', file=sys.stderr)
        return 2
    print(f'Phase 3 physical acceptance complete: {passed}/{len(CHECKS) * 2} checks passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
