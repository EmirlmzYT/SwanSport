import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/demo/demo_role.dart';
import 'package:swansport_app/features/test_center/test_center_screen.dart';
import 'package:swansport_app/features/verification/presentation/admin_review_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets(
    'platform admin keeps the App panel when SwanSport Pro cannot open',
    (tester) async {
      Uri? openedUri;
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveIsPlatformAdminProvider.overrideWithValue(true),
            proManagementLauncherProvider.overrideWithValue((uri) async {
              openedUri = uri;
              return false;
            }),
            platformStatsProvider
                .overrideWith((ref) async => PlatformStats.empty),
            pendingCredentialsProvider.overrideWith((ref) async => const []),
            pendingClubsProvider.overrideWith((ref) async => const []),
            openReportsProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: AdminReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SwanSport Pro’da aç'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('SwanSport Pro’da aç'));
      await tester.pumpAndSettle();

      expect(
        openedUri.toString(),
        'https://swansport.pages.dev/konsol/#/operasyon/platform-profesyonel-inceleme',
      );
      expect(find.text('Platform Yönetimi'), findsOneWidget);
      expect(
        find.text('Pro açılamadı; App’teki çalışan paneli kullanabilirsiniz.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'local Test Center opens the local Pro credential review',
    (tester) async {
      Uri? openedUri;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveIsPlatformAdminProvider.overrideWithValue(true),
            localTestCenterRequestedProvider.overrideWithValue(true),
            proManagementLauncherProvider.overrideWithValue((uri) async {
              openedUri = uri;
              return true;
            }),
            platformStatsProvider
                .overrideWith((ref) async => PlatformStats.empty),
            pendingCredentialsProvider.overrideWith((ref) async => const []),
            pendingClubsProvider.overrideWith((ref) async => const []),
            openReportsProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: AdminReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SwanSport Pro’da aç'));
      await tester.pumpAndSettle();

      expect(
        openedUri.toString(),
        'http://127.0.0.1:55432/#/operasyon/platform-profesyonel-inceleme',
      );
    },
  );

  testWidgets(
    'platform panel renders a pending credential with no person name',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveIsPlatformAdminProvider.overrideWithValue(true),
            platformStatsProvider
                .overrideWith((ref) async => PlatformStats.empty),
            pendingCredentialsProvider.overrideWith(
              (ref) async => const [
                CredentialRow(
                  id: 'credential-without-name',
                  kind: 'identity',
                  status: 'pending',
                ),
              ],
            ),
            pendingClubsProvider.overrideWith((ref) async => const []),
            openReportsProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: AdminReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kişi'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
