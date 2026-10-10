import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/calendar/presentation/screens/schedule_calendar_screen.dart';
import 'package:swansport_app/features/calendar/presentation/widgets/unified_calendar_widgets.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

FederationActivity official(DateTime day) => FederationActivity.fromMap({
      'id': 'official',
      'program_id': 'official',
      'is_match': false,
      'federation_name': 'Tenis Federasyonu',
      'office_name': 'İstanbul Temsilciliği',
      'season_id': 'season',
      'season_label': '2026 Faaliyet Yılı',
      'sport_code': 'tenis',
      'city_code': '34',
      'title': 'U16 Türkiye Şampiyonası',
      'kind': 'tournament',
      'category': 'U16',
      'location': 'Merkez Kort',
      'status': 'open',
      'starts_at': calendarDayStart(day).toIso8601String(),
      'ends_at':
          calendarDayStart(day.add(const Duration(days: 2))).toIso8601String(),
      'all_day': true,
    });
void main() {
  final today = calendarTurkeyTime(DateTime.now());
  final activity = official(today);
  final training = UnifiedCalendarEvent.club({
    'id': 'session',
    'club_id': 'club',
    'title': 'Kulüp Teknik Antrenmanı',
    'kind': 'training',
    'status': 'completed',
    'starts_at':
        calendarDayStart(today).add(const Duration(hours: 10)).toIso8601String()
  });
  Widget host({bool guest = false, bool failPublic = false}) => ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(guest
                ? SwanAccess.none
                : const SwanAccess(
                    isPlatformAdmin: false,
                    clubRole: 'athlete',
                    coachLevel: 0,
                    athleteKind: null)),
            activeClubProvider.overrideWith((ref) async => null),
            unifiedCalendarMonthProvider.overrideWith((ref, month) async =>
                UnifiedCalendarData(
                    mergeCalendarEvents(
                        failPublic ? [] : [activity], guest ? [] : [training]),
                    officialUnavailable: failPublic)),
          ],
          child: MaterialApp(
              theme: SwanTheme.light(), home: const ScheduleCalendarScreen()));
  Future<void> load(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'unified calendar displays official badge, club session and both day markers',
      (tester) async {
    await load(tester, host());
    expect(find.text('Birleşik Takvim'), findsOneWidget);
    expect(find.text('Resmi Faaliyet / Şampiyona'), findsOneWidget);
    expect(find.text('Kulüp Teknik Antrenmanı'), findsOneWidget);
    expect(find.byKey(ValueKey('calendar-dot-${today.day}-officialFederation')),
        findsOneWidget);
    expect(find.byKey(ValueKey('calendar-dot-${today.day}-clubTraining')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('three filters select correct source and Tümü restores both',
      (tester) async {
    await load(tester, host());
    await tester.tap(find.text('Kulüp Antrenmanları'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficialActivityCard), findsNothing);
    expect(find.text('Kulüp Teknik Antrenmanı'), findsOneWidget);
    await tester.ensureVisible(find.text('Resmi Federasyon Faaliyetleri'));
    await tester.tap(find.text('Resmi Federasyon Faaliyetleri'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficialActivityCard), findsOneWidget);
    expect(find.byType(CalendarSessionCard), findsNothing);
    await tester.ensureVisible(find.text('Tümü'));
    await tester.tap(find.text('Tümü'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarSessionCard), findsOneWidget);
  });
  testWidgets(
      'guest official activity details are read-only and show place, dates, category and status',
      (tester) async {
    await load(tester, host(guest: true));
    expect(find.byType(CalendarSessionCard), findsNothing);
    final card = find.byType(OfficialActivityCard);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Yer: Merkez Kort'), findsOneWidget);
    expect(find.text('Kategori: U16'), findsOneWidget);
    expect(find.text('Durum: Planlandı'), findsOneWidget);
    expect(find.text('Faaliyet yılı: 2026 Faaliyet Yılı'), findsOneWidget);
    expect(find.textContaining('Tarih:'), findsOneWidget);
    expect(find.text('Etkinlik Ekle'), findsNothing);
    expect(find.text('Katılacağım'), findsNothing);
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('Kategori: U16'), findsNothing);
  });
  testWidgets('source failure is visible while available club entries remain',
      (tester) async {
    await load(tester, host(failPublic: true));
    expect(find.text('Resmi faaliyetler yüklenemedi. Yeniden dene'),
        findsOneWidget);
    expect(find.text('Kulüp Teknik Antrenmanı'), findsOneWidget);
  });
  testWidgets('selecting another day filters the chronological list',
      (tester) async {
    await load(tester, host());
    final days = DateTime(today.year, today.month + 1, 0).day;
    final different = today.day == days ? today.day - 1 : today.day + 1;
    await tester.tap(find.byKey(ValueKey('calendar-day-$different')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarSessionCard), findsNothing);
    await tester.tap(find.byKey(ValueKey('calendar-day-${today.day}')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarSessionCard), findsOneWidget);
  });
  for (final role in ['athlete', 'coach']) {
    testWidgets('existing club match keeps $role actions at mobile width',
        (tester) async {
      final match = UnifiedCalendarEvent.club({
        'id': 'match',
        'event_id': 'match',
        'club_id': 'club',
        'title': 'Kulüp Hazırlık Maçı',
        'kind': 'match',
        'status': 'scheduled',
        'place': 'Kulüp Sahası',
        'starts_at': calendarDayStart(today)
            .add(const Duration(hours: 18))
            .toIso8601String(),
      });
      await load(
          tester,
          ProviderScope(
              overrides: [
                swanAccessProvider.overrideWithValue(SwanAccess(
                    isPlatformAdmin: false,
                    clubRole: role,
                    coachLevel: 0,
                    athleteKind: null)),
                activeClubProvider.overrideWith((ref) async =>
                    ClubRef(id: 'club', name: 'Kulüp', role: role)),
                unifiedCalendarMonthProvider.overrideWith(
                    (ref, month) async => UnifiedCalendarData([match])),
                eventRsvpSummaryProvider.overrideWith((ref, id) async =>
                    const EventRsvpSummary(
                        attending: 3, uncertain: 1, unavailable: 0)),
                myEventRsvpProvider.overrideWith((ref, id) async => null),
              ],
              child: MaterialApp(
                  theme: SwanTheme.light(),
                  home: const ScheduleCalendarScreen())));
      tester.view.physicalSize = const Size(375, 1200);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kulüp Hazırlık Maçı'));
      expect(find.text('Kulüp Hazırlık Maçı'), findsOneWidget);
      if (role == 'athlete') {
        expect(find.text('Katılacağım'), findsOneWidget);
      } else {
        await tester.tap(find.text('Kulüp Hazırlık Maçı'));
        await tester.pumpAndSettle();
        expect(find.text('Maç Sonucu'), findsOneWidget);
        expect(find.text('BIZIM SKOR'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
