import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/widgets/action_gate.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('cleanPostgresMessage', () {
    test('removes PostgrestException wrapper', () {
      const raw =
          'PostgrestException(message: Doğrulanmış kimlik gerekli; hesap bekleme odasında, code: 42501, details: null, hint: null)';
      expect(
        cleanPostgresMessage(raw),
        'Doğrulanmış kimlik gerekli; hesap bekleme odasında',
      );
    });

    test('removes generic Exception prefix', () {
      const raw = 'Exception: Bir hata oluştu';
      expect(cleanPostgresMessage(raw), 'Bir hata oluştu');
    });

    test('leaves clean strings unchanged', () {
      const clean = 'Normal bir kullanıcı mesajı';
      expect(cleanPostgresMessage(clean), clean);
    });
  });

  group('VerificationRequirement.detect', () {
    test('detects identity requirement from postgres message', () {
      const error =
          'PostgrestException(message: Doğrulanmış kimlik gerekli; hesap bekleme odasında, code: 42501)';
      final req = VerificationRequirement.detect(error);
      expect(req, isNotNull);
      expect(req!.targetMode, 2); // 2 = Kimlik
      expect(req.title, 'Doğrulanmış Hesap Gerekli');
      expect(req.actionLabel, 'Kimlik Doğrulamaya Git');
    });

    test('detects coach level requirement from postgres message', () {
      const error =
          'PostgrestException(message: Kulüp kurmak için en az 2. kademe doğrulanmış antrenör olmalısın., code: P0001)';
      final req = VerificationRequirement.detect(error);
      expect(req, isNotNull);
      expect(req!.targetMode, 0); // 0 = Antrenör
      expect(req.title, 'Antrenör Belgesi Gerekli');
      expect(req.actionLabel, 'Antrenör Belgesi Yükle');
    });

    test('detects coach second level from additive requirement', () {
      const error =
          'PostgrestException(message: Geçerli branşlı en az ikinci kademe belge gerekli, code: P0001)';
      final req = VerificationRequirement.detect(error);
      expect(req, isNotNull);
      expect(req!.targetMode, 0); // 0 = Antrenör
    });

    test('detects guardian verification requirement', () {
      const error =
          'PostgrestException(message: Veli için doğrulanmış kimlik ve geçerli davet bağı gerekli, code: P0001)';
      final req = VerificationRequirement.detect(error);
      expect(req, isNotNull);
      expect(req!.targetMode, 2);
      expect(req.title, 'Veli Doğrulaması Gerekli');
    });

    test('returns null for unrelated errors', () {
      const error = 'PostgrestException(message: Kulüp adı zaten kullanılıyor, code: 23505)';
      final req = VerificationRequirement.detect(error);
      expect(req, isNull);
    });
  });

  group('VerificationRequiredBottomSheet', () {
    testWidgets('renders title, description and button', (tester) async {
      const req = VerificationRequirement(
        title: 'Doğrulanmış Hesap Gerekli',
        description:
            'Kulüp kurabilmek için kimlik doğrulamanızı tamamlamanız gerekmektedir.',
        targetMode: 2,
        actionLabel: 'Kimlik Doğrulamaya Git',
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/dogrulama': (ctx) => const Scaffold(body: Text('DogrulamaEkrani')),
          },
          home: const Scaffold(
            body: VerificationRequiredBottomSheet(requirement: req),
          ),
        ),
      );

      expect(find.text('Doğrulanmış Hesap Gerekli'), findsOneWidget);
      expect(
        find.text(
          'Kulüp kurabilmek için kimlik doğrulamanızı tamamlamanız gerekmektedir.',
        ),
        findsOneWidget,
      );
      expect(find.text('Kimlik Doğrulamaya Git'), findsOneWidget);
      expect(find.text('Daha Sonra'), findsOneWidget);

      await tester.tap(find.text('Kimlik Doğrulamaya Git'));
      await tester.pumpAndSettle();

      expect(find.text('DogrulamaEkrani'), findsOneWidget);
    });
  });
}
