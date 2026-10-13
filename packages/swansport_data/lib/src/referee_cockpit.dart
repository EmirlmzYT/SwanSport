import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sports_roles_service.dart';
import 'sports_roles_models.dart';
import 'supabase_scope.dart';

DateTime refereeTurkeyTime(DateTime instant) => instant.toUtc().add(const Duration(hours: 3));
bool refereeSupportsLive(String sportCode) => const {'futbol','basketbol','tenis'}.contains(sportCode);
bool refereeSameDay(DateTime? startsAt, DateTime now) {
  if (startsAt == null) return false;
  final a = refereeTurkeyTime(startsAt), b = refereeTurkeyTime(now);
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
String refereeOperationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
}

class RefereeLineupCandidate {
  const RefereeLineupCandidate({required this.athleteId, required this.side,
    this.name, this.jerseyNumber, this.licenseNumber, this.licenseExpiresOn,
    required this.eligibilityStatus, required this.eligible, required this.selection});
  final String athleteId;
  final String side;
  final String? name;
  final int? jerseyNumber;
  final String? licenseNumber;
  final DateTime? licenseExpiresOn;
  final String eligibilityStatus;
  final bool eligible;
  final String selection;
  String get maskedRef => '#${athleteId.replaceAll('-', '').substring(0,6).toUpperCase()}';
  factory RefereeLineupCandidate.fromMap(Map<String,dynamic> m) => RefereeLineupCandidate(
    athleteId: m['athlete_id'] as String, side: m['side'] as String,
    name: m['name'] as String?, jerseyNumber: m['jersey_number'] as int?,
    licenseNumber: m['license_number'] as String?,
    licenseExpiresOn: DateTime.tryParse(m['license_expires_on'] as String? ?? ''),
    eligibilityStatus: m['eligibility_status'] as String, eligible: m['eligible'] as bool,
    selection: m['selection'] as String);
}
class RefereeLiveEvent {
  const RefereeLiveEvent({required this.id, required this.version, required this.kind,
    this.side, this.athleteId, this.replacementId, this.card,
    required this.createdAt, required this.undone, this.elapsedSeconds=0});
  final String id;
  final int version;
  final String kind;
  final String? side;
  final String? athleteId;
  final String? replacementId;
  final String? card;
  final DateTime createdAt;
  final bool undone;
  final int elapsedSeconds;
  factory RefereeLiveEvent.fromMap(Map<String,dynamic> m) => RefereeLiveEvent(
    id:m['id'] as String, version:m['version'] as int, kind:m['kind'] as String,
    side:m['side'] as String?, athleteId:m['athlete_id'] as String?,
    replacementId:m['replacement_id'] as String?, card:m['card'] as String?,
    createdAt:DateTime.parse(m['created_at'] as String), undone:m['undone'] as bool,elapsedSeconds:m['elapsed_seconds'] as int? ?? 0);
}
class RefereeLiveState {
  RefereeLiveState({required this.matchId, required this.sportCode, required this.matchStatus,
    required this.version, required this.homeScore, required this.awayScore, required this.period,
    required this.elapsedSeconds, this.clockStartedAt, this.reportRevisionId,this.reportNotes,
    required List<RefereeLiveEvent> events, required Map<String,List<String>> squads,
    this.periodHome=0,this.periodAway=0,List<({int home,int away})> sets=const []})
    : events = List.unmodifiable(events), squads = Map.unmodifiable({
      for(final e in squads.entries) e.key:List<String>.unmodifiable(e.value)}),sets=List.unmodifiable(sets);
  final String matchId;
  final String sportCode;
  final String matchStatus;
  final int version;
  final int homeScore;
  final int awayScore;
  final int period;
  final int elapsedSeconds;
  final int periodHome;
  final int periodAway;
  final List<({int home,int away})> sets;
  final DateTime? clockStartedAt;
  final String? reportRevisionId;
  final String? reportNotes;
  final List<RefereeLiveEvent> events;
  final Map<String,List<String>> squads;
  bool get isClosed => matchStatus != 'scheduled' || reportRevisionId != null;
  int secondsAt(DateTime now) => elapsedSeconds + (clockStartedAt == null ? 0 :
    max(0, now.toUtc().difference(clockStartedAt!.toUtc()).inSeconds));
  factory RefereeLiveState.fromMap(Map<String,dynamic> m) => RefereeLiveState(
    matchId:m['match_id'] as String, sportCode:m['sport_code'] as String,
    matchStatus:m['match_status'] as String, version:m['version'] as int,
    homeScore:m['home_score'] as int, awayScore:m['away_score'] as int, period:m['period'] as int,
    elapsedSeconds:m['elapsed_seconds'] as int,
    clockStartedAt:DateTime.tryParse(m['clock_started_at'] as String? ?? ''),
    reportRevisionId:m['report_revision_id'] as String?,
    reportNotes:m['report_notes'] as String?,
    events:[for(final row in m['events'] as List) RefereeLiveEvent.fromMap(Map<String,dynamic>.from(row as Map))],
    squads:{for(final key in ['active_home','active_away','bench_home','bench_away'])
      key:(m[key] as List).cast<String>()},periodHome:m['period_home'] as int? ?? 0,
    periodAway:m['period_away'] as int? ?? 0,
    sets:[for(final row in m['sets'] as List? ?? const [])(home:(row as Map)['home'] as int,away:row['away'] as int)]);
}

