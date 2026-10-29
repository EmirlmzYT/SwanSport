import base64
import plistlib
import os
import runpy
import unittest
from unittest.mock import patch
from pathlib import Path
from tempfile import TemporaryDirectory
from configure_ios_firebase import generate_disabled_plist, validate_config
from verify_ios_preview_bundle import verify_bundle
from guard_ios_firebase_registration import guarded_source

ROOT = Path(__file__).resolve().parent.parent


class IosPushConfigTest(unittest.TestCase):
    def test_native_guard_preserves_other_plugins_and_is_idempotent(self):
        source = '''@implementation GeneratedPluginRegistrant
  [FLTFirebaseCorePlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCorePlugin"]];
  [FLTFirebaseMessagingPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseMessagingPlugin"]];
  [SharedPreferencesPlugin registerWithRegistrar:[registry registrarForPlugin:@"SharedPreferencesPlugin"]];
'''
        result = guarded_source(source)
        self.assertEqual(result.count('if (SwanFirebaseConfigured())'), 2)
        self.assertIn('if (path == nil) return NO;', result)
        self.assertIn('  [SharedPreferencesPlugin registerWithRegistrar:', result)
        self.assertEqual(guarded_source(result), result)
        with self.assertRaises(ValueError):
            guarded_source(source.replace('FLTFirebaseMessagingPlugin', 'UnexpectedPlugin'))
        project = (ROOT / 'apps/swansport_app/ios/Runner.xcodeproj/project.pbxproj').read_text()
        self.assertIn('guard_ios_firebase_registration.py', project)

    def test_disabled_resource_cannot_be_used_as_firebase_configuration(self):
        stub = plistlib.loads(generate_disabled_plist('com.swansport.fixture'))
        self.assertEqual(stub['BUNDLE_ID'], 'com.swansport.fixture')
        self.assertTrue(stub['SWAN_FIREBASE_DISABLED'])
        self.assertNotIn('API_KEY', stub)
        self.assertNotIn('GOOGLE_APP_ID', stub)

    def test_final_preview_must_not_contain_any_firebase_plist(self):
        with TemporaryDirectory() as directory:
            bundle = Path(directory)
            (bundle / 'Info.plist').write_bytes(plistlib.dumps({
                'CFBundleExecutable': 'Runner', 'CFBundleIdentifier': 'com.swansport.app'}))
            (bundle / 'Runner').touch()
            verify_bundle(bundle, False)
            config = bundle / 'GoogleService-Info.plist'
            config.write_bytes(generate_disabled_plist())
            with self.assertRaisesRegex(ValueError, 'must not bundle'):
                verify_bundle(bundle, False)
            config.write_bytes(plistlib.dumps({'API_KEY': 'AIzaSyPlaceholderKeyForBuild'}))
            with self.assertRaisesRegex(ValueError, 'must not bundle'):
                verify_bundle(bundle, False)

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
                  'GOOGLE_APP_ID': '1:123456789:ios:abcdef123456',
                  'GCM_SENDER_ID': '123456789', 'API_KEY': 'AIza' + 'x' * 35}
        encode = lambda c: base64.b64encode(plistlib.dumps(c)).decode()
        self.assertEqual(plistlib.loads(validate_config(encode(config))), config)
        for wrong in ('', 'not base64', encode({**config, 'PROJECT_ID': 'wrong'}),
                      encode({**config, 'BUNDLE_ID': 'wrong'}), encode({**config, 'API_KEY': ''}),
                      encode({**config, 'API_KEY': 'AIzaSyPlaceholderKeyForBuild'}),
                      encode({**config, 'GOOGLE_APP_ID': 'fixture'}),
                      encode({**config, 'GCM_SENDER_ID': 'fixture'})):
            with self.assertRaises(ValueError):
                validate_config(wrong)

    def test_pro_ios_firebase_validation(self):
        config = {
            'PROJECT_ID': 'swansport-pro',
            'BUNDLE_ID': 'com.swansport.pro',
            'GOOGLE_APP_ID': '1:987654321:ios:abcdef654321',
            'GCM_SENDER_ID': '987654321',
            'API_KEY': 'AIza' + 'y' * 35,
        }
        encode = lambda c: base64.b64encode(plistlib.dumps(c)).decode()
        self.assertEqual(
            plistlib.loads(
                validate_config(
                    encode(config),
                    bundle_id='com.swansport.pro',
                    project_id='swansport-pro',
                )
            ),
            config,
        )
        with self.assertRaises(ValueError):
            validate_config(
                encode({**config, 'BUNDLE_ID': 'com.swansport.app'}),
                bundle_id='com.swansport.pro',
                project_id='swansport-pro',
            )

    def test_ci_configuration_is_before_both_unsigned_and_signed_builds(self):
        workflow = (ROOT / '.github/workflows/build_ios.yml').read_text()
        config_index = workflow.index('python tools/configure_ios_firebase.py')
        self.assertLess(config_index, workflow.index('flutter build ios'))
        self.assertLess(config_index, workflow.index('flutter build ipa'))
        self.assertIn('secrets.GOOGLESERVICE_INFO_PLIST_BASE64', workflow)
        self.assertIn('GoogleService-Info.plist', (ROOT / '.gitignore').read_text())
        self.assertIn('--dart-define="IOS_FIREBASE_ENABLED=$IOS_FIREBASE_ENABLED"', workflow)
        self.assertLess(workflow.index('rm build/ios/unsigned-payload/Payload/Runner.app/GoogleService-Info.plist'),
                        workflow.index('verify_ios_preview_bundle.py'))
        self.assertLess(workflow.index('verify_ios_preview_bundle.py'), workflow.index('zip -qry'))


if __name__ == '__main__':
    unittest.main()
