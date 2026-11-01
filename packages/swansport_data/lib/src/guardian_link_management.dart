import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_athletes.dart';
import 'supabase_scope.dart';

class ClubGuardianAthlete {
  const ClubGuardianAthlete({
    required this.id,
    required this.displayName,
    required this.isMinor,
    required this.status,
    required this.guardianCount,
  });

  final String id;
  final String displayName;
  final bool isMinor;
  final String status;
  final int guardianCount;

  factory ClubGuardianAthlete.fromMap(Map<String, dynamic> map) =>
      ClubGuardianAthlete(
        id: map['id'] as String,
        displayName: (map['display_name'] as String?) ?? 'Sporcu',
        isMinor: map['is_minor'] == true,
        status: (map['status'] as String?) ?? 'active',
        guardianCount: (map['guardian_count'] as num?)?.toInt() ?? 0,
      );
}

class ClubGuardianLink {
  const ClubGuardianLink({
    required this.id,
    required this.athleteId,
    required this.athleteDisplayName,
    required this.guardianLabel,
    required this.relationship,
  });

  final String id;
  final String athleteId;
  final String athleteDisplayName;
  final String guardianLabel;
  final String relationship;

  factory ClubGuardianLink.fromMap(Map<String, dynamic> map) =>
      ClubGuardianLink(
        id: map['id'] as String,
        athleteId: map['athlete_id'] as String,
        athleteDisplayName:
            (map['athlete_display_name'] as String?) ?? 'Sporcu',
        guardianLabel: (map['guardian_label'] as String?) ?? 'Veli hesabı',
        relationship: (map['relationship'] as String?) ?? 'Veli',
      );
}

class PendingGuardianInvite {
  const PendingGuardianInvite({
    required this.id,
    required this.athleteId,
    required this.athleteDisplayName,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String athleteId;
  final String athleteDisplayName;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());

  factory PendingGuardianInvite.fromMap(Map<String, dynamic> map) =>
      PendingGuardianInvite(
        id: map['id'] as String,
        athleteId: map['athlete_id'] as String,
        athleteDisplayName:
            (map['athlete_display_name'] as String?) ?? 'Sporcu',
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        expiresAt: DateTime.parse(map['expires_at'] as String).toLocal(),
      );
}

class ClubGuardianLinkOverview {
  const ClubGuardianLinkOverview({
    this.athletes = const [],
    this.links = const [],
    this.pendingInvites = const [],
  });

  final List<ClubGuardianAthlete> athletes;
  final List<ClubGuardianLink> links;
  final List<PendingGuardianInvite> pendingInvites;

  int get pendingCount =>
      pendingInvites.where((invite) => !invite.isExpired).length;

  factory ClubGuardianLinkOverview.fromMap(Map<String, dynamic> map) {
    List<T> parse<T>(
      String key,
      T Function(Map<String, dynamic>) fromMap,
    ) =>
        (map[key] as List? ?? const [])
            .map((row) => fromMap((row as Map).cast<String, dynamic>()))
            .toList(growable: false);

    return ClubGuardianLinkOverview(
      athletes: parse('athletes', ClubGuardianAthlete.fromMap),
      links: parse('links', ClubGuardianLink.fromMap),
      pendingInvites: parse('pending_invites', PendingGuardianInvite.fromMap),
    );
  }
}

class GuardianLinkManagementService {
  GuardianLinkManagementService(this._client);

  final SupabaseClient _client;

  Future<ClubGuardianLinkOverview> overview(String clubId) async {
    final result = await _client.rpc<dynamic>(
      'club_guardian_link_overview',
      params: {'p_club': clubId},
    );
    return ClubGuardianLinkOverview.fromMap(
      (result as Map).cast<String, dynamic>(),
    );
  }

  Future<void> cancelPendingInvite(String inviteId) => _client.rpc<void>(
        'cancel_guardian_invite',
        params: {'p_invite': inviteId},
      );
}

final guardianLinkManagementServiceProvider =
    Provider<GuardianLinkManagementService>((ref) {
  return GuardianLinkManagementService(ref.watch(supabaseClientProvider));
});

final clubGuardianLinkOverviewProvider =
    FutureProvider.autoDispose<ClubGuardianLinkOverview>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return const ClubGuardianLinkOverview();
  }
  final club = await ref.watch(activeClubProvider.future);
  if (club == null || club.role != 'club_admin') {
    throw StateError('Kulüp yöneticisi yetkisi gerekli.');
  }
  return ref.watch(guardianLinkManagementServiceProvider).overview(club.id);
});
