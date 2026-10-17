import base64
import plistlib
import os
import runpy
import unittest
from unittest.mock import patch
from pathlib import Path
from configure_ios_firebase import generate_stub_plist, validate_config

ROOT = Path(__file__).resolve().parent.parent


class IosPushConfigTest(unittest.TestCase):
    def test_unsigned_stub_retains_bundle_but_is_not_real_push_configuration(self):
        stub = plistlib.loads(generate_stub_plist('com.swansport.fixture'))
        self.assertEqual(stub['BUNDLE_ID'], 'com.swansport.fixture')
        self.assertIn('Placeholder', stub['API_KEY'])

    def test_signed_build_without_real_config_stops_before_materializing(self):
        with patch.dict(os.environ, {'GOOGLESERVICE_INFO_PLIST_BASE64': '',
                                     'REQUIRE_IOS_FIREBASE_CONFIG': 'true'}):
            with patch.object(Path, 'write_bytes') as write:
                with self.assertRaisesRegex(SystemExit, 'secret gerekli'):
                    runpy.run_path(str(ROOT / 'tools/configure_ios_firebase.py'), run_name='__main__')
                write.assert_not_called()

    def test_background_entitlement_and_xcode_bundle_contract(self):
        ios = ROOT / 'apps/swansport_app/ios'
        info = plistlib.loads((ios / 'Runner/Info.plist').read_bytes())
        self.assertEqual(set(info['UIBackgroundModes']), {'fetch', 'remote-notification'})
        self.assertNotEqual(info.get('FirebaseAppDelegateProxyEnabled'), False)
        entitlements = plistlib.loads((ios / 'Runner/Runner.entitlements').read_bytes())
        self.assertEqual(entitlements['aps-environment'], '$(APS_ENVIRONMENT)')
        project = (ios / 'Runner.xcodeproj/project.pbxproj').read_text()
        self.assertEqual(project.count('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'), 3)
        self.assertEqual(project.count('APS_ENVIRONMENT = production;'), 2)
        self.assertEqual(project.count('APS_ENVIRONMENT = development;'), 1)
        self.assertIn('GoogleService-Info.plist in Resources', project)
        self.assertIn('com.apple.Push = {enabled = 1;}', project)

    def test_synthetic_firebase_config_validated_without_logging_or_materializing(self):
        config = {'PROJECT_ID': 'swanspor', 'BUNDLE_ID': 'com.swansport.app',
                  'GOOGLE_APP_ID': 'fixture', 'GCM_SENDER_ID': 'fixture', 'API_KEY': 'fixture'}
        encode = lambda c: base64.b64encode(plistlib.dumps(c)).decode()
        self.assertEqual(plistlib.loads(validate_config(encode(config))), config)
        for wrong in ('', 'not base64', encode({**config, 'PROJECT_ID': 'wrong'}),
                      encode({**config, 'BUNDLE_ID': 'wrong'}), encode({**config, 'API_KEY': ''})):
            with self.assertRaises(ValueError):
                validate_config(wrong)

    def test_ci_configuration_is_before_both_unsigned_and_signed_builds(self):
        workflow = (ROOT / '.github/workflows/build_ios.yml').read_text()
        config_index = workflow.index('python tools/configure_ios_firebase.py')
        self.assertLess(config_index, workflow.index('flutter build ios'))
        self.assertLess(config_index, workflow.index('flutter build ipa'))
        self.assertIn('secrets.GOOGLESERVICE_INFO_PLIST_BASE64', workflow)
        self.assertIn('GoogleService-Info.plist', (ROOT / '.gitignore').read_text())


if __name__ == '__main__':
    unittest.main()
