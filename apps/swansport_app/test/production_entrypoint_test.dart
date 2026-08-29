import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/bootstrap/startup_failure_app.dart';
import 'package:swansport_app/main_production.dart' as app;

void main() {
  testWidgets(
    'production entrypoint reports missing Supabase configuration',
    (tester) async {
      app.main();
      await tester.pump();

      expect(find.byType(StartupFailureApp), findsOneWidget);
    },
  );
}
