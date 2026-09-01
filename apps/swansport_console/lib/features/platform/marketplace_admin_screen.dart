import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../app/theme/console_theme.dart';

/// Pazaryeri yönetimi — mağaza başvuruları ve raporlanan ilanlar.
///
/// **Ticari analitik yok.** Satış hacmi, komisyon ve ciro raporları gerçek
/// ödeme verisi oluşmadan üretilemez; üretilirse uydurma sayı olur. Buradaki
/// metrikler yalnızca sayılabilir gerçekler: kaç ilan, kaç rapor, hangi oran.
class MarketplaceAdminScreen extends ConsumerStatefulWidget {
  const MarketplaceAdminScreen({super.key});

  @override
  ConsumerState<MarketplaceAdminScreen> createState() =>
      _MarketplaceAdminScreenState();
}

class _MarketplaceAdminScreenState
    extends ConsumerState<MarketplaceAdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Pazaryeri', style: t.textTheme.titleMedium),
            const SizedBox(width: ConsoleDensity.lg),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Mağaza başvuruları')),
                ButtonSegment(value: 1, label: Text('Raporlar')),
                ButtonSegment(value: 2, label: Text('Özet')),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
          ]),
          const SizedBox(height: ConsoleDensity.xl),
          Expanded(
            child: switch (_tab) {
              1 => _reports(t),
              2 => _summary(t),
              _ => _stores(t),
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ mağaza başvuruları

  Widget _stores(ThemeData t) {
    final async = ref.watch(adminStoresProvider);
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _err(t, '$e'),
      data: (rows) {
        if (rows.isEmpty) return _empty(t, 'Bekleyen mağaza başvurusu yok');
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: ConsoleDensity.md),
          itemBuilder: (_, i) => _storeCard(t, rows[i]),
        );
      },
    );
  }

  Widget _storeCard(ThemeData t, Map<String, dynamic> s) {
    final status = '${s['status']}';
    final noteCtrl = TextEditingController(text: '${s['review_note'] ?? ''}');

    return Container(
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        border: Border.all(color: t.colorScheme.outline),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${s['name']}', style: t.textTheme.titleSmall),
          ),
          Text(status.toUpperCase(), style: t.textTheme.labelSmall),
        ]),
        if ('${s['description'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: ConsoleDensity.sm),
          Text('${s['description']}', style: t.textTheme.bodySmall),
        ],
        if ('${s['application_note'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: ConsoleDensity.sm),
          Text('Başvuru notu: ${s['application_note']}',
              style: t.textTheme.bodySmall),
        ],
        const SizedBox(height: ConsoleDensity.md),
        TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Karar notu (başvurana görünür)',
          ),
        ),
        const SizedBox(height: ConsoleDensity.md),
        Row(children: [
          FilledButton(
            onPressed: () => _decide(s['id'] as String, 'approved', noteCtrl.text),
            child: const Text('Onayla'),
          ),
          const SizedBox(width: ConsoleDensity.md),
          OutlinedButton(
            // Ret notu zorunlu: sebebini bilmeyen başvuran aynı başvuruyu
            // tekrar gönderiyor ve iki taraf da zaman kaybediyor.
            onPressed: () => noteCtrl.text.trim().isEmpty
                ? _say('Reddetmek için karar notu yaz')
                : _decide(s['id'] as String, 'rejected', noteCtrl.text),
            child: const Text('Reddet'),
          ),
          const SizedBox(width: ConsoleDensity.md),
          if (status == 'approved')
            TextButton(
              onPressed: () =>
                  _decide(s['id'] as String, 'suspended', noteCtrl.text),
              child: const Text('Askıya al'),
            ),
        ]),
      ]),
    );
  }

  // ------------------------------------------------------------- raporlar

  Widget _reports(ThemeData t) {
    final async = ref.watch(adminReportsProvider);
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _err(t, '$e'),
      data: (rows) {
        if (rows.isEmpty) return _empty(t, 'Açık rapor yok');
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: ConsoleDensity.md),
          itemBuilder: (_, i) => _reportCard(t, rows[i]),
        );
      },
    );
  }

  Widget _reportCard(ThemeData t, Map<String, dynamic> r) {
    final listing = (r['listings'] as Map?)?.cast<String, dynamic>();
    final noteCtrl = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        border: Border.all(color: t.colorScheme.outline),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${listing?['title'] ?? 'İlan'}',
                style: t.textTheme.titleSmall),
          ),
          Text('${r['reason']}'.toUpperCase(), style: t.textTheme.labelSmall),
        ]),
        if ('${r['note'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: ConsoleDensity.sm),
          Text('${r['note']}', style: t.textTheme.bodySmall),
        ],
        const SizedBox(height: ConsoleDensity.md),
        TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
              isDense: true, labelText: 'Karar notu'),
        ),
        const SizedBox(height: ConsoleDensity.md),
        Row(children: [
          FilledButton(
            onPressed: () => _resolve(r, 'hidden_by_moderation', noteCtrl.text),
            child: const Text('İlanı gizle'),
          ),
          const SizedBox(width: ConsoleDensity.md),
          OutlinedButton(
            onPressed: () => _resolve(r, 'under_review', noteCtrl.text),
            child: const Text('İncelemeye al'),
          ),
          const SizedBox(width: ConsoleDensity.md),
          TextButton(
            onPressed: () => _resolve(r, null, noteCtrl.text),
            child: const Text('Raporu reddet'),
          ),
        ]),
      ]),
    );
  }

  // ---------------------------------------------------------------- özet

  Widget _summary(ThemeData t) {
    final async = ref.watch(marketSummaryProvider);
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _err(t, '$e'),
      data: (s) => Wrap(
        spacing: ConsoleDensity.lg,
        runSpacing: ConsoleDensity.lg,
        children: [
          _stat(t, 'Yayındaki ilan', s['active'] ?? 0),
          _stat(t, 'Sıfır ürün', s['new_items'] ?? 0),
          _stat(t, 'İkinci el', s['used_items'] ?? 0),
          _stat(t, 'Satıldı', s['sold'] ?? 0),
          _stat(t, 'Onaylı mağaza', s['stores'] ?? 0),
          _stat(t, 'Açık rapor', s['open_reports'] ?? 0,
              urgent: (s['open_reports'] ?? 0) > 0),
        ],
      ),
    );
  }

  Widget _stat(ThemeData t, String label, int value, {bool urgent = false}) {
    final accent = urgent ? t.colorScheme.error : t.colorScheme.primary;
    return Container(
      width: 190,
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        border: Border.all(
            color: urgent ? accent.withValues(alpha: .35) : t.colorScheme.outline),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: t.textTheme.labelSmall),
        const SizedBox(height: ConsoleDensity.sm),
        Text('$value',
            style: t.textTheme.titleLarge
                ?.copyWith(fontSize: 28, color: urgent ? accent : null)),
      ]),
    );
  }

  // ------------------------------------------------------------- eylemler

  Future<void> _decide(String storeId, String status, String note) async {
    try {
      await Supabase.instance.client.from('stores').update({
        'status': status,
        'review_note': note.trim().isEmpty ? null : note.trim(),
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'reviewed_by': Supabase.instance.client.auth.currentUser?.id,
      }).eq('id', storeId);
      ref.invalidate(adminStoresProvider);
      _say('Kaydedildi');
    } catch (e) {
      _say('$e');
    }
  }

  Future<void> _resolve(
      Map<String, dynamic> report, String? listingStatus, String note) async {
    final c = Supabase.instance.client;
    try {
      if (listingStatus != null) {
        await c.rpc<void>('set_market_listing_status', params: {
          'p_listing': report['listing_id'],
          'p_status': listingStatus,
        });
      }
      await c.from('marketplace_reports').update({
        'status': listingStatus == null ? 'dismissed' : 'resolved',
        'decision_note': note.trim().isEmpty ? null : note.trim(),
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'reviewed_by': c.auth.currentUser?.id,
      }).eq('id', report['id']);
      ref.invalidate(adminReportsProvider);
      _say('Karar kaydedildi');
    } catch (e) {
      _say('$e');
    }
  }

  void _say(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _err(ThemeData t, String msg) => Center(
        child: SelectableText('Yüklenemedi: $msg',
            style: t.textTheme.bodySmall, textAlign: TextAlign.center),
      );

  Widget _empty(ThemeData t, String msg) =>
      Center(child: Text(msg, style: t.textTheme.bodySmall));
}

