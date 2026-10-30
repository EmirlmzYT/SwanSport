import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_theme.dart';
import 'package:swansport_pro/features/auth/pro_login_screen.dart';
import 'package:swansport_pro/widgets/pro_ui_components.dart';

class _FakeSessionService implements AccountSessionService {
  @override
  Future<void> signIn(
      {required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  group('SwanSport Pro Etkileşim, Odak ve Görsel Kalite Sözleşmeleri', () {
    test(
        'ProTheme.dark() odak, hover ve buton dokunma boyutlarını garanti eder',
        () {
      final theme = ProTheme.dark();

      expect(
          theme.focusColor, equals(ProTheme.primary.withValues(alpha: 0.16)));
      expect(
          theme.hoverColor, equals(ProTheme.primary.withValues(alpha: 0.08)));

      final filledStyle = theme.filledButtonTheme.style;
      expect(filledStyle, isNotNull);
      expect(
        filledStyle!.minimumSize?.resolve({}),
        equals(const Size(48, 50)),
      );

      final outlinedStyle = theme.outlinedButtonTheme.style;
      expect(outlinedStyle, isNotNull);
      expect(
        outlinedStyle!.minimumSize?.resolve({}),
        equals(const Size(48, 48)),
      );

      final textButtonStyle = theme.textButtonTheme.style;
      expect(textButtonStyle, isNotNull);
      expect(
        textButtonStyle!.minimumSize?.resolve({}),
        equals(const Size(48, 48)),
      );
    });

    testWidgets(
        'ProFilterBar 48x48 dokunma alanı ve erişilebilir semantik sunar',
        (tester) async {
      String selected = 'Tümü';
      final filters = ['Tümü', 'Bekleyen', 'Tamamlanan'];

      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ProFilterBar(
                filters: filters,
                selected: selected,
                onChanged: (val) => setState(() => selected = val),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final filter in filters) {
        final chipFinder = find.widgetWithText(InkWell, filter);
        expect(chipFinder, findsOneWidget);
        final size = tester.getSize(chipFinder);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }

      await tester.tap(find.text('Bekleyen'));
      await tester.pumpAndSettle();
      expect(selected, equals('Bekleyen'));
    });

    testWidgets(
        'ProStatusBadge tüm tonlarda semantik etiket ve belirgin ikon sunar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                ProStatusBadge(label: 'Acil Görev', tone: ProStatusTone.urgent),
                ProStatusBadge(
                    label: 'Onay Bekliyor', tone: ProStatusTone.pending),
                ProStatusBadge(
                    label: 'Planlandı', tone: ProStatusTone.scheduled),
                ProStatusBadge(
                    label: 'Tamamlandı', tone: ProStatusTone.completed),
                ProStatusBadge(
                    label: 'Bilgilendirme', tone: ProStatusTone.info),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acil Görev'), findsOneWidget);
      expect(find.text('Onay Bekliyor'), findsOneWidget);
      expect(find.text('Planlandı'), findsOneWidget);
      expect(find.text('Tamamlandı'), findsOneWidget);
      expect(find.text('Bilgilendirme'), findsOneWidget);
    });

    testWidgets(
        'ProLoginScreen klavye odaklanması ve form dolaşımını destekler',
        (tester) async {
      final fake = _FakeSessionService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(fake),
          ],
          child: MaterialApp(
            theme: ProTheme.dark(),
            home: const ProLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextField, 'E-posta');
      expect(emailField, findsOneWidget);

      await tester.tap(emailField);
      await tester.pumpAndSettle();

      await tester.enterText(emailField, 'operasyon@swansport.app');
      await tester.pumpAndSettle();
      expect(find.text('operasyon@swansport.app'), findsOneWidget);

      final passwordField = find.widgetWithText(TextField, 'Şifre');
      await tester.tap(passwordField);
      await tester.pumpAndSettle();
      await tester.enterText(passwordField, 'ProSifre2026!');
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(FilledButton, 'Giriş Yap');
      expect(submitBtn, findsOneWidget);
    });

    testWidgets(
        'showProDangerDialog geri alınamaz operasyonlar için tehlike teyidi sunar',
        (tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await showProDangerDialog(
                    context: context,
                    title: 'Geri Alınamaz İşlem',
                    message: 'Bu kaydı silmek istediğinize emin misiniz?',
                    confirmLabel: 'Evet, Sil',
                  );
                  if (result) confirmed = true;
                },
                child: const Text('İşlemi Başlat'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('İşlemi Başlat'));
      await tester.pumpAndSettle();

      expect(find.text('Geri Alınamaz İşlem'), findsOneWidget);
      expect(find.text('Bu kaydı silmek istediğinize emin misiniz?'),
          findsOneWidget);

      final cancelBtn = find.text('Vazgeç');
      expect(cancelBtn, findsOneWidget);

      final confirmBtn = find.text('Evet, Sil');
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });
  });
}
