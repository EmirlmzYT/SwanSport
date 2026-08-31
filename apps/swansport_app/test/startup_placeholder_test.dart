import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swansport_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:swansport_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:swansport_app/main_development.dart' as app;

/// Açılış kapısının iki yolu.
///
/// Oturumu olmayan kullanıcı **önce tanıtımı** görür, bir kez. Bu test
/// eskiden doğrudan giriş ekranı bekliyordu; tanıtım eklenince düştü ve
/// düşmesi doğruydu — beklenti güncellendi, davranış değil.
void main() {
  testWidgets('ilk açılışta tanıtım gösterilir', (tester) async {
    SharedPreferences.setMockInitialValues({});

    app.main();
    // Tercih okuması eşzamansız: `pump` tek kare çiziyor, `pumpAndSettle`
    // FutureProvider çözülene kadar bekliyor.
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('tanıtım görülmüşse doğrudan giriş ekranı açılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({kOnboardingSeenKey: true});

    app.main();
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('"Atla" tanıtımı kapatır ve bir daha göstermez', (tester) async {
    SharedPreferences.setMockInitialValues({});

    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    // Bayrak gerçekten yazıldı mı — yazılmazsa tanıtım her açılışta çıkardı.
    expect(await onboardingSeen(), isTrue);
  });

  testWidgets('hızlı iki dokunuş iki sayfa ilerletir', (tester) async {
    SharedPreferences.setMockInitialValues({});

    app.main();
    await tester.pumpAndSettle();

    // Canlida bu senaryo tek sayfa ilerletiyordu: `nextPage` hedefi ucus
    // halindeki kaydirma konumundan hesapliyor ve ikinci dokunus yutuluyor.
    await tester.tap(find.text('Devam'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();

    expect(find.text('Başla'), findsOneWidget,
        reason: 'iki dokunustan sonra son sayfada olmali');
  });
}
