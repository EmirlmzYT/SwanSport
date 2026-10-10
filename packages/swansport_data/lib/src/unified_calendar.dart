import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access.dart';
import 'club_data.dart';
import 'coach_guardian_results.dart';
import 'supabase_athletes.dart';
import 'supabase_scope.dart';

enum CalendarEventType {
  officialFederation,
  clubTraining,
  clubMatch,
  clubMeeting,
  clubOther;

  // Existing calendar preview fixtures retain their source compatibility.
  static const training = clubTraining;
  static const match = clubMatch;
  static const meeting = clubMeeting;
}

/// UTC instant -> Turkey's calendar fields, independent of device timezone.
DateTime calendarTurkeyTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 3));
DateTime calendarDayStart(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day)
        .subtract(const Duration(hours: 3));

class CalendarMonth {
  const CalendarMonth(
    this.year,
    this.month, {
    this.sportCode,
    this.cityCode,
    this.seasonId,
  });
  final int year, month;
  final String? sportCode, cityCode, seasonId;
  DateTime get from => calendarDayStart(DateTime.utc(year, month));
  DateTime get to => calendarDayStart(DateTime.utc(year, month + 1));
  @override
  bool operator ==(Object other) =>
      other is CalendarMonth &&
      year == other.year &&
      month == other.month &&
      sportCode == other.sportCode &&
      cityCode == other.cityCode &&
      seasonId == other.seasonId;
  @override
  int get hashCode => Object.hash(year, month, sportCode, cityCode, seasonId);
}

typedef FederationActivityFilter = ({
  String? sportCode,
  String? cityCode,
  String? seasonId,
  DateTime? from,
  DateTime? to
});
typedef UnifiedCalendarQuery = ({
  CalendarMonth month,
  DateTime? day,
  CalendarEventType? type,
  String? place
});

String _requiredText(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Takvim $key eksik');
  }
  return value;
}

String? _optionalText(Map<String, dynamic> map, String key) =>
    map[key] is String ? map[key] as String : null;
DateTime _requiredTime(Map<String, dynamic> map, String key) {
  final parsed = DateTime.tryParse(_requiredText(map, key));
  if (parsed == null) throw FormatException('Takvim $key geçersiz');
  return parsed.toUtc();
}

class FederationActivity {
  FederationActivity.fromMap(Map<String, dynamic> map)
      : id = _requiredText(map, 'id'),
        programId = _requiredText(map, 'program_id'),
        title = _requiredText(map, 'title'),
        sportCode = _requiredText(map, 'sport_code'),
        cityCode = _optionalText(map, 'city_code'),
        seasonId = _requiredText(map, 'season_id'),
        seasonLabel = _requiredText(map, 'season_label'),
        federationName = _requiredText(map, 'federation_name'),
        officeName = _requiredText(map, 'office_name'),
        kind = _requiredText(map, 'kind'),
        category = _optionalText(map, 'category'),
        location = _optionalText(map, 'location'),
        status = _requiredText(map, 'status'),
        startsAt = _requiredTime(map, 'starts_at'),
        endsAt = map['ends_at'] == null ? null : _requiredTime(map, 'ends_at'),
        allDay = map['all_day'] == true,
        isMatch = map['is_match'] == true;
  final String id,
      programId,
      title,
      sportCode,
      seasonId,
      seasonLabel,
      federationName,
      officeName,
      kind,
      status;
  final String? cityCode, category, location;
  final DateTime startsAt;

  /// Exclusive end; all-day programs include their final calendar date.
  final DateTime? endsAt;
  final bool allDay, isMatch;
}

