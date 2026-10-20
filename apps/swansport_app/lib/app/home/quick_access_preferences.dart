import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swansport_data/swansport_data.dart';

/// Device-local display preferences; never a source of permissions.
class QuickAccessPreferences {
  const QuickAccessPreferences({this.hidden = false, this.ids});

  final bool hidden;
  // null follows role defaults; an empty list is an intentional empty choice.
  final List<String>? ids;

  String encode() => jsonEncode({'hidden': hidden, 'ids': ids});

  static QuickAccessPreferences decode(String? raw) {
    try {
      final value = jsonDecode(raw ?? '') as Map<String, dynamic>;
      final ids = value['ids'];
      return QuickAccessPreferences(
        hidden: value['hidden'] == true,
        ids: ids is List
            ? ids.whereType<String>().toSet().take(4).toList()
            : null,
      );
    } catch (_) {
      return const QuickAccessPreferences();
    }
  }
}

final quickAccessAccountProvider = Provider<String?>((ref) {
  if (!ref.watch(swanAccessProvider).hasAccount) return null;
  if (ref.watch(isSupabaseEnabledProvider)) {
    return ref.watch(authSessionProvider).valueOrNull?.user.id;
  }
  return ref.watch(currentProfileProvider).valueOrNull?.id;
});

final quickAccessPreferencesProvider = StateNotifierProvider.autoDispose
    .family<QuickAccessController, AsyncValue<QuickAccessPreferences>, String>(
  (ref, accountId) => QuickAccessController(accountId),
);

class QuickAccessController
    extends StateNotifier<AsyncValue<QuickAccessPreferences>> {
  QuickAccessController(String accountId)
      : storageKey = 'swan.quick_access.v1.$accountId',
        super(const AsyncLoading()) {
    _load();
  }

  final String storageKey;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = QuickAccessPreferences.decode(prefs.getString(storageKey));
      if (mounted) state = AsyncData(value);
    } catch (error, stack) {
      if (mounted) state = AsyncError(error, stack);
    }
  }

  Future<void> save(QuickAccessPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, value.encode())) {
      throw StateError('Hızlı erişim tercihleri kaydedilemedi.');
    }
    if (mounted) state = AsyncData(value);
  }
}
