import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access.dart';
import 'supabase_scope.dart';

dynamic _freeze(dynamic value) {
  if (value is Map) return Map<String, dynamic>.unmodifiable(
      value.map((key, value) => MapEntry(key as String, _freeze(value))));
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}
Map<String, dynamic> _object(dynamic value) =>
    _freeze(value ?? <String, dynamic>{}) as Map<String, dynamic>;
double _number(dynamic value) => value is num
    ? value.toDouble() : double.parse(value as String);
DateTime? _date(dynamic value) => value == null ? null : DateTime.parse(value as String);

/// Public configuration. These switches store intent; enforcement must be
/// wired separately into server-side signup/payment/marketplace workflows.
class PlatformConfig {
  PlatformConfig.fromMap(Map<String, dynamic> map)
      : branding = _object(map['branding']),
        commissions = _object(map['commissions']),
        maintenance = _object(map['maintenance']),
        broadcastAlert = _object(map['broadcast_alert']),
        killSwitches = _object(map['kill_switches']);
  const PlatformConfig.empty()
      : branding = const {}, commissions = const {}, maintenance = const {},
        broadcastAlert = const {}, killSwitches = const {};
  final Map<String, dynamic> branding;
  final Map<String, dynamic> commissions;
  final Map<String, dynamic> maintenance;
  final Map<String, dynamic> broadcastAlert;
  final Map<String, dynamic> killSwitches;
  String? get appName => branding['app_name'] as String?;
  String? get logoUrl => branding['logo_url'] as String?;
  String? get tagline => branding['tagline'] as String?;
  String? get supportEmail => branding['support_email'] as String?;
  bool get maintenanceEnabled => maintenance['enabled'] == true;
  bool get broadcastEnabled => broadcastAlert['enabled'] == true;
  bool get disableSignups => killSwitches['disable_signups'] == true;
  bool get disablePayments => killSwitches['disable_payments'] == true;
  bool get disableMarketplace => killSwitches['disable_marketplace'] == true;
}

class PlatformPlan {
  PlatformPlan({this.id, required this.target, required this.code,
    required this.name, this.badge, this.priceMonthly = 0, this.priceYearly = 0,
    this.maxAthletes, List<dynamic> features = const [], this.isActive = true,
    this.sortOrder = 0, this.createdAt, this.updatedAt})
      : features = _freeze(features) as List<dynamic>;
  final String? id;
  final String target;
  final String code;
  final String name;
  final String? badge;
  final double priceMonthly;
  final double priceYearly;
  final int? maxAthletes;
  final List<dynamic> features;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  factory PlatformPlan.fromMap(Map<String, dynamic> map) => PlatformPlan(
    id: map['id'] as String?, target: map['target'] as String,
    code: map['code'] as String, name: map['name'] as String,
    badge: map['badge'] as String?, priceMonthly: _number(map['price_monthly'] ?? 0),
    priceYearly: _number(map['price_yearly'] ?? 0),
    maxAthletes: (map['max_athletes'] as num?)?.toInt(),
    features: map['features'] as List<dynamic>? ?? const [],
    isActive: map['is_active'] as bool? ?? true,
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    createdAt: _date(map['created_at']), updatedAt: _date(map['updated_at']));
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'target': target, 'code': code, 'name': name,
    'badge': badge, 'price_monthly': priceMonthly, 'price_yearly': priceYearly,
    'max_athletes': maxAthletes, 'features': features, 'is_active': isActive,
    'sort_order': sortOrder,
  };
}

class PlatformAuditLog {
  PlatformAuditLog({required this.id, this.actorId, required this.action,
    required this.entityType, this.entityId, Map<String, dynamic>? oldState,
    Map<String, dynamic>? newState, this.createdAt})
      : oldState = oldState == null ? null : _object(oldState),
        newState = newState == null ? null : _object(newState);
  final String id;
  final String? actorId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? oldState;
  final Map<String, dynamic>? newState;
  final DateTime? createdAt;
  factory PlatformAuditLog.fromMap(Map<String, dynamic> map) => PlatformAuditLog(
    id: map['id'] as String, actorId: map['actor_id'] as String?,
    action: map['action'] as String, entityType: map['entity_type'] as String,
    entityId: map['entity_id'] as String?,
    oldState: map['old_state'] as Map<String, dynamic>?,
    newState: map['new_state'] as Map<String, dynamic>?, createdAt: _date(map['created_at']));
}

class PlatformMissionControlService {
  PlatformMissionControlService(this._client, {this.onWrite});
  final SupabaseClient _client;
  final void Function()? onWrite;
  Future<PlatformConfig> config() async => PlatformConfig.fromMap(
      Map<String, dynamic>.from(await _client.rpc('get_public_platform_config') as Map));
  Future<List<PlatformPlan>> plans() async {
    final rows = await _client.from('platform_plans').select().order('sort_order').order('code');
    return rows.map((row) => PlatformPlan.fromMap(row)).toList();
  }
  Future<List<PlatformAuditLog>> auditLogs({int limit = 100, int offset = 0}) async {
    if (limit < 1 || limit > 200 || offset < 0) throw ArgumentError('Invalid audit page');
    final rows = await _client.from('platform_audit_logs').select()
        .order('created_at', ascending: false).order('id', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map((row) => PlatformAuditLog.fromMap(row)).toList();
  }
  Future<void> updatePlatformSetting(String key, Map<String, dynamic> value) async {
    await _client.rpc('update_platform_setting', params: {'p_key': key, 'p_value': value});
    onWrite?.call();
  }
  Future<PlatformPlan> upsertPlatformPlan(PlatformPlan plan) async {
    if (!['club', 'athlete'].contains(plan.target) || plan.code.trim().isEmpty ||
        plan.name.trim().isEmpty || !plan.priceMonthly.isFinite || !plan.priceYearly.isFinite ||
        plan.priceMonthly < 0 || plan.priceYearly < 0 || (plan.maxAthletes ?? 0) < 0) {
      throw ArgumentError('Invalid platform plan');
    }
    // A new plan must not silently overwrite another administrator's plan
    // with the same code. Existing IDs retain explicit upsert semantics.
    final row = plan.id == null
        ? await _client.from('platform_plans').insert(plan.toMap()).select().single()
        : await _client.from('platform_plans').upsert(plan.toMap(), onConflict: 'id').select().single();
    onWrite?.call();
    return PlatformPlan.fromMap(row);
  }
}

final platformMissionControlServiceProvider = Provider<PlatformMissionControlService>((ref) =>
    PlatformMissionControlService(ref.watch(supabaseClientProvider), onWrite: () {
      ref.invalidate(platformConfigProvider);
      ref.invalidate(platformPlansProvider);
      ref.invalidate(platformAuditLogsProvider);
    }));
final platformConfigProvider = FutureProvider.autoDispose<PlatformConfig>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const PlatformConfig.empty();
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  ref.watch(authSessionProvider);
  return ref.watch(platformMissionControlServiceProvider).config();
});
final platformPlansProvider = FutureProvider.autoDispose<List<PlatformPlan>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  ref.watch(swanAccessProvider); // Re-fetch active/admin visibility on account changes.
  return ref.watch(platformMissionControlServiceProvider).plans();
});
final platformAuditLogsProvider = FutureProvider.autoDispose<List<PlatformAuditLog>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider) || !ref.watch(swanAccessProvider).isPlatformAdmin) return const [];
  return ref.watch(platformMissionControlServiceProvider).auditLogs(limit: 50);
});
