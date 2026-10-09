import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'club_lifecycle_service.dart';
import 'feature_flags.dart';
import 'supabase_scope.dart';
import 'vault_service.dart';

class GuardianChild {
  const GuardianChild({
    required this.id,
    required this.name,
    required this.clubId,
    required this.clubName,
  });
  final String id, name, clubId, clubName;
  factory GuardianChild.fromMap(Map<String, dynamic> m) => GuardianChild(
        id: m['id'] as String,
        name: m['full_name'] as String,
        clubId: m['club_id'] as String,
        clubName: m['club_name'] as String,
      );
}

class GuardianEventAction {
  const GuardianEventAction({
    required this.id,
    required this.title,
    required this.childId,
    required this.childName,
    required this.clubName,
    required this.startsAt,
    this.place,
    this.response,
    this.responseAt,
  });
  final String id, title, childId, childName, clubName;
  final String? place, response;
  final DateTime startsAt;
  // Keep the exact server timestamp: rounding microseconds breaks optimistic checks.
  final String? responseAt;
  factory GuardianEventAction.fromMap(Map<String, dynamic> m) =>
      GuardianEventAction(
        id: m['id'] as String,
        title: m['title'] as String,
        childId: m['athlete_id'] as String,
        childName: m['child_name'] as String,
        clubName: m['club_name'] as String,
        startsAt: DateTime.parse(m['starts_at'] as String).toLocal(),
        place: m['place'] as String?,
        response: m['response'] as String?,
        responseAt: m['response_at'] as String?,
      );
}

class ParentActions {
  const ParentActions({
    this.children = const [],
    this.events = const [],
    this.documents = const [],
    this.tickets = const [],
  });
  final List<GuardianChild> children;
  final List<GuardianEventAction> events;
  final List<VaultDoc> documents;
  final List<SupportTicket> tickets;
  int get count => events.length + documents.length + tickets.length;
  factory ParentActions.fromMap(Map<String, dynamic> m) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) fn) =>
        (m[key] as List)
            .map((v) => fn((v as Map).cast<String, dynamic>()))
            .toList(growable: false);
    return ParentActions(
      children: parse('children', GuardianChild.fromMap),
      events: parse('events', GuardianEventAction.fromMap),
      documents: parse('documents', VaultDoc.fromMap),
      tickets: parse('tickets', SupportTicket.fromMap),
    );
  }
}

class ParentActionService {
  ParentActionService(this.client);
  final SupabaseClient client;
  Future<ParentActions> load() async {
    final result = await client.rpc<dynamic>('my_parent_actions');
    return ParentActions.fromMap((result as Map).cast<String, dynamic>());
  }

  Future<void> respond(GuardianEventAction event, String status) =>
      client.rpc<void>(
        'set_guardian_event_rsvp',
        params: {
          'p_event': event.id,
          'p_athlete': event.childId,
          'p_status': status,
          'p_expected': event.responseAt,
        },
      );
}

final parentActionServiceProvider = Provider<ParentActionService>(
  (ref) => ParentActionService(ref.watch(supabaseClientProvider)),
);
final parentActionsProvider = FutureProvider.autoDispose<ParentActions>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(featureEnabledProvider(FeatureFlags.parentHub))) {
    return Future.value(const ParentActions());
  }
  ref.watch(authSessionProvider);
  return ref.watch(parentActionServiceProvider).load();
});

// Guardian is an independent relationship, including coach + parent accounts.
// Do not use my_children_overview here: staff can read other athletes there.
final guardianAthleteIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const {};
  ref.watch(authSessionProvider);
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const {};
  final rows =
      await client.from('guardians').select('athlete_id').eq('profile_id', uid);
  return rows.map((r) => r['athlete_id'] as String).toSet();
});
