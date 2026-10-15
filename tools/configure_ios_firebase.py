"""CI-only config materialization; never prints Firebase configuration values."""
import base64
import os
import plistlib
from pathlib import Path


def validate_config(encoded: str, bundle_id: str = 'com.swansport.app') -> bytes:
    if not encoded:
        raise ValueError('GOOGLESERVICE_INFO_PLIST_BASE64 secret eksik; iOS Firebase yapılandırması gerekli.')
    try:
        raw = base64.b64decode(''.join(encoded.split()), validate=True)
        config = plistlib.loads(raw)
    except Exception:
        raise ValueError('iOS Firebase config base64/plist biçimi geçersiz.') from None
    if not isinstance(config, dict) or config.get('BUNDLE_ID') != bundle_id:
        raise ValueError('Firebase BUNDLE_ID iOS hedefi ile uyuşmuyor.')
    if config.get('PROJECT_ID') != 'swanspor':
        raise ValueError('Firebase PROJECT_ID beklenen SwanSport projesi ile uyuşmuyor.')
    if not all(isinstance(config.get(k), str) and config[k] for k in ('GOOGLE_APP_ID', 'GCM_SENDER_ID', 'API_KEY')):
        raise ValueError('Firebase iOS config zorunlu alanları eksik.')
    return raw


def generate_stub_plist(bundle_id: str = 'com.swansport.app') -> bytes:
    stub = {
        'API_KEY': 'AIzaSyPlaceholderKeyForBuild',
        'GCM_SENDER_ID': '000000000000',
        'PLIST_VERSION': '1',
        'PROJECT_ID': 'swanspor',
        'STORAGE_BUCKET': 'swanspor.appspot.com',
        'IS_ADS_ENABLED': False,
        'IS_ANALYTICS_ENABLED': False,
        'IS_APPINVITE_ENABLED': True,
        'IS_GCM_ENABLED': True,
        'IS_SIGNIN_ENABLED': True,
        'GOOGLE_APP_ID': '1:000000000000:ios:0000000000000000000000',
    }
    return plistlib.dumps(stub)


if __name__ == '__main__':
    encoded = os.environ.get('GOOGLESERVICE_INFO_PLIST_BASE64', '')
    target = Path(__file__).resolve().parent.parent / 'apps/swansport_app/ios/Runner/GoogleService-Info.plist'
    if not encoded.strip():
        print('[UYARI] GOOGLESERVICE_INFO_PLIST_BASE64 secret bulunamadı; unsigned IPA derlemesi için yer tutucu plist üretildi.')
        print('[UYARI] Canlı cihazda push bildirimi almak için GitHub secret olarak GoogleService-Info.plist base64 eklenmelidir.')
        target.write_bytes(generate_stub_plist(os.environ.get('IOS_BUNDLE_ID', 'com.swansport.app')))
    else:
        try:
            data = validate_config(encoded, os.environ.get('IOS_BUNDLE_ID', 'com.swansport.app'))
            target.write_bytes(data)
            print('iOS Firebase config doğrulandı ve CI derleme kaynağına yerleştirildi.')
        except ValueError as error:
            raise SystemExit(str(error)) from None
