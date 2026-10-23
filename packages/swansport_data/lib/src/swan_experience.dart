import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access.dart';
import 'feature_flags.dart';
import 'supabase_scope.dart';

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from((value as Map?) ?? const {});
List<Map<String, dynamic>> _maps(dynamic value) =>
    [for (final item in (value as List?) ?? const []) _map(item)];

class SwanIdRole {
  const SwanIdRole({required this.kind, this.sportCode, this.coachLevel});
  final String kind;
  final String? sportCode;
  final int? coachLevel;
  factory SwanIdRole.fromMap(Map<String, dynamic> m) => SwanIdRole(
      kind: '${m['kind'] ?? ''}',
      sportCode: m['sport_code'] as String?,
      coachLevel: (m['coach_level'] as num?)?.toInt());
}

class SwanIdCard {
  const SwanIdCard(
      {required this.publicCode,
      required this.fullName,
      required this.visibility,
      required this.isMinor,
      required this.roles,
      required this.clubs,
      this.avatarPath,
      this.athleteId});
  final String publicCode, fullName, visibility;
  final bool isMinor;
  final String? avatarPath, athleteId;
  final List<SwanIdRole> roles;
  final List<Map<String, dynamic>> clubs;
  factory SwanIdCard.fromMap(Map<String, dynamic> m) => SwanIdCard(
      publicCode: '${m['public_code'] ?? ''}',
      fullName: '${m['full_name'] ?? ''}',
      visibility: '${m['visibility'] ?? 'private'}',
      isMinor: m['is_minor'] == true,
      avatarPath: m['avatar_path'] as String?,
      athleteId: m['athlete_id'] as String?,
      roles: _maps(m['roles']).map(SwanIdRole.fromMap).toList(),
      clubs: _maps(m['clubs']));
}

class SwanShowcaseVideo {
  const SwanShowcaseVideo(
      {required this.id,
      required this.title,
      required this.storagePath,
      required this.durationSeconds,
      required this.status,
      required this.discoverable,
      required this.clubVerified,
      required this.guardianApproved,
      this.description,
      this.sportCode,
      this.signedUrl});
  final String id, title, storagePath, status;
  final int durationSeconds;
  final bool discoverable, clubVerified, guardianApproved;
  final String? description, sportCode, signedUrl;
  factory SwanShowcaseVideo.fromMap(Map<String, dynamic> m,
          {String? signedUrl}) =>
      SwanShowcaseVideo(
          id: '${m['id']}',
          title: '${m['title'] ?? ''}',
          storagePath: '${m['storage_path'] ?? ''}',
          durationSeconds: (m['duration_seconds'] as num?)?.toInt() ?? 0,
          status: '${m['status'] ?? 'draft'}',
          discoverable: m['discoverable'] == true,
          clubVerified: m['club_verified'] == true,
          guardianApproved: m['guardian_approved'] == true,
          description: m['description'] as String?,
          sportCode: m['sport_code'] as String?,
          signedUrl: signedUrl);
}

class AthleteJourneyEntry {
  const AthleteJourneyEntry(
      {required this.id,
      required this.kind,
      required this.source,
      required this.title,
      required this.happenedAt,
      this.summary});
  final String id, kind, source, title;
  final String? summary;
  final DateTime happenedAt;
  factory AthleteJourneyEntry.fromMap(Map<String, dynamic> m) =>
      AthleteJourneyEntry(
          id: '${m['id']}',
          kind: '${m['kind']}',
          source: '${m['source']}',
          title: '${m['title']}',
          summary: m['summary'] as String?,
          happenedAt: DateTime.tryParse('${m['happened_at']}')?.toLocal() ??
              DateTime.now());
}

class EventPreparation {
  const EventPreparation(
      {required this.eventId,
      required this.title,
      required this.startsAt,
      required this.equipment,
      this.place,
      this.meetingAt,
      this.kitNote,
      this.coachNote,
      this.rsvp});
  final String eventId, title;
  final DateTime startsAt;
  final String? place, kitNote, coachNote, rsvp;
  final DateTime? meetingAt;
  final List<String> equipment;
  factory EventPreparation.fromMap(Map<String, dynamic> m) => EventPreparation(
      eventId: '${m['event_id']}',
      title: '${m['title']}',
      startsAt: DateTime.parse('${m['starts_at']}').toLocal(),
      place: m['place'] as String?,
      meetingAt: m['meeting_at'] == null
          ? null
          : DateTime.parse('${m['meeting_at']}').toLocal(),
      equipment: [for (final x in m['equipment'] as List? ?? const []) '$x'],
      kitNote: m['kit_note'] as String?,
      coachNote: m['coach_note'] as String?,
      rsvp: m['rsvp'] as String?);
}

