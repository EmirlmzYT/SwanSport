import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pendingKey = 'setup_wizard_pending_accounts_v1';

/// Only successful registrations enter the guide queue. Existing accounts do
/// not become new users merely because a device has no local seen flag.
Future<void> queueSetupWizard(String accountId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final pending = {...?prefs.getStringList(_pendingKey), accountId};
    await prefs.setStringList(_pendingKey, pending.toList());
  } catch (_) {
    // Storage failure must not turn a successful registration into an error.
  }
}

Future<bool> setupWizardRequired(String accountId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pendingKey) ?? []).contains(accountId) &&
        !(prefs.getBool('setup_wizard_seen_v1_$accountId') ?? false);
  } catch (_) {
    return false;
  }
}

Future<void> markSetupWizardSeen(String accountId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_wizard_seen_v1_$accountId', true);
    final pending = (prefs.getStringList(_pendingKey) ?? [])
        .where((id) => id != accountId)
        .toList();
    await prefs.setStringList(_pendingKey, pending);
  } catch (_) {
    // The user can still leave the guide if local storage is unavailable.
  }
}

final setupWizardRequiredProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, accountId) => setupWizardRequired(accountId),
);