class RefereeCockpitService {
  RefereeCockpitService(this._client);
  final SupabaseClient _client;
  Future<List<RefereeLineupCandidate>> candidates(String matchId) async {
    final rows = await _client.rpc('referee_lineup_candidates',params:{'p_match_id':matchId});
    return List.unmodifiable([for(final row in rows as List)
      RefereeLineupCandidate.fromMap(Map<String,dynamic>.from(row as Map))]);
  }
  Future<RefereeLiveState> state(String matchId) async => RefereeLiveState.fromMap(
    Map<String,dynamic>.from(await _client.rpc('referee_match_state',params:{'p_match_id':matchId}) as Map));
  Future<void> send(String rpc, Map<String,dynamic> params) async {
    if(!const {'referee_append_match_event','referee_submit_match_report'}.contains(rpc)) {
      throw ArgumentError.value(rpc,'rpc','Hakem yazma servisi yalnız maç olayı ve rapor kabul eder');
    }
    await _client.rpc(rpc,params:params);
  }
}
final refereeCockpitServiceProvider = Provider<RefereeCockpitService?>((ref) =>
  ref.watch(isSupabaseEnabledProvider) ? RefereeCockpitService(ref.watch(supabaseClientProvider)) : null);
final refereeLineupCandidatesProvider = FutureProvider.autoDispose.family<List<RefereeLineupCandidate>,String>((ref,matchId) async {
  if(ref.watch(authSessionProvider).valueOrNull == null) return const [];
  return await ref.watch(refereeCockpitServiceProvider)?.candidates(matchId) ?? const [];
});
final refereeMatchStateProvider = FutureProvider.autoDispose.family<RefereeLiveState?,String>((ref,matchId) async {
  if(ref.watch(authSessionProvider).valueOrNull == null) return null;
  final service = ref.watch(refereeCockpitServiceProvider);
  if(service == null) return null;
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final result = await service.state(matchId);
  if(!disposed && !result.isClosed) {
    final timer = Timer(const Duration(seconds:5),ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return result;
});
final refereeDutyMatchesProvider = FutureProvider.autoDispose<List<RefereeMatchSummary>>((ref) async {
  // One list poller shared by feed and duties; cancelled when unobserved.
  final timer=Timer(const Duration(seconds:30),()=>ref.invalidate(myRefereeMatchesProvider(null)));
  ref.onDispose(timer.cancel);
  return ref.watch(myRefereeMatchesProvider(null).future);
});
final refereeTodayMatchesProvider = FutureProvider.autoDispose<List<RefereeMatchSummary>>((ref) async {
  final matches = await ref.watch(refereeDutyMatchesProvider.future);
  return List.unmodifiable(matches.where((m) => m.canControl && m.matchStatus == 'scheduled' && refereeSameDay(m.startsAt,DateTime.now())));
});

class RefereeMutationState {
  const RefereeMutationState({this.busy = false, this.error, this.rpc, this.params});
  final bool busy;
  final String? error;
  final String? rpc;
  final Map<String,dynamic>? params;
  bool get pending => rpc != null;
}
/// Uncertain requests retain the exact operation ID/payload. No optimistic score.
/// This is an in-memory retry draft, not an offline journal; server events persist.
class RefereeMutationController extends StateNotifier<RefereeMutationState> {
  RefereeMutationController(this._service,this._refresh) : super(const RefereeMutationState());
  final RefereeCockpitService? _service;
  final void Function() _refresh;
  bool _disposed = false;
  Future<bool> submit(String rpc, Map<String,dynamic> params) async {
    if(state.busy || state.pending) return false;
    state = RefereeMutationState(rpc:rpc,params:Map.unmodifiable(params));
    return retry();
  }
  Future<bool> retry() async {
    if(state.busy || !state.pending) return false;
    final wasUncertain = state.error != null;
    final rpc = state.rpc!, params = state.params!;
    state = RefereeMutationState(busy:true,rpc:rpc,params:params);
    try {
      if(_service == null) throw StateError('Çevrimiçi bağlantı gerekli');
      await _service.send(rpc,params);
      if(_disposed) return false;
      state = const RefereeMutationState();_refresh();return true;
    } catch(e) {
      if(_disposed) return false;
      // A permission denial after a lost response cannot prove the earlier
      // transaction rolled back: authority may have been revoked after commit.
      final definitive = e is PostgrestException && ['42501','22023','40001','55000','P0001'].contains(e.code)
        && !(wasUncertain && e.code=='42501');
      state = RefereeMutationState(error:'$e',rpc:definitive ? null : rpc,params:definitive ? null : params);
      _refresh();return false;
    }
  }
  @override void dispose() {_disposed = true;super.dispose();}
}
final refereeMutationProvider = StateNotifierProvider.family<RefereeMutationController,RefereeMutationState,String>((ref,matchId) {
  ref.watch(authSessionProvider.select((s)=>s.valueOrNull?.user.id));
  return RefereeMutationController(ref.watch(refereeCockpitServiceProvider),() {
    ref.invalidate(refereeMatchStateProvider(matchId));
    ref.invalidate(refereeLineupCandidatesProvider(matchId));
    ref.invalidate(myRefereeMatchesProvider);
    ref.invalidate(refereeTodayMatchesProvider);
  });
});
