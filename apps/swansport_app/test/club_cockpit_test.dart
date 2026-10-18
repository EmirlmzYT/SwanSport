import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/clubs/presentation/club_cockpit_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('ClubCockpitScreen renders empty state when no active club',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClubProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: ClubCockpitScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aktif bir kulüp bulunamadı'), findsOneWidget);
  });

  testWidgets(
      'ClubCockpitScreen renders hero card, urgent actions, KPIs and hybrid athlete sheet',
      (tester) async {
    const testClub = ClubRef(
      id: 'club-123',
      name: 'Kadıköy Basketbol SK',
      city: 'İstanbul, Kadıköy',
      role: 'club_admin',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClubProvider.overrideWith((ref) async => testClub),
          clubPendingApplicationsProvider.overrideWith((ref) async => const []),
          clubAthletesProvider.overrideWith(
            (ref) async => const [
              AthleteRow(
                id: 'a1',
                firstName: 'Kerem',
                lastName: 'Yılmaz',
              ),
              AthleteRow(
                id: 'a2',
                firstName: 'Zeynep',
                lastName: 'Kaya',
              ),
            ],
          ),
          pendingPaymentsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: ClubCockpitScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kadıköy Basketbol SK'), findsOneWidget);
    expect(find.text('İstanbul, Kadıköy'), findsOneWidget);
    expect(find.text('GÜNÜN ACİL İŞLERİ'), findsOneWidget);
    expect(find.text('KADRO & SPORCULAR'), findsOneWidget);
    expect(find.text('2 aktif sporcu kaydı'), findsOneWidget);

    // Open Hybrid Add Athlete Sheet
    await tester.tap(
      find.text('Yeni Sporcu / Öğrenci Ekle (QR veya Elle)'),
    );
    await tester.pumpAndSettle();

    expect(find.text('1. Davet Linki / QR'), findsOneWidget);
    expect(find.text('2. Sahada Elle Ekle'), findsOneWidget);
    expect(find.text('WhatsApp ile Gönder'), findsOneWidget);

    // Switch to manual entry tab
    await tester.tap(find.text('2. Sahada Elle Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Sporcuyu Kadroya Kaydet'), findsOneWidget);
  });
}
