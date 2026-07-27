import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/config/app_environment.dart';

void main() {
  group('AppEnvironment', () {
    test('creates the default development environment', () {
      final environment = AppEnvironment.fromCompileTime();

      expect(environment.type, AppEnvironmentType.development);
      expect(environment.label, 'Development environment');
      expect(environment.appName, 'SwanSport');
      expect(environment.enableDebugTools, isTrue);
    });

    test('creates a production environment', () {
      final environment = AppEnvironment.fromCompileTime(
        environmentName: 'production',
      );

      expect(environment.type, AppEnvironmentType.production);
      expect(environment.label, 'Production environment');
      expect(environment.enableDebugTools, isFalse);
    });

    test('supports explicit app name and debug flag values', () {
      final environment = AppEnvironment.fromCompileTime(
        environmentName: 'prod',
        appName: 'SwanSport Admin Preview',
        enableDebugTools: 'true',
      );

      expect(environment.type, AppEnvironmentType.production);
      expect(environment.appName, 'SwanSport Admin Preview');
      expect(environment.enableDebugTools, isTrue);
    });

    test('throws a clear error for invalid APP_ENV', () {
      expect(
        () => AppEnvironment.fromCompileTime(environmentName: 'staging'),
        throwsA(
          isA<AppEnvironmentException>().having(
            (error) => error.message,
            'message',
            'APP_ENV must be either development or production.',
          ),
        ),
      );
    });

    test('throws a clear error for empty APP_NAME', () {
      expect(
        () => AppEnvironment.fromCompileTime(appName: '   '),
        throwsA(
          isA<AppEnvironmentException>().having(
            (error) => error.message,
            'message',
            'APP_NAME cannot be empty.',
          ),
        ),
      );
    });

    test('throws a clear error for invalid ENABLE_DEBUG_TOOLS', () {
      expect(
        () => AppEnvironment.fromCompileTime(enableDebugTools: 'yes'),
        throwsA(
          isA<AppEnvironmentException>().having(
            (error) => error.message,
            'message',
            'ENABLE_DEBUG_TOOLS must be true or false.',
          ),
        ),
      );
    });
  });
}
