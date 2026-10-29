import unittest

from validate_android_firebase import validate


class AndroidFirebaseConfigTest(unittest.TestCase):
    def test_accepts_matching_pro_config(self):
        validate(
            {
                'project_info': {'project_id': 'swansport-pro'},
                'client': [
                    {
                        'client_info': {
                            'mobilesdk_app_id': '1:123:android:abcdef',
                            'android_client_info': {
                                'package_name': 'com.swansport.pro',
                            },
                        },
                        'api_key': [{'current_key': 'AIza' + ('a' * 35)}],
                    }
                ],
            },
            'com.swansport.pro',
            'swansport-pro',
        )

    def test_rejects_wrong_package_or_project(self):
        config = {
            'project_info': {'project_id': 'wrong'},
            'client': [],
        }
        with self.assertRaises(ValueError):
            validate(config, 'com.swansport.pro', 'swansport-pro')


if __name__ == '__main__':
    unittest.main()
