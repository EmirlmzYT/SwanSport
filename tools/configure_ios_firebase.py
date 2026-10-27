"""CI-only config materialization; never prints Firebase configuration values."""
import base64
import os
import plistlib
import re
from pathlib import Path


def validate_config(encoded: str, bundle_id: str = 'com.swansport.app', project_id: str = 'swanspor') -> bytes:
    if not encoded:
        raise ValueError('GOOGLESERVICE_INFO_PLIST_BASE64 secret eksik; iOS Firebase yapılandırması gerekli.')
    try:
        raw = base64.b64decode(''.join(encoded.split()), validate=True)
        config = plistlib.loads(raw)
    except Exception:
        raise ValueError('iOS Firebase config base64/plist biçimi geçersiz.') from None
    if not isinstance(config, dict) or config.get('BUNDLE_ID') != bundle_id:
        raise ValueError('Firebase BUNDLE_ID iOS hedefi ile uyuşmuyor.')
    if config.get('PROJECT_ID') != project_id:
        raise ValueError('Firebase PROJECT_ID beklenen SwanSport projesi ile uyuşmuyor.')
    if not all(isinstance(config.get(k), str) and config[k] for k in ('GOOGLE_APP_ID', 'GCM_SENDER_ID', 'API_KEY')):
        raise ValueError('Firebase iOS config zorunlu alanları eksik.')
    if not re.fullmatch(r'AIza[\w-]{35}', config['API_KEY']):
        raise ValueError('Firebase API_KEY biçimi geçersiz; yer tutucu kabul edilmez.')
    if not re.fullmatch(r'1:[0-9]+:ios:[0-9a-f]+', config['GOOGLE_APP_ID']):
        raise ValueError('Firebase GOOGLE_APP_ID biçimi geçersiz.')
    if not config['GCM_SENDER_ID'].isdigit():
        raise ValueError('Firebase GCM_SENDER_ID biçimi geçersiz.')
    return raw


def generate_disabled_plist(bundle_id: str = 'com.swansport.app') -> bytes:
    # Xcode's resource reference needs a file at build time. This is NOT a
    # Firebase config and must be removed from the final preview app bundle.
    return plistlib.dumps({'BUNDLE_ID': bundle_id, 'SWAN_FIREBASE_DISABLED': True})


if __name__ == '__main__':
    target_app = os.environ.get('TARGET_APP', 'swansport_app').strip()
    is_pro = target_app == 'pro' or os.environ.get('IOS_BUNDLE_ID') == 'com.swansport.pro'
    secret_key = 'PRO_IOS_GOOGLE_SERVICE_INFO_BASE64' if is_pro else 'GOOGLESERVICE_INFO_PLIST_BASE64'
    default_bundle = 'com.swansport.pro' if is_pro else 'com.swansport.app'
    bundle_id = os.environ.get('IOS_BUNDLE_ID', default_bundle)
    app_folder = 'apps/swansport_pro' if is_pro else 'apps/swansport_app'
    encoded = os.environ.get(secret_key, '') or ('' if is_pro else os.environ.get('GOOGLESERVICE_INFO_PLIST_BASE64', ''))
    target = Path(__file__).resolve().parent.parent / app_folder / 'ios/Runner/GoogleService-Info.plist'

    if not encoded.strip():
        if os.environ.get('REQUIRE_IOS_FIREBASE_CONFIG') == 'true':
            raise SystemExit(f'İmzalı iOS derlemesi için {secret_key} secret gerekli.')
        print('[UYARI] iOS Firebase config yok; önizlemede push kapalı, sahte anahtar üretilmez.')
        target.write_bytes(generate_disabled_plist(bundle_id))
        enabled = False
    else:
        try:
            data = validate_config(encoded, bundle_id)
            target.write_bytes(data)
            enabled = True
            print('iOS Firebase config doğrulandı ve CI derleme kaynağına yerleştirildi.')
        except ValueError as error:
            raise SystemExit(str(error)) from None
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as output:
            output.write(f'IOS_FIREBASE_ENABLED={str(enabled).lower()}\n')
