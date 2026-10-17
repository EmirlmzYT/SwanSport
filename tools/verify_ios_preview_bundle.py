"""Fail packaging if an iOS preview can auto-configure invalid Firebase."""
import argparse
import base64
from pathlib import Path
import plistlib

from configure_ios_firebase import validate_config


def verify_bundle(bundle: Path, firebase_enabled: bool) -> None:
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    if not (bundle / info['CFBundleExecutable']).is_file():
        raise ValueError('iOS executable missing')
    config = bundle / 'GoogleService-Info.plist'
    if firebase_enabled:
        validate_config(base64.b64encode(config.read_bytes()).decode(),
                        info['CFBundleIdentifier'])
    elif config.exists():
        raise ValueError('Firebase-disabled preview must not bundle GoogleService-Info.plist')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('bundle', type=Path)
    parser.add_argument('--firebase-enabled', choices=['true', 'false'], required=True)
    args = parser.parse_args()
    verify_bundle(args.bundle, args.firebase_enabled == 'true')
    print('iOS bundle Firebase startup contract verified.')
