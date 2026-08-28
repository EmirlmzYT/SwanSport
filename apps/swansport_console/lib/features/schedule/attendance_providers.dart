import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

/// Izgarada görünen haftanın pazartesisi (yerel saat, gece yarısı).
final attendanceWeekProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day);
});

DateTime _weekEnd(DateTime start) => start.add(const Duration(days: 7));

/// Haftadaki antrenmanlar — ızgaranın sütunları.
final attendanceEventsProvider =
    FutureProvider.autoDispose<List<EventRow>>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  final start = ref.watch(attendanceWeekProvider);

  return ref.watch(clubDataServiceProvider).events(
        club.id,
        from: start,
        to: _weekEnd(start),
      );
});

/// Haftadaki işaretlemeler — `"$eventId/$athleteId"` anahtarıyla.
///
/// Düz liste yerine harita: ızgara her hücrede lineer arama yapmasın.
final attendanceMarksProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const {};
  final start = ref.watch(attendanceWeekProvider);

  final marks = await ref.watch(clubDataServiceProvider).attendanceMarks(
        club.id,
        from: start,
        to: _weekEnd(start),
      );

  return {
    for (final m in marks) '${m.eventId}/${m.athleteId}': m.status,
  };
});

/// Izgaranın satırları — kulübün tüm aktif sporcuları.
///
/// Burada sayfalama yok: yoklama ızgarasının anlamı herkesi bir arada
/// görebilmek. 200 satır tarayıcıda sorun değil, 200 satırı 4 sayfaya bölmek
/// ızgarayı işe yaramaz hale getirirdi.
final attendanceAthletesProvider =
    FutureProvider.autoDispose<List<AthleteRow>>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(athleteServiceProvider).fetchAthletes(
        club.id,
        status: 'active',
      );
});