class UnifiedCalendarEvent {
  const UnifiedCalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startsAt,
    required this.status,
    this.endsAt,
    this.place,
    this.activity,
    this.clubEvent,
    this.sessionId,
    this.clubId,
    this.guardianResult,
  });
  final String id, title, status;
  final CalendarEventType type;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? place, sessionId, clubId;
  final FederationActivity? activity;
  final EventRow? clubEvent;
  final GuardianCalendarResult? guardianResult;
  bool occursOn(DateTime day) {
    final start = calendarDayStart(day);
    final end = start.add(const Duration(days: 1));
    return startsAt.isBefore(end) &&
        (!startsAt.isBefore(start) ||
            (endsAt != null && endsAt!.isAfter(start)));
  }

  factory UnifiedCalendarEvent.official(FederationActivity a) =>
      UnifiedCalendarEvent(
        id: 'official:${a.isMatch ? 'match' : 'program'}:${a.id}',
        title: a.title,
        type: CalendarEventType.officialFederation,
        startsAt: a.startsAt,
        endsAt: a.endsAt,
        status: a.status,
        place: a.location,
        activity: a,
      );
  factory UnifiedCalendarEvent.club(Map<String, dynamic> row) {
    final eventId = _optionalText(row, 'event_id');
    final sourceId = _requiredText(row, 'id');
    final kind = _requiredText(row, 'kind');
    return UnifiedCalendarEvent(
      id: 'club:${_requiredText(row, 'club_id')}:$sourceId',
      clubId: _requiredText(row, 'club_id'),
      title: _requiredText(row, 'title'),
      type: switch (kind) {
        'training' => CalendarEventType.clubTraining,
        'match' => CalendarEventType.clubMatch,
        'meeting' => CalendarEventType.clubMeeting,
        _ => CalendarEventType.clubOther
      },
      startsAt: _requiredTime(row, 'starts_at'),
      endsAt: row['ends_at'] == null ? null : _requiredTime(row, 'ends_at'),
      status: _requiredText(row, 'status'),
      place: _optionalText(row, 'place'),
      sessionId: _optionalText(row, 'session_id'),
      clubEvent: eventId == null || eventId != sourceId
          ? null
          : EventRow(
              id: eventId,
              title: _requiredText(row, 'title'),
              kind: kind,
              startsAt: _requiredTime(row, 'starts_at'),
              endsAt:
                  row['ends_at'] == null ? null : _requiredTime(row, 'ends_at'),
              place: _optionalText(row, 'place'),
              teamId: _optionalText(row, 'team_id'),
              opponent: _optionalText(row, 'opponent'),
              homeScore:
                  row['home_score'] is int ? row['home_score'] as int : null,
              awayScore:
                  row['away_score'] is int ? row['away_score'] as int : null,
            ),
    );
  }
}

List<UnifiedCalendarEvent> mergeCalendarEvents(
  List<FederationActivity> official,
  List<UnifiedCalendarEvent> club,
) {
  final unique = <String, UnifiedCalendarEvent>{};
  for (final event in [
    ...official.map(UnifiedCalendarEvent.official),
    ...club,
  ]) {
    unique[event.id] = event;
  }
  final entries = unique.values.toList()
    ..sort((a, b) {
      final time = a.startsAt.compareTo(b.startsAt);
      return time != 0 ? time : a.id.compareTo(b.id);
    });
  return List.unmodifiable(entries);
}

List<UnifiedCalendarEvent> filterCalendarEvents(
  List<UnifiedCalendarEvent> entries, {
  DateTime? day,
  CalendarEventType? type,
  String? place,
}) =>
    List.unmodifiable(
      entries.where(
        (e) =>
            (day == null || e.occursOn(day)) &&
            (type == null || e.type == type) &&
            (place == null || e.place == place),
      ),
    );

