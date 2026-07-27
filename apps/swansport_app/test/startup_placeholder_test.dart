import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:swansport_app/main_development.dart' as app;

void main() {
  testWidgets('development entrypoint opens the authentication screen', (
    tester,
  ) async {
    app.main();
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
  });
}
