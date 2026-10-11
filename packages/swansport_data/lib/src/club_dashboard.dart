import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'access.dart';
import 'club_data.dart';
import 'supabase_athletes.dart';

class ClubRosterCounts {
  const ClubRosterCounts({required this.total, required this.active});
  final int total;
  final int active;
}

/// Independent of the console table's search, page and status filters.
final clubRosterCountsProvider = FutureProvider.autoDispose<ClubRosterCounts?>((ref) async {
  if (!ref.watch(swanAccessProvider).isClubStaff) return null;
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return null;
  final service = ref.watch(athleteServiceProvider);
  final counts = await Future.wait([
    service.countAthletes(club.id),
    service.countAthletes(club.id, status: 'active'),
  ]);
  return ClubRosterCounts(total: counts[0], active: counts[1]);
});

class ClubTodayAttendance {
  const ClubTodayAttendance({required this.trainingCount, required this.markedCount});
  final int trainingCount;
  /// Events with at least one saved mark, not necessarily complete rosters.
  final int markedCount;
}

final clubDashboardDayProvider = Provider.autoDispose<DateTime>((ref) {
  final turkey = DateTime.now().toUtc().add(const Duration(hours: 3));
  final start = DateTime.utc(turkey.year, turkey.month, turkey.day)
      .subtract(const Duration(hours: 3));
  final timer = Timer(start.add(const Duration(days: 1)).difference(DateTime.now().toUtc()), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return start;
});

final clubTodayAttendanceProvider = FutureProvider.autoDispose<ClubTodayAttendance?>((ref) async {
  if (!ref.watch(swanAccessProvider).isClubStaff) return null;
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return null;
  final start = ref.watch(clubDashboardDayProvider);
  final end = start.add(const Duration(days: 1));
  final service = ref.watch(clubDataServiceProvider);
  final events = await service.events(club.id, from: start, to: end);
  final training = events.where((e) => e.kind == 'training').toList();
  final marks = await service.attendanceMarksForEvents(club.id, training.map((e) => e.id).toList());
  final marked = marks.map((m) => m.eventId).toSet();
  return ClubTodayAttendance(trainingCount: training.length,
      markedCount: training.where((e) => marked.contains(e.id)).length);
});
