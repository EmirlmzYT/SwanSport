import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_scope.dart';

/// Özellik bayrakları — kademeli yayın.
///
/// **Neden var:** planın kararı, "büyük özellikler doğrudan herkese açılmaz".
/// Bugüne kadar öyle açıldı: kort sistemi, partner arama, halı saha ve
/// pazaryeri yazıldıkları gün herkese görünür oldu ve hiçbiri önce
/// denenmedi. Bayrak olmadan "önce test kullanıcılarıyla dene" bir niyet;
/// bayrakla bir düğme.
///
/// **Bayrak güvenlik değildir.** Yalnızca görünürlük: bir özelliği kapatmak
/// ekranı gizler, veriyi korumaz. Koruma her zaman RLS ve RPC'de.
///
/// Sunucu erişilemezse **boş küme** dönüyor, yani hiçbir bayraklı özellik
/// açılmıyor. Tersi tehlikeli olurdu: ağ hatası yeni bir özelliği yanlışlıkla
/// herkese açardı.
class FeatureFlags {
  const FeatureFlags(this._keys);

  const FeatureFlags.none() : _keys = const {};

  final Set<String> _keys;

  bool has(String key) => _keys.contains(key);

  /// Bilinen bayraklar. Sabit olarak burada duruyorlar ki yazım hatası
  /// derleme zamanında yakalansın; `has('marketpalce')` sessizce false döner.
  static const marketplace = 'marketplace';
  static const courts = 'courts';
  static const partnerSearch = 'partner_search';
  static const turfFields = 'turf_fields';
  static const teamHub = 'team_hub';

  /// 0054. Sabiti eksikti; feature_flag_sync_test bunu yakaladı.
  static const coachDiscovery = 'coach_discovery';

  // 0061 — mali operasyon merkezi
  static const financeOperationsCenter = 'finance_operations_center';
  static const recurringExpenses = 'recurring_expenses';
  static const bankReconciliation = 'bank_reconciliation';
  static const clubBudgeting = 'club_budgeting';
  static const periodClosing = 'period_closing';
  static const clubOperationsCenter = 'club_operations_center';

  // 0063 — sosyal katman
  static const socialSavedPosts = 'social_saved_posts';
  static const socialMultiPhoto = 'social_multi_photo';
  static const socialContentShare = 'social_content_share';
  static const socialReposts = 'social_reposts';
  static const socialMentions = 'social_mentions';
  static const socialSportsCards = 'social_sports_cards';
  static const socialExternalShare = 'social_external_share';

  /// V1 kapsamında **değil**. Anahtar baştan tanımlı ki açılacağı gün şema
  /// değil yalnızca kademe değişsin.
  static const socialVideo = 'social_video';

  // 0064-0066 — kulüp yaşam döngüsü
  static const eligibilityGate = 'eligibility_gate';
  static const membershipLifecycle = 'membership_lifecycle';
  static const parentHub = 'parent_hub';
  static const coachWorkspace = 'coach_workspace';
  static const facilityConflicts = 'facility_conflicts';
  static const notificationPreferences = 'notification_preferences';
  static const supportCenter = 'support_center';
  static const operationsAnalytics = 'operations_analytics';
  static const clubOperationalRisk = 'club_operational_risk';
  static const tournamentHub = 'tournament_hub';
  static const clubOnboarding = 'club_onboarding';
  static const clubCsvImport = 'club_csv_import';

  /// 0068. Kapak, marka rengi, avatar tonu ve kulüp vitrini.
  static const identityCustomization = 'identity_customization';

  /// Çakışma çözme ekranı yazılmadan açılmamalı — yanlış çalıştığında veri
  /// kaybettiriyor. Sunucuda da `off` kademesinde.
  static const offlineAttendance = 'offline_attendance';
}

/// Bu kullanıcı için açık bayraklar.
///
/// `autoDispose` **değil**: açılışta bir kez alınıp uygulama boyunca
/// tutuluyor. Her ekranda yeniden sormak, açılışı ekran sayısı kadar
/// yavaşlatırdı.
final featureFlagsProvider = FutureProvider<FeatureFlags>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return const FeatureFlags.none();
  }
  try {
    final rows = await ref
        .watch(supabaseClientProvider)
        .rpc<dynamic>('my_feature_flags');
    final keys = ((rows as List?) ?? const [])
        .map((r) => ((r as Map)['key'] as String?) ?? '')
        .where((k) => k.isNotEmpty)
        .toSet();
    return FeatureFlags(keys);
  } catch (_) {
    // 0053 çalıştırılmadıysa fonksiyon yok. Bayraklı özellikler kapalı
    // kalıyor — kapalı bir özellik, yanlışlıkla açılmış bir özellikten iyi.
    return const FeatureFlags.none();
  }
});

/// Tek bir bayrağın durumu — ekranların çoğu yalnızca birini soruyor.
final featureEnabledProvider =
    Provider.family<bool, String>((ref, key) {
  final flags = ref.watch(featureFlagsProvider).valueOrNull;
  return flags?.has(key) ?? false;
});
