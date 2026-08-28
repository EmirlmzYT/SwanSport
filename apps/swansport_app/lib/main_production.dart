import 'package:swansport_core/swansport_core.dart';

import 'app/bootstrap/bootstrap.dart';
import 'app/config/app_environment.dart';

void main() {
  bootstrap(
    AppEnvironment.fromCompileTime(
      environmentName: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'production',
      ),
      enableDebugTools: const String.fromEnvironment(
        'ENABLE_DEBUG_TOOLS',
        defaultValue: 'false',
      ),
    ),
    supabaseConfig: SupabaseConfig.fromCompileTime(),
  );
}
