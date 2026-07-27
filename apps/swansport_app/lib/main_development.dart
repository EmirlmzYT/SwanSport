import 'app/bootstrap/bootstrap.dart';
import 'app/config/app_environment.dart';

void main() {
  bootstrap(
    AppEnvironment.fromCompileTime(
      environmentName: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      ),
      enableDebugTools: const String.fromEnvironment(
        'ENABLE_DEBUG_TOOLS',
        defaultValue: 'true',
      ),
    ),
  );
}
