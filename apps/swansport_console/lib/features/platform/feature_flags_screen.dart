import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';

/// Özellik bayrakları — kademeli yayın kontrolü.
///
/// Planın 1. bölümü: "Büyük özellikler doğrudan herkese açılmaz." Bu ekran
/// o kararı uygulanabilir kılıyor; bayrak olmadan "önce test kullanıcılarıyla
/// dene" bir niyet, bayrakla bir düğme.
///
/// **Bayrak güvenlik değildir.** Bir özelliği kapatmak ekranı gizler, veriyi
/// korumaz. Koruma her zaman RLS ve RPC'de — kapalı bir pazaryeri bayrağı,
/// doğrudan API çağıran birini durdurmaz.
class FeatureFlagsScreen extends ConsumerWidget {
  const FeatureFlagsScreen({super.key});

  static const _stages = [
    ('off', 'Kapalı', 'Kimse görmüyor. Geri alma da bu.'),
    ('admins', 'Yönetici', 'Yalnızca platform yöneticisi.'),
    ('testers', 'Test', 'Seçili kullanıcılar ve kulüpler.'),
    ('everyone', 'Genel', 'Herkes.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final async = ref.watch(adminFlagsProvider);

    return Padding(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Özellik bayrakları', style: t.textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.sm),
        Text(
          'Kademe sırası: Kapalı → Yönetici → Test → Genel. '
          'Bir sorun çıkarsa Kapalı\'ya çekmek geri alma yerine geçer.',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: ConsoleDensity.xl),
        Expanded(
          child: async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: SelectableText(
                'Bayraklar yüklenemedi: $e\n'
                '0053 migration çalıştırıldı mı?',
                style: t.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            data: (rows) => rows.isEmpty
                ? Center(
                    child: Text('Tanımlı bayrak yok',
                        style: t.textTheme.bodySmall))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: ConsoleDensity.md),
                    itemBuilder: (_, i) => _row(context, ref, t, rows[i]),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, ThemeData t,
      Map<String, dynamic> f) {
    final current = '${f['audience']}';

    return Container(
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        border: Border.all(color: t.colorScheme.outline),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${f['label']}', style: t.textTheme.titleSmall),
                Text('${f['key']}', style: t.textTheme.labelSmall),
              ],
            ),
          ),
          SegmentedButton<String>(
            segments: [
              for (final s in _stages)
                ButtonSegment(value: s.$1, label: Text(s.$2)),
            ],
            selected: {current},
            showSelectedIcon: false,
            onSelectionChanged: (v) =>
                _setStage(context, ref, '${f['key']}', v.first),
          ),
        ]),
        if ('${f['description'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: ConsoleDensity.sm),
          Text('${f['description']}', style: t.textTheme.bodySmall),
        ],
        const SizedBox(height: ConsoleDensity.sm),
        Text(
          _stages.firstWhere((s) => s.$1 == current,
              orElse: () => ('', '', '')).$3,
          style: t.textTheme.bodySmall,
        ),
      ]),
    );
  }

  Future<void> _setStage(BuildContext context, WidgetRef ref, String key,
      String audience) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.from('feature_flags').update({
        'audience': audience,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': Supabase.instance.client.auth.currentUser?.id,
      }).eq('key', key);
      ref.invalidate(adminFlagsProvider);
      messenger.showSnackBar(SnackBar(content: Text('$key → $audience')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

final adminFlagsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final rows = await Supabase.instance.client
      .from('feature_flags')
      .select()
      .order('key');
  return (rows as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
});
