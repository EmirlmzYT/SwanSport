import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feature_flags.dart';
import 'federation_bulletin_models.dart';
import 'federation_bulletin_service.dart';
import 'league_standings_models.dart';
import 'league_standings_service.dart';
import 'live_match_models.dart';
import 'live_match_service.dart';
import 'supabase_scope.dart';
import 'unified_calendar.dart';

enum FederationCenterTab {
  todayMatches,
  upcomingSchedule,
  resultsAndStandings,
  calendar,
}

class FederationCenterFilter {
  const FederationCenterFilter({
    this.sportCode,
    this.cityCode,
    this.query = '',
  });

  final String? sportCode;
  final String? cityCode;
  final String query;

  FederationCenterFilter copyWith({
    String? sportCode,
    String? cityCode,
    String? query,
    bool clearSport = false,
    bool clearCity = false,
  }) =>
      FederationCenterFilter(
        sportCode: clearSport ? null : (sportCode ?? this.sportCode),
        cityCode: clearCity ? null : (cityCode ?? this.cityCode),
        query: query ?? this.query,
      );

  @override
  bool operator ==(Object other) =>
      other is FederationCenterFilter &&
      sportCode == other.sportCode &&
      cityCode == other.cityCode &&
      query == other.query;

  @override
  int get hashCode => Object.hash(sportCode, cityCode, query);
}

class FederationCenterOverview {
  const FederationCenterOverview({
    required this.todayMatches,
    required this.liveMatches,
    required this.upcomingActivities,
    required this.leagues,
    this.disciplinaryDecisions = const [],
    this.notices = const [],
  });

  final List<PublicLiveMatchSummary> todayMatches;
  final List<PublicLiveMatchSummary> liveMatches;
  final List<FederationActivity> upcomingActivities;
  final List<StandingsLeague> leagues;
  final List<FederationDisciplinaryItem> disciplinaryDecisions;
  final List<FederationNoticeItem> notices;

  int get liveCount => liveMatches.length;
  int get todayCount => todayMatches.length;
  int get bulletinCount => disciplinaryDecisions.length + notices.length;
}

/// Kamuya açık federasyon merkezi özeti (Canlı maçlar, bugünün maçları, takvim aktiviteleri ve ligler).
final federationCenterOverviewProvider = FutureProvider.autoDispose
    .family<FederationCenterOverview, FederationCenterFilter>(
        (ref, filter) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return const FederationCenterOverview(
      todayMatches: [],
      liveMatches: [],
      upcomingActivities: [],
      leagues: [],
    );
  }

  // 1. Canlı ve bugünün maçları. Bu çağrı da bayrakla korunmalı; yalnız
  // ekrandaki kartı gizlemek kapalı özelliğin public RPC'sini çağırmayı
  // engellemez.
  final liveMatchHubEnabled =
      ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub));
  final allLiveMatches = liveMatchHubEnabled
      ? await ref.watch(liveMatchServiceProvider).fetchLiveMatches(
            sport: filter.sportCode,
            city: filter.cityCode,
          )
      : const <PublicLiveMatchSummary>[];

  final queryLower = filter.query.trim().toLowerCase();
  final filteredMatches = allLiveMatches.where((m) {
    if (queryLower.isEmpty) return true;
    final text =
        '${m.programName} ${m.homeClubName} ${m.awayClubName} ${m.location ?? ''}'
            .toLowerCase();
    return text.contains(queryLower);
  }).toList();

  final today = filteredMatches.where((m) => m.isToday || m.isLive).toList();
  final live = filteredMatches.where((m) => m.isLive).toList();

  // 2. Takvim aktiviteleri. Merkezdeki "Fikstür & Takvim" tek bir ayla
  // sınırlı değildir; bugünden başlayarak üç aylık yayımlanmış programı
  // getirir. Takvim ekranı aylık sanallaştırmasını kendi içinde korur.
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final activityFilter = (
    sportCode: filter.sportCode,
    cityCode: filter.cityCode,
    seasonId: null,
    from: todayStart,
    to: DateTime(todayStart.year, todayStart.month + 3, todayStart.day),
  );
  final activities = await ref.watch(
    federationActivitiesProvider(activityFilter).future,
  );

  final filteredActivities = activities.where((a) {
    if (queryLower.isEmpty) return true;
    return a.title.toLowerCase().contains(queryLower) ||
        a.federationName.toLowerCase().contains(queryLower);
  }).toList();

  // 3. Ligler ve Puan Durumları (Mevcut league_standings_service public RPC'si)
  List<StandingsLeague> leagues = const [];
  if (ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings))) {
    final standingsService = ref.watch(leagueStandingsServiceProvider);
    final allLeagues = await standingsService.leagues();
    leagues = allLeagues.where((l) {
      if (filter.sportCode != null && l.sportCode != filter.sportCode) {
        return false;
      }
      if (filter.cityCode != null && l.cityCode != filter.cityCode) {
        return false;
      }
      if (queryLower.isNotEmpty && !l.name.toLowerCase().contains(queryLower)) {
        return false;
      }
      return true;
    }).toList();
  }

  // 4. Disiplin bülteni ve resmi müsabaka duyuruları
  final bulletinService = ref.watch(federationBulletinServiceProvider);
  final allDecisions = await bulletinService.fetchDisciplinaryBulletin(
    sportCode: filter.sportCode,
    cityCode: filter.cityCode,
  );
  final allNotices = await bulletinService.fetchNotices(
    sportCode: filter.sportCode,
    cityCode: filter.cityCode,
  );

  final filteredDecisions = allDecisions.where((d) {
    if (queryLower.isEmpty) return true;
    final text = '${d.clubName} ${d.athleteDisplay} ${d.reason} ${d.matchTitle} ${d.penaltyLabel}'
        .toLowerCase();
    return text.contains(queryLower);
  }).toList();

  final filteredNotices = allNotices.where((n) {
    if (queryLower.isEmpty) return true;
    final text = '${n.title} ${n.body} ${n.programName}'.toLowerCase();
    return text.contains(queryLower);
  }).toList();

  return FederationCenterOverview(
    todayMatches: today,
    liveMatches: live,
    upcomingActivities: filteredActivities,
    leagues: leagues,
    disciplinaryDecisions: filteredDecisions,
    notices: filteredNotices,
  );
});
