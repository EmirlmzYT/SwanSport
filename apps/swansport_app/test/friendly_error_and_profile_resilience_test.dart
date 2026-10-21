import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/premium.dart';

void main() {
  group('friendlyErrorMessage', () {
    test('42501 ve yetki/izin hatalarını Türkçeleştirir', () {
      const pgrst42501 =
          "PostgrestException(message: permission denied for table profiles, code: 42501)";
      expect(
        friendlyErrorMessage(pgrst42501),
        'Bu içeriği görüntülemek için giriş yapmanız veya yetkinizin olması gerekiyor.',
      );

      const rlsViolation =
          "PostgrestException(message: new row violates row-level security policy for table profiles)";
      expect(
        friendlyErrorMessage(rlsViolation),
        'Bu içeriği görüntülemek için giriş yapmanız veya yetkinizin olması gerekiyor.',
      );
    });

    test('Bağlantı ve ağ hatalarını Türkçeleştirir', () {
      const netErr =
          "SocketException: Failed host lookup: 'api.swansport.app' (OS Error: No address associated with hostname)";
      expect(
        friendlyErrorMessage(netErr),
        'İnternet bağlantısı kurulamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
      );

      const clientErr = "ClientException: Connection refused";
      expect(
        friendlyErrorMessage(clientErr),
        'İnternet bağlantısı kurulamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin.',
      );
    });

    test('Zaman aşımı hatalarını Türkçeleştirir', () {
      const timeout = "TimeoutException after 0:00:10.000000: Timed out";
      expect(
        friendlyErrorMessage(timeout),
        'Sunucu yanıt vermedi. Lütfen biraz sonra tekrar deneyin.',
      );
    });

    test('Oturum ve JWT süresi dolumu hatalarını Türkçeleştirir', () {
      const jwtErr = "AuthException(message: JWT expired, statusCode: 401)";
      expect(
        friendlyErrorMessage(jwtErr),
        'Oturum süreniz dolmuş olabilir. Lütfen yeniden giriş yapın.',
      );
    });

    test('404 / Bulunamadı hatalarını Türkçeleştirir', () {
      const notFound =
          "PostgrestException(message: JSON object requested, multiple (or no) rows returned, code: PGRST116)";
      expect(
        friendlyErrorMessage(notFound),
        'Aradığınız kayıt bulunamadı veya kaldırılmış olabilir.',
      );
    });
  });

  group('premiumError widget', () {
    testWidgets('hata mesajını ve Tekrar Dene butonunu gösterir',
        (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => premiumError(
                context,
                "PostgrestException(code: 42501)",
                onRetry: () => retried = true,
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(
          'Bu içeriği görüntülemek için giriş yapmanız veya yetkinizin olması gerekiyor.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tekrar Dene'), findsOneWidget);

      await tester.tap(find.text('Tekrar Dene'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('düz PGRST kodunu teknik ayrıntı olarak göstermez',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => premiumError(context, 'PGRST116'),
            ),
          ),
        ),
      );

      expect(find.text('PGRST116'), findsNothing);
      expect(
        find.text('Aradığınız kayıt bulunamadı veya kaldırılmış olabilir.'),
        findsOneWidget,
      );
    });
  });

  group('Profil sorgusu RLS güvencesi', () {
    test('Hassas sütunlar doğrudan profil sorgularında yer almaz', () {
      final root = Directory.current.path;
      var path =
          '$root/../../packages/swansport_data/lib/src/social_service.dart';
      if (!File(path).existsSync()) {
        path = '$root/../packages/swansport_data/lib/src/social_service.dart';
      }
      if (!File(path).existsSync()) {
        path = '$root/packages/swansport_data/lib/src/social_service.dart';
      }
      final file = File(path).readAsStringSync();

      // phone, height_cm, weight_kg, national_id sütunları doğrudan SELECT edilmemelidir.
      final directSelectBlock = file.substring(
        file.indexOf("Future<SocialProfile?> profile("),
        file.indexOf("if (row == null) return null;"),
      );
      final profileMethod = file.substring(
        file.indexOf("Future<SocialProfile?> profile("),
        file.indexOf("Future<SocialProfile?> clubProfile("),
      );
      final selectedColumns = RegExp(
        r"\.select\(\s*'([^']*)'",
        multiLine: true,
      )
          .allMatches(directSelectBlock)
          .expand((match) => match.group(1)!.split(','))
          .map((column) => column.trim())
          .toSet();

      for (final forbidden in [
        'phone',
        'height_cm',
        'weight_kg',
        'national_id',
      ]) {
        expect(
          selectedColumns.contains(forbidden),
          isFalse,
          reason: '$forbidden sütunu doğrudan profiles sorgusunda bulunamaz!',
        );
      }

      // profile_private_projection yalnız oturumlu (uid != null) çağrılmalıdır.
      expect(
        RegExp(
          r"if \(uid != null\) \{[\s\S]*?'profile_private_projection'",
        ).hasMatch(profileMethod),
        isTrue,
        reason: 'profile_private_projection uid != null ile korunmalıdır!',
      );

      expect(
        profileMethod.contains('catch (_)'),
        isFalse,
        reason: 'Ağ ve sunucu hataları sessizce yutulmamalıdır.',
      );
    });
  });
}
