import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_router.dart';
import 'package:swansport_pro/features/operations/pro_guardian_links_screen.dart';

void main() {
  test('guardian links route is registered', () {
    expect(ProRoutes.registeredPatterns, contains(ProRoutes.guardianLinks));
  });

  testWidgets('club admin sees masked links and real pending invite count',
      (tester) async {
    final overview = ClubGuardianLinkOverview(
      athletes: const [
        ClubGuardianAthlete(
          id: 'athlete',
          displayName: 'A. Y.',
          isMinor: true,
          status: 'active',
          guardianCount: 1,
        ),
      ],
      links: const [
        ClubGuardianLink(
          id: 'link',
          athleteId: 'athlete',
          athleteDisplayName: 'A. Y.',
          guardianLabel: 'Doğrulanmış veli hesabı',
          relationship: 'Anne',
        ),
      ],
      pendingInvites: [
        PendingGuardianInvite(
          id: 'invite',
          athleteId: 'athlete',
          athleteDisplayName: 'A. Y.',
          createdAt: DateTime(2026, 10, 31),
          expiresAt: DateTime(2099, 11, 1),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club',
              name: 'Kulüp',
              role: 'club_admin',
            ),
          ),
          clubGuardianLinkOverviewProvider.overrideWith(
            (ref) async => overview,
          ),
        ],
        child: const MaterialApp(home: ProGuardianLinksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A. Y.'), findsOneWidget);
    expect(find.textContaining('Doğrulanmış veli hesabı'), findsOneWidget);
    expect(find.textContaining('telefon'), findsNothing);

    await tester.tap(find.text('Bekleyen Davetler'));
    await tester.pumpAndSettle();
    expect(find.text('A. Y.'), findsOneWidget);
    expect(find.byTooltip('Daveti iptal et'), findsOneWidget);
  });

  testWidgets('coach fails closed before constructing guardian data',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club',
              name: 'Kulüp',
              role: 'coach',
            ),
          ),
        ],
        child: const MaterialApp(home: ProGuardianLinksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('kulüp yöneticisi'), findsWidgets);
    expect(find.text('Bağlı Hesaplar'), findsNothing);
  });
}
