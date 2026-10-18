import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/bootstrap/startup_failure_app.dart';
import 'package:swansport_app/app/bootstrap/bootstrap.dart';
import 'package:swansport_app/app/config/app_environment.dart';
import 'package:swansport_core/swansport_core.dart';

void main() {
  testWidgets(
    'production entrypoint reports missing Supabase configuration',
    (tester) async {
      await bootstrap(const AppEnvironment.production(), supabaseConfig: SupabaseConfig.empty);
      await tester.pump();

      expect(find.byType(StartupFailureApp), findsOneWidget);
    },
  );
}
