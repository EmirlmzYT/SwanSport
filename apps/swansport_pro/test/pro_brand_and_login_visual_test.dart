import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_theme.dart';
import 'package:swansport_pro/features/auth/pro_login_screen.dart';
import 'package:swansport_pro/shell/pro_shell.dart';

class _FakeAccountSessionService implements AccountSessionService {
  @override
  Future<void> signIn(
      {required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  group('SwanSport Pro Marka, Login ve Splash Sözleşmeleri', () {
    testWidgets('ProLoginScreen resmî marka başlığı ve kurumsal destek sunar',
        (tester) async {
      final fake = _FakeAccountSessionService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSupabaseEnabledProvider.overrideWithValue(true),
            accountSessionServiceProvider.overrideWithValue(fake),
          ],
          child: MaterialApp(
            theme: ProTheme.light(),
            home: const ProLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SwanSport Pro'), findsOneWidget);
      expect(find.text('Profesyonel Operasyon Merkezi'), findsOneWidget);
      expect(find.text('Tekrar hoş geldin'), findsOneWidget);
      expect(
        find.text('Kurumsal destek: destek@swansport.app'),
        findsOneWidget,
      );

      // E-posta ve şifre inputları
      expect(find.widgetWithText(TextField, 'E-posta'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Şifre'), findsOneWidget);

      // Giriş butonu
      final submitBtn = find.widgetWithText(FilledButton, 'Giriş Yap');
      expect(submitBtn, findsOneWidget);
      final size = tester.getSize(submitBtn);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('ilk native frame sıfır yükseklikte güvenle yerleşir',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSupabaseEnabledProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: ProTheme.light(),
            home: const Scaffold(
              body: SizedBox(height: 0, child: ProLoginScreen()),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ProBrand hem standart hem kompakt modda marka rozetini doğru çizer',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.light(),
          home: const Scaffold(
            body: Column(
              children: [
                ProBrand(compact: false),
                ProBrand(compact: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SwanSport Pro'), findsNWidgets(2));
      expect(find.byIcon(Icons.sports_rounded), findsNWidgets(2));
    });

    test('Web ve Android splash App açık teması (#F4F7FA) ile aynıdır', () {
      final indexHtml = File('web/index.html');
      expect(indexHtml.existsSync(), isTrue);
      final indexContent = indexHtml.readAsStringSync();
      expect(indexContent, contains('content="#F4F7FA"'));
      expect(indexContent, contains('SwanSport Pro'));

      final manifestJson = File('web/manifest.json');
      expect(manifestJson.existsSync(), isTrue);
      final manifestContent = manifestJson.readAsStringSync();
      expect(manifestContent, contains('"background_color": "#F4F7FA"'));
      expect(manifestContent, contains('"theme_color": "#F4F7FA"'));
      expect(manifestContent, contains('"name": "SwanSport Pro"'));

      final androidColors = File('android/app/src/main/res/values/colors.xml');
      expect(androidColors.existsSync(), isTrue);
      expect(
        androidColors.readAsStringSync(),
        contains('<color name="pro_splash_background">#F4F7FA</color>'),
      );
    });
  });
}
