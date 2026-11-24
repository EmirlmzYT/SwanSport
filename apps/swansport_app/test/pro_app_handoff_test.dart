import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/pro_operations/swan_pro_handoff.dart';

void main() {
  group('SwanSport App → Pro handoff', () {
    test('builds the dedicated Pro URI without sharing the social scheme', () {
      expect(
        swanSportProUri('/operasyon/kulup-yonetimi').toString(),
        'swansportpro://app/operasyon/kulup-yonetimi',
      );
      expect(
        swanSportProUri('panel?workspace=club').toString(),
        'swansportpro://app/panel?workspace=club',
      );
    });

    testWidgets('card launches the requested Pro operation', (tester) async {
      Uri? launchedUri;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwanProHandoffCard(
              route: '/operasyon/kulup-yonetimi',
              title: 'Detaylı kulüp operasyonları',
              subtitle: 'Profesyonel çalışma alanında yönet.',
              launcher: (uri) async {
                launchedUri = uri;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SwanProHandoffCard));
      await tester.pump();

      expect(
        launchedUri.toString(),
        'swansportpro://app/operasyon/kulup-yonetimi',
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('failed handoff explains that Pro must be installed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwanProHandoffCard(
              route: '/panel',
              title: 'SwanSport Pro',
              subtitle: 'Profesyonel çalışma alanı.',
              launcher: (_) async => false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SwanProHandoffCard));
      await tester.pump();

      expect(
        find.text(
          'SwanSport Pro açılamadı. Uygulamanın bu cihazda yüklü olduğundan emin ol.',
        ),
        findsOneWidget,
      );
    });

    test('native clients register and query the isolated Pro scheme', () {
      final proAndroid = File(
        '../swansport_pro/android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final appAndroid =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final proIos =
          File('../swansport_pro/ios/Runner/Info.plist').readAsStringSync();
      final appIos = File('ios/Runner/Info.plist').readAsStringSync();

      expect(proAndroid, contains('android:scheme="swansportpro"'));
      expect(proAndroid, contains('android:host="app"'));
      expect(
        proAndroid,
        contains('android:name="flutter_deeplinking_enabled"'),
      );
      expect(proAndroid, contains('android:value="true"'));
      expect(appAndroid, contains('android:scheme="swansportpro"'));
      expect(proIos, contains('<string>swansportpro</string>'));
      expect(proIos, contains('<key>FlutterDeepLinkingEnabled</key>'));
      expect(appIos, contains('<string>swansportpro</string>'));
    });
  });
}
