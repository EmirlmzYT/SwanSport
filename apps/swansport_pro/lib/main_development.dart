import 'package:swansport_core/swansport_core.dart';
import 'app/pro_bootstrap.dart';
import 'app/pro_environment.dart';

void main() {
  bootstrapPro(
    ProEnvironment.fromCompileTime(
      environmentName: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      ),
      enableDebugTools: const String.fromEnvironment(
        'ENABLE_DEBUG_TOOLS',
        defaultValue: 'true',
      ),
    ),
    config: SupabaseConfig.fromCompileTime(),
  );
}
