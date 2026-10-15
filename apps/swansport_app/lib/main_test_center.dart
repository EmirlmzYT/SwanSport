import 'package:swansport_core/swansport_core.dart';

import 'app/bootstrap/bootstrap.dart';
import 'app/config/app_environment.dart';

/// Deliberately does NOT use SupabaseConfig.fromCompileTime's production defaults.
Future<void> main() => bootstrap(
  const AppEnvironment.development(),
  localTestCenter: true,
  supabaseConfig: const SupabaseConfig(
    url: 'http://127.0.0.1:55421',
    anonKey: String.fromEnvironment('LOCAL_TEST_ANON_KEY'),
  ),
);
