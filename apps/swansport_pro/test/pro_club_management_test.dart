import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_router.dart';
import 'package:swansport_pro/features/operations/pro_club_management_screen.dart';

void main() {
  test('club management route is registered', () {
    expect(
      ProRoutes.registeredPatterns,
      contains(ProRoutes.clubManagement),
    );
  });

  testWidgets('club management exposes applications announcements and docs',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clubPendingApplicationsProvider.overrideWith(
            (ref) async => const <ClubApplicationRow>[],
          ),
          announcementsProvider.overrideWith(
            (ref) async => const <AnnouncementRow>[],
          ),
          clubDocumentsProvider.overrideWith(
            (ref) async => const <DocumentRow>[],
          ),
        ],
        child: const MaterialApp(home: ProClubManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başvurular'), findsOneWidget);
    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Belgeler'), findsOneWidget);
    expect(find.text('Bekleyen başvuru yok'), findsOneWidget);

    await tester.tap(find.text('Duyurular'));
    await tester.pumpAndSettle();
    expect(find.text('Duyuru Oluştur'), findsOneWidget);

    await tester.tap(find.text('Belgeler'));
    await tester.pumpAndSettle();
    expect(find.text('Belge Ekle'), findsOneWidget);
  });
}