class TeamKudo {
  const TeamKudo(
      {required this.id,
      required this.badge,
      required this.source,
      required this.createdAt});
  final String id, badge, source;
  final DateTime createdAt;
  factory TeamKudo.fromMap(Map<String, dynamic> m) => TeamKudo(
      id: '${m['id']}',
      badge: '${m['badge']}',
      source: '${m['source']}',
      createdAt: DateTime.parse('${m['created_at']}').toLocal());
}

class AthleteMatchCard {
  const AthleteMatchCard(this.data);
  final Map<String, dynamic> data;
  String get matchId => '${data['match_id']}';
  String get programName => '${data['program_name'] ?? 'Resmi maç'}';
  String get status => '${data['status'] ?? ''}';
  String get lineupStatus => '${data['lineup_status'] ?? 'not_shared'}';
  bool get isLive => data['is_live'] == true;
}

class SwanAssistantIntent {
  const SwanAssistantIntent(
      {required this.key,
      required this.title,
      required this.answer,
      required this.actionKey,
      this.feature});
  final String key, title, answer, actionKey;
  final String? feature;
  factory SwanAssistantIntent.fromMap(Map<String, dynamic> m) =>
      SwanAssistantIntent(
          key: '${m['key']}',
          title: '${m['title']}',
          answer: '${m['answer']}',
          actionKey: '${m['action_key'] ?? 'help'}',
          feature: m['feature'] as String?);
}

class SwanExperienceService {
  SwanExperienceService(this._client);
  final SupabaseClient _client;
  Future<SwanIdCard> myCard() async =>
      SwanIdCard.fromMap(_map(await _client.rpc<dynamic>('my_swan_id_card')));
  Future<void> setVisibility(String value) => _client
      .rpc<void>('set_my_swan_id_visibility', params: {'p_visibility': value});
  Future<String> createShare({String? profileId, int hours = 24}) async =>
      '${await _client.rpc<dynamic>('create_swan_id_share', params: {
            if (profileId != null) 'p_profile': profileId,
            'p_hours': hours
          })}';
  Future<Map<String, dynamic>> verify(String token) async => _map(
      await _client.rpc<dynamic>('verify_swan_id', params: {'p_token': token}));
  Future<int> revokeShares({String? profileId}) async =>
      (await _client.rpc<num>('revoke_my_swan_id_shares',
              params: {if (profileId != null) 'p_profile': profileId}))
          .toInt();
  Future<List<SwanShowcaseVideo>> videos() async {
    final rows = _maps(await _client.rpc<dynamic>('my_showcase_videos'));
    return Future.wait([
      for (final row in rows)
        () async {
          String? url;
          try {
            url = await _client.storage
                .from('athlete-showcase')
                .createSignedUrl('${row['storage_path']}', 3600);
          } catch (_) {}
          return SwanShowcaseVideo.fromMap(row, signedUrl: url);
        }()
    ]);
  }

  Future<String> reserveAndUpload(
      {required String title,
      required String sportCode,
      required int durationSeconds,
      required String mimeType,
      required String extension,
      required Uint8List bytes,
      String? description,
      String? eventId,
      String? matchId}) async {
    final result =
        _map(await _client.rpc<dynamic>('reserve_showcase_video', params: {
      'p_title': title,
      'p_description': description,
      'p_sport': sportCode,
      'p_duration': durationSeconds,
      'p_size': bytes.length,
      'p_mime': mimeType,
      'p_extension': extension,
      'p_event': eventId,
      'p_match': matchId
    }));
    await _client.storage.from('athlete-showcase').uploadBinary(
        '${result['storage_path']}', bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: false));
    return '${result['id']}';
  }

  Future<void> publishVideo(String id) =>
      _client.rpc<void>('publish_showcase_video', params: {'p_video': id});
  Future<void> reviewVideo(String id, String decision) =>
      _client.rpc<void>('review_showcase_video',
          params: {'p_video': id, 'p_decision': decision});
  Future<void> guardianApproveVideo(String id, bool approved) =>
      _client.rpc<void>('guardian_approve_showcase_video',
          params: {'p_video': id, 'p_approved': approved});
  Future<void> archiveVideo(String id) =>
      _client.rpc<void>('archive_showcase_video', params: {'p_video': id});
  Future<List<AthleteJourneyEntry>> journey(String athleteId) async =>
      _maps(await _client.rpc<dynamic>('athlete_journey',
              params: {'p_athlete': athleteId}))
          .map(AthleteJourneyEntry.fromMap)
          .toList();
  Future<String> addMilestone(String athleteId, String title, String? summary,
          DateTime happenedAt) async =>
      '${await _client.rpc<dynamic>('add_athlete_milestone', params: {
            'p_athlete': athleteId,
            'p_title': title,
            'p_summary': summary,
            'p_happened_at': happenedAt.toUtc().toIso8601String()
          })}';
  Future<EventPreparation> preparation(String eventId) async =>
      EventPreparation.fromMap(_map(await _client
          .rpc<dynamic>('my_event_preparation', params: {'p_event': eventId})));
  Future<void> savePreparation(String eventId,
          {DateTime? meetingAt,
          List<String> equipment = const [],
          String? kitNote,
          String? coachNote}) =>
      _client.rpc<void>('set_event_preparation', params: {
        'p_event': eventId,
        'p_meeting': meetingAt?.toUtc().toIso8601String(),
        'p_equipment': equipment,
        'p_kit': kitNote,
        'p_note': coachNote
      });
  Future<List<TeamKudo>> kudos() async =>
      _maps(await _client.rpc<dynamic>('my_team_kudos'))
          .map(TeamKudo.fromMap)
          .toList();
  Future<void> sendKudo(String eventId, String receiverId, String badge) =>
      _client.rpc<void>('send_team_kudos', params: {
        'p_event': eventId,
        'p_receiver': receiverId,
        'p_badge': badge
      });
  Future<AthleteMatchCard> matchCard(String matchId) async =>
      AthleteMatchCard(_map(await _client.rpc<dynamic>('my_athlete_match_card',
          params: {'p_match': matchId})));
  Future<List<AthleteMatchCard>> matchCards() async =>
      _maps(await _client.rpc<dynamic>('my_athlete_match_cards'))
          .map(AthleteMatchCard.new)
          .toList();
  Future<List<SwanAssistantIntent>> assistant(
          {String query = '',
          List<String> audience = const [],
          List<String> features = const []}) async =>
      _maps(await _client.rpc<dynamic>('search_swan_assistant', params: {
        'p_query': query,
        'p_audience': audience,
        'p_features': features
      }))
          .map(SwanAssistantIntent.fromMap)
          .toList();
  Future<void> assistantFeedback(String? intent,
          {required bool matched, bool? helpful}) =>
      _client.rpc<void>('record_assistant_feedback', params: {
        'p_intent': intent,
        'p_matched': matched,
        'p_helpful': helpful
      });
}

