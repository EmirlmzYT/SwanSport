import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_router.dart';
import 'package:swansport_pro/features/operations/pro_club_management_screen.dart';

void main() {
  test('club management route is registered', () {
    expect(ProRoutes.registeredPatterns, contains(ProRoutes.clubManagement));
  });

  testWidgets('club management exposes applications announcements and docs', (
    tester,
  ) async {
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
          activeClubProvider.overrideWith((ref) async => null),
          clubIdentityProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: ProClubManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başvurular'), findsOneWidget);
    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Belgeler'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Bekleyen başvuru yok'), findsOneWidget);

    await tester.tap(find.text('Duyurular'));
    await tester.pumpAndSettle();
    expect(find.text('Duyuru Oluştur'), findsOneWidget);

    await tester.tap(find.text('Belgeler'));
    await tester.pumpAndSettle();
    expect(find.text('Belge Ekle'), findsOneWidget);

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('Aktif kulüp bulunamadı'), findsOneWidget);
  });

  testWidgets('club settings keep admin and coach capabilities separate', (
    tester,
  ) async {
    Future<void> pumpFor(ClubRef club) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(club.role),
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
            activeClubProvider.overrideWith((ref) async => club),
            clubIdentityProvider.overrideWith(
              (ref) async => ClubIdentity(id: club.id, name: club.name),
            ),
            clubSeasonsProvider.overrideWith(
              (ref) async => const <SeasonRow>[],
            ),
            clubTrainingSportsProvider(club.id)
                .overrideWith((ref) async => const <String>[]),
            teamsProvider.overrideWith((ref) async => const <TeamRow>[]),
            clubMembersAdminProvider.overrideWith(
              (ref) async => const <ClubMember>[],
            ),
          ],
          child: const MaterialApp(home: ProClubManagementScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
    }

    await pumpFor(const ClubRef(id: 'club', name: 'Kulüp', role: 'club_admin'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-club-settings')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('club-settings-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('save-club-settings')), findsOneWidget);
    expect(find.text('Sınırlı operasyon yetkisi'), findsNothing);

    await pumpFor(const ClubRef(id: 'club', name: 'Kulüp', role: 'coach'));
    expect(find.byKey(const Key('save-club-settings')), findsNothing);
    expect(find.text('Sınırlı operasyon yetkisi'), findsOneWidget);
    expect(find.text('Sezon ekle'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Branşları kaydet'),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('club-settings-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Branşları kaydet'), findsOneWidget);
  });
}
