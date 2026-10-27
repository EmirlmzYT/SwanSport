import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_scope.dart';

/// Target application for push subscriptions and delivery isolation.
enum PushAppTarget {
  social('social'),
  pro('pro');

  const PushAppTarget(this.wireName);
  final String wireName;

  static PushAppTarget fromWire(String? value) {
    if (value == null) return PushAppTarget.social;
    return switch (value.trim().toLowerCase()) {
      'pro' => PushAppTarget.pro,
      _ => PushAppTarget.social,
    };
  }
}

/// The set of notification kinds eligible for professional operations (pro-only or both).
const proNotificationKinds = <String>{
  // Pro only (15)
  'referee_assignment',
  'expense_approval',
  'expense_rejected',
  'commitment_due',
  'account_negative',
  'bank_unmatched',
  'period_closed',
  'period_blocked',
  'turf_slot_request',
  'turf_field',
  'turf_manager',
  'court_waitlist',
  'turf_delegation',
  'store_decision',
  'moderation',
  // Both (18)
  'match_live',
  'match_result',
  'fee',
  'fee_reminder',
  'payment',
  'donation',
  'attendance',
  'attendance_reminder',
  'event',
  'announcement',
  'document',
  'documents',
  'document_expiry',
  'support',
  'eligibility',
  'training_session',
  'training_result',
  'application',
};

/// Returns true if [kind] is eligible to be presented in professional clients (SwanSport Pro).
bool isProNotificationKind(String? kind) {
  if (kind == null) return false;
  return proNotificationKinds.contains(kind.trim().toLowerCase());
}

/// Push subscription registration state on the server.
enum PushSubState {
  mine,
  otherAccount,
  missing,
  noSession,
}

/// Last push error retained for diagnostics without exposing sensitive tokens or credentials.
String? lastPushErrorDiagnostics;

/// Service for registering and querying device push subscriptions targeting
/// either the social app (`PushAppTarget.social`) or professional operations (`PushAppTarget.pro`).
class PushSubscriptionService {
  PushSubscriptionService({
    SupabaseClient? client,
    required PushAppTarget target,
  })  : _client = client,
        _target = target;

  final SupabaseClient? _client;
  final PushAppTarget _target;

  PushAppTarget get target => _target;

  /// Registers a push endpoint for the current authenticated user.
  /// If the endpoint was registered by another account on this physical device,
  /// ownership transitions to the current user.
  Future<void> registerSubscription({
    required String endpoint,
    String kind = 'fcm',
    String? p256dh,
    String? auth,
    String? userAgent,
  }) async {
    final client = _client;
    if (client == null) return;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) return;

    try {
      await client.rpc<void>(
        'register_push_subscription',
        params: {
          'p_endpoint': trimmed,
          'p_kind': kind,
          if (p256dh != null) 'p_p256dh': p256dh,
          if (auth != null) 'p_auth': auth,
          if (userAgent != null) 'p_user_agent': userAgent,
          'p_app_target': _target.wireName,
        },
      );
      lastPushErrorDiagnostics = null;
    } catch (e) {
      lastPushErrorDiagnostics = 'Push registration failed: ${e.runtimeType}';
      rethrow;
    }
  }

  /// Removes the push endpoint registration.
  Future<void> unregisterSubscription(String endpoint) async {
    final client = _client;
    if (client == null) return;
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) return;
    try {
      await client.rpc<void>(
        'drop_push_subscription',
        params: {
          'p_endpoint': trimmed,
        },
      );
      lastPushErrorDiagnostics = null;
    } catch (e) {
      lastPushErrorDiagnostics = 'Push unregistration failed: ${e.runtimeType}';
      rethrow;
    }
  }

  /// Checks the current device endpoint registration state on the server.
  Future<PushSubState> subscriptionState(String endpoint) async {
    final client = _client;
    if (client == null) return PushSubState.missing;
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) return PushSubState.missing;
    try {
      final res = await client.rpc<dynamic>(
        'push_subscription_state',
        params: {
          'p_endpoint': trimmed,
          'p_app_target': _target.wireName,
        },
      );
      return switch ('$res') {
        'mine' => PushSubState.mine,
        'other_account' => PushSubState.otherAccount,
        'no_session' => PushSubState.noSession,
        _ => PushSubState.missing,
      };
    } catch (e) {
      lastPushErrorDiagnostics = 'Push state query failed: ${e.runtimeType}';
      return PushSubState.missing;
    }
  }
}

/// Provider for the current application push target.
/// Defaults to [PushAppTarget.social].
/// SwanSport Pro overrides this in its root ProviderScope to [PushAppTarget.pro].
final pushAppTargetProvider = Provider<PushAppTarget>((ref) {
  return PushAppTarget.social;
});

/// Shared provider for [PushSubscriptionService].
final pushSubscriptionServiceProvider =
    Provider<PushSubscriptionService>((ref) {
  final target = ref.watch(pushAppTargetProvider);
  final isEnabled = ref.watch(isSupabaseEnabledProvider);
  final client = isEnabled ? ref.watch(supabaseClientProvider) : null;
  return PushSubscriptionService(client: client, target: target);
});