// ------------------------------------------------------------- sağlayıcılar

/// Bekleyen ve son incelenen mağaza başvuruları.
final adminStoresProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final rows = await Supabase.instance.client
      .from('stores')
      .select()
      .order('applied_at', ascending: false)
      .limit(50);
  return (rows as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
});

/// Açık raporlar — ilan başlığıyla birlikte.
final adminReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final rows = await Supabase.instance.client
      .from('marketplace_reports')
      .select('*, listings(title)')
      .inFilter('status', ['open', 'reviewing'])
      .order('created_at', ascending: false)
      .limit(50);
  return (rows as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
});

/// Sayılabilir gerçekler. Ciro ve komisyon yok: ödeme verisi olmadan
/// üretilecek her ticari sayı uydurma olurdu.
final marketSummaryProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const {};
  final c = Supabase.instance.client;

  Future<int> count(String table, void Function(dynamic q) apply) async {
    var q = c.from(table).select('id');
    apply(q);
    final rows = await q;
    return (rows as List).length;
  }

  final active = await c
      .from('listings')
      .select('id, item_condition, market_status')
      .inFilter('market_status', ['active', 'reserved']);
  final sold = await c
      .from('listings')
      .select('id')
      .eq('market_status', 'sold');
  final stores = await c.from('stores').select('id').eq('status', 'approved');
  final reports = await c
      .from('marketplace_reports')
      .select('id')
      .inFilter('status', ['open', 'reviewing']);

  final list = (active as List).map((r) => Map<String, dynamic>.from(r as Map));
  return {
    'active': list.length,
    'new_items': list.where((m) => m['item_condition'] == 'new').length,
    'used_items': list.where((m) => m['item_condition'] != 'new').length,
    'sold': (sold as List).length,
    'stores': (stores as List).length,
    'open_reports': (reports as List).length,
  };
});
