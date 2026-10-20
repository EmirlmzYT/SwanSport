import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_scope.dart';

class TransferRequest {
  TransferRequest.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        familyName = m['family_name'] as String?,
        athleteReference = m['athlete_reference'] as String,
        sport = m['sport_code'] as String,
        fromClub = m['from_club'] as String,
        toClub = m['to_club'] as String,
        reason = m['reason'] as String,
        status = m['status'] as String,
        consented = m['consented'] == true,
        accepted = m['accepted'] == true,
        canAccept = m['can_accept'] == true,
        canConsent = m['can_consent'] == true,
        canFinalize = m['can_finalize'] == true,
        canCancel = m['can_cancel'] == true,
        canReject = m['can_reject'] == true;
  final String id, athleteReference, sport, fromClub, toClub, reason, status;
  final String? familyName;
  final bool consented,
      accepted,
      canAccept,
      canConsent,
      canFinalize,
      canCancel,
      canReject;
}

class TransferCandidate {
  TransferCandidate.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        name = m['name'] as String,
        sport = m['sport_code'] as String,
        clubId = m['from_club_id'] as String,
        clubName = m['club_name'] as String;
  final String id, name, sport, clubId, clubName;
  String get key => '$id:$sport';
}

class TransferDestination {
  TransferDestination.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        name = m['name'] as String,
        sport = m['sport_code'] as String;
  final String id, name, sport;
}

class TransferRequestOptions {
  TransferRequestOptions.fromMap(Map<String, dynamic> m)
      : athletes = List.unmodifiable((m['athletes'] as List).map((r) =>
            TransferCandidate.fromMap(Map<String, dynamic>.from(r as Map)))),
        clubs = List.unmodifiable((m['clubs'] as List).map((r) =>
            TransferDestination.fromMap(Map<String, dynamic>.from(r as Map))));
  final List<TransferCandidate> athletes;
  final List<TransferDestination> clubs;
}

class TransferRequestService {
  TransferRequestService(this.client);
  final SupabaseClient client;
  Future<List<TransferRequest>> board() async => (await client
          .rpc<List<dynamic>>('my_transfer_requests'))
      .map((r) => TransferRequest.fromMap(Map<String, dynamic>.from(r as Map)))
      .toList();
  Future<TransferRequestOptions> options() async =>
      TransferRequestOptions.fromMap(
          await client.rpc<Map<String, dynamic>>('transfer_request_options'));
  Future<void> create(
      {required String id,
      required TransferCandidate athlete,
      required String toClub,
      required String reason}) async {
    await client.rpc<String>('submit_transfer_request', params: {
      'p_id': id,
      'p_athlete': athlete.id,
      'p_sport': athlete.sport,
      'p_to': toClub,
      'p_reason': reason
    });
  }

  Future<void> act(String id, String action) async {
    await client.rpc<dynamic>('act_transfer_request',
        params: {'p_id': id, 'p_action': action});
  }
}

final transferRequestServiceProvider = Provider<TransferRequestService>(
    (ref) => TransferRequestService(ref.watch(supabaseClientProvider)));
final transferRequestOptionsProvider =
    FutureProvider.autoDispose<TransferRequestOptions>((ref) {
  ref.watch(authSessionProvider);
  return ref.watch(transferRequestServiceProvider).options();
});
final transferRequestsProvider =
    FutureProvider.autoDispose<List<TransferRequest>>((ref) async {
  ref.watch(authSessionProvider);
  final result = await ref.watch(transferRequestServiceProvider).board();
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return result;
});