final swanExperienceServiceProvider = Provider<SwanExperienceService>(
    (ref) => SwanExperienceService(ref.watch(supabaseClientProvider)));
final mySwanIdProvider = FutureProvider.autoDispose<SwanIdCard>(
    (ref) => ref.watch(swanExperienceServiceProvider).myCard());
final myShowcaseVideosProvider =
    FutureProvider.autoDispose<List<SwanShowcaseVideo>>(
        (ref) => ref.watch(swanExperienceServiceProvider).videos());
final athleteJourneyProvider = FutureProvider.autoDispose
    .family<List<AthleteJourneyEntry>, String>(
        (ref, id) => ref.watch(swanExperienceServiceProvider).journey(id));
final eventPreparationProvider = FutureProvider.autoDispose
    .family<EventPreparation, String>(
        (ref, id) => ref.watch(swanExperienceServiceProvider).preparation(id));
final myTeamKudosProvider = FutureProvider.autoDispose<List<TeamKudo>>(
    (ref) => ref.watch(swanExperienceServiceProvider).kudos());
final athleteMatchCardProvider = FutureProvider.autoDispose
    .family<AthleteMatchCard, String>(
        (ref, id) => ref.watch(swanExperienceServiceProvider).matchCard(id));
final athleteMatchCardsProvider =
    FutureProvider.autoDispose<List<AthleteMatchCard>>(
        (ref) => ref.watch(swanExperienceServiceProvider).matchCards());
final swanAssistantProvider = FutureProvider.autoDispose
    .family<List<SwanAssistantIntent>, String>((ref, query) async {
  final flags =
      ref.watch(featureFlagsProvider).valueOrNull?.enabled ?? const <String>[];
  final access = ref.watch(swanAccessProvider);
  final audience = <String>['everyone'];
  if (access.athleteKind != null || access.clubRole == 'athlete') {
    audience.add('athlete');
  }
  if (access.coachLevel > 0 || access.clubRole == 'coach') {
    audience.add('coach');
  }
  if (access.isParent) audience.add('parent');
  return ref
      .watch(swanExperienceServiceProvider)
      .assistant(query: query, features: flags, audience: audience);
});
