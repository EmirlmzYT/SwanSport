import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access.dart';
import 'news_service.dart';
import 'supabase_scope.dart';

class FederationStaffAssignment {
  const FederationStaffAssignment({
    required this.profileId,
    required this.name,
  });

  final String profileId;
  final String name;

  factory FederationStaffAssignment.fromMap(Map<String, dynamic> map) {
    final profile = (map['profiles'] as Map).cast<String, dynamic>();
    final name = ((profile['full_name'] as String?) ?? '').trim();
    return FederationStaffAssignment(
      profileId: map['profile_id'] as String,
      name: name.isEmpty ? 'Kullanıcı' : name,
    );
  }
}

class PlatformAdminParityService {
  const PlatformAdminParityService(this.client);

  final SupabaseClient client;

  Future<List<FederationStaffAssignment>> federationStaff(
    String communityId,
  ) async {
    final rows = await client
        .from('community_members')
        .select('profile_id, profiles!inner(full_name)')
        .eq('community_id', communityId)
        .eq('state', 'joined')
        .eq('role', 'staff')
        .order('profile_id');
    return (rows as List)
        .map(
          (row) => FederationStaffAssignment.fromMap(
            (row as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  Future<void> setFederationStaff({
    required String communityId,
    required String profileId,
    required bool staff,
  }) =>
      client.rpc<void>(
        'set_community_staff',
        params: {
          'p_community': communityId,
          'p_profile': profileId,
          'p_staff': staff,
        },
      );
}

final platformAdminParityServiceProvider = Provider<PlatformAdminParityService>(
  (ref) => PlatformAdminParityService(ref.watch(supabaseClientProvider)),
);

final platformRssSourcesProvider =
    FutureProvider.autoDispose<List<RssSource>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(swanAccessProvider).isPlatformAdmin) {
    return Future.value(const <RssSource>[]);
  }
  return ref.watch(newsServiceProvider).sources(onlyActive: false);
});

final federationStaffProvider = FutureProvider.autoDispose
    .family<List<FederationStaffAssignment>, String>((ref, communityId) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(swanAccessProvider).isPlatformAdmin) {
    return Future.value(const <FederationStaffAssignment>[]);
  }
  return ref
      .watch(platformAdminParityServiceProvider)
      .federationStaff(communityId);
});