class UnifiedCalendarService {
  UnifiedCalendarService(this._client);
  final SupabaseClient _client;
  Future<List<FederationActivity>> activities(
    FederationActivityFilter filter,
  ) async {
    String? date(DateTime? value) => value == null
        ? null
        : calendarTurkeyTime(value).toIso8601String().substring(0, 10);
    final rows = await _client.rpc<List<dynamic>>(
      'public_federation_activities',
      params: {
        'p_sport': filter.sportCode,
        'p_city': filter.cityCode,
        'p_season': filter.seasonId,
        'p_from': date(filter.from),
        'p_to': date(filter.to),
      },
    );
    return [
      for (final row in rows)
        FederationActivity.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<List<UnifiedCalendarEvent>> clubEntries(
    CalendarMonth month,
    String? clubId,
  ) async {
    if (_client.auth.currentUser == null) return const [];
    final rows = await _client.rpc<List<dynamic>>(
      'my_calendar_club_entries',
      params: {
        'p_from': month.from.toIso8601String(),
        'p_to': month.to.toIso8601String(),
        'p_club': clubId,
      },
    );
    return [
      for (final row in rows)
        UnifiedCalendarEvent.club(Map<String, dynamic>.from(row as Map)),
    ];
  }
}

final unifiedCalendarServiceProvider = Provider<UnifiedCalendarService>(
  (ref) => UnifiedCalendarService(ref.watch(supabaseClientProvider)),
);
final federationActivitiesProvider = FutureProvider.autoDispose
    .family<List<FederationActivity>, FederationActivityFilter>((ref, filter) {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(unifiedCalendarServiceProvider).activities(filter);
});
final calendarClubEntriesProvider = FutureProvider.autoDispose
    .family<List<UnifiedCalendarEvent>, CalendarMonth>((ref, month) async {
  if (!ref.watch(swanAccessProvider).hasAccount) return const [];
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  ref.watch(authSessionProvider);
  final club = await ref.watch(activeClubProvider.future);
  return ref.watch(unifiedCalendarServiceProvider).clubEntries(month, club?.id);
});

class UnifiedCalendarData {
  const UnifiedCalendarData(
    this.events, {
    this.officialUnavailable = false,
    this.clubUnavailable = false,
  });
  final List<UnifiedCalendarEvent> events;
  final bool officialUnavailable, clubUnavailable;
}

final unifiedCalendarMonthProvider = FutureProvider.autoDispose
    .family<UnifiedCalendarData, CalendarMonth>((ref, month) async {
  final publicFuture = ref.watch(
    federationActivitiesProvider(
      (
        sportCode: month.sportCode,
        cityCode: month.cityCode,
        seasonId: month.seasonId,
        from: month.from,
        to: month.to
      ),
    ).future,
  );
  // Do not even construct private reads for guests, including during sign-out.
  final hasAccount = ref.watch(swanAccessProvider).hasAccount;
  final clubFuture = hasAccount
      ? ref.watch(calendarClubEntriesProvider(month).future)
      : Future.value(const <UnifiedCalendarEvent>[]);
  final guardianFuture = hasAccount && ref.watch(swanAccessProvider).isParent
      ? ref.watch(guardianCalendarResultsProvider(month).future)
      : Future.value(const <GuardianCalendarResult>[]);
  var publicFailed = false, clubFailed = false;
  Future<List<FederationActivity>> official() async {
    try {
      return await publicFuture;
    } catch (_) {
      publicFailed = true;
      return const [];
    }
  }

  Future<List<UnifiedCalendarEvent>> private() async {
    try {
      return await clubFuture;
    } catch (_) {
      clubFailed = true;
      return const [];
    }
  }

  Future<List<UnifiedCalendarEvent>> guardian() async {
    try {
      return [
        for (final row in await guardianFuture)
          UnifiedCalendarEvent(
            id: 'guardian:${row.result.source.matchId}:${row.childId ?? row.notificationId}',
            title: '${row.result.childName} · ${row.result.source.name}',
            type: CalendarEventType.officialFederation,
            startsAt: row.result.source.startsAt!,
            status: 'played',
            place: row.result.source.location,
            guardianResult: row,
          )
      ];
    } catch (_) {
      clubFailed = true;
      return const [];
    }
  }

  // Attach both error handlers before awaiting either source.
  final results =
      await Future.wait<Object>([official(), private(), guardian()]);
  return UnifiedCalendarData(
    mergeCalendarEvents(
      (results[0] as List<FederationActivity>)
          .where((a) =>
              !a.isMatch ||
              !(results[2] as List<UnifiedCalendarEvent>)
                  .any((g) => g.guardianResult!.result.source.matchId == a.id))
          .toList(),
      [
        ...results[1] as List<UnifiedCalendarEvent>,
        ...results[2] as List<UnifiedCalendarEvent>
      ],
    ),
    officialUnavailable: publicFailed,
    clubUnavailable: clubFailed,
  );
});
final unifiedCalendarEventsProvider = FutureProvider.autoDispose
    .family<List<UnifiedCalendarEvent>, UnifiedCalendarQuery>(
        (ref, query) async {
  final data =
      await ref.watch(unifiedCalendarMonthProvider(query.month).future);
  return filterCalendarEvents(
    data.events,
    day: query.day,
    type: query.type,
    place: query.place,
  );
});
final calendarDayTypesProvider = Provider.autoDispose
    .family<Map<int, Set<CalendarEventType>>, CalendarMonth>((ref, month) {
  final events =
      ref.watch(unifiedCalendarMonthProvider(month)).valueOrNull?.events ??
          const [];
  return {
    for (var d = 1; d <= DateTime.utc(month.year, month.month + 1, 0).day; d++)
      d: {
        for (final e in events)
          if (e.occursOn(DateTime.utc(month.year, month.month, d))) e.type,
      },
  };
});
