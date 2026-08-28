import 'package:swansport_core/swansport_core.dart';

import 'app/console_bootstrap.dart';

void main() {
  bootstrapConsole(supabaseConfig: SupabaseConfig.fromCompileTime());
}
