import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../demo/demo_role.dart';

/// Haber kaynakları yönetimi — yalnızca platform yöneticisi.
///
/// Buradan eklenen RSS akışları herkesin ana sayfasında haber olarak görünür.
class RssAdminScreen extends ConsumerWidget {
  const RssAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final isAdmin = ref.watch(effectiveIsPlatformAdminProvider);
    final async = ref.watch(rssSourcesProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(rssSourcesProvider);
                await ref.read(rssSourcesProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: line)),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: ink),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PLATFORM YÖNETİCİSİ',
                              style: jakarta(
                                  10.5, FontWeight.w700, SwanColors.textSecondary,
                                  ls: 1.3)),
                          Text('Haber Kaynakları',
                              style: sora(21, FontWeight.w800, ink)),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      AddButton(onTap: () => _add(context, ref)),
                  ]),
                  const SizedBox(height: 18),

                  if (!isAdmin)
                    premiumEmpty(
                      context,
                      icon: Icons.lock_rounded,
                      title: 'Yetkin yok',
                      subtitle: 'Bu ekran yalnızca platform yöneticisine açık.',
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kTeal.withValues(alpha: .3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: kTeal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              'Eklediğin RSS akışları herkesin ana sayfasında '
                              'haber olarak görünür. Kapattığın kaynak akıştan '
                              'çıkar ama silinmez.',
                              style: jakarta(11.5, FontWeight.w500,
                                  SwanColors.textSecondary)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    async.when(
                      loading: premiumLoading,
                      error: (e, _) => premiumError(context, '$e'),
                      data: (list) {
                        if (list.isEmpty) {
                          return premiumEmpty(
                            context,
                            icon: Icons.rss_feed_rounded,
                            title: 'Kaynak yok',
                            subtitle:
                                'Sağ üstteki + ile bir RSS adresi ekle.',
                          );
                        }
                        return Column(
                            children: list
                                .map((s) => _row(context, ref, isDark, s))
                                .toList());
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: -1,
        onSelect: (_) {},
        onAction: () {},
      ),
    );
  }

  Widget _row(
      BuildContext context, WidgetRef ref, bool isDark, RssSource s) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (s.active ? kCoral : SwanColors.textSecondary)
                .withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.rss_feed_rounded,
              size: 19,
              color: s.active ? kCoral : SwanColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(13.5, FontWeight.w800, ink)),
              Text(s.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(
                      11, FontWeight.w500, SwanColors.textSecondary)),
            ],
          ),
        ),
        Switch(
          value: s.active,
          activeThumbColor: Colors.white,
          activeTrackColor: kTeal,
          onChanged: (v) async {
            await ref.read(newsServiceProvider).setActive(s.id, v);
            ref.invalidate(rssSourcesProvider);
            ref.invalidate(newsProvider);
          },
        ),
        GestureDetector(
          onTap: () => _remove(context, ref, s),
          child: Icon(Icons.delete_outline_rounded,
              size: 19, color: SwanColors.textSecondary),
        ),
      ]),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = FormField_('Kaynak adı', hint: 'TRT Spor');
    final url = FormField_('RSS adresi',
        hint: 'https://ornek.com/spor.rss', keyboard: TextInputType.url);
    final ok = await showQuickForm(
      context,
      title: 'Haber Kaynağı Ekle',
      note: 'Sitenin RSS/feed adresini gir (genelde /rss veya /feed ile biter).',
      fields: [name, url],
      onSubmit: () async {
        final u = url.value;
        if (!u.startsWith('http')) throw 'Adres http ile başlamalı';
        await ref.read(newsServiceProvider).addSource(name.value, u);
      },
    );
    if (ok == true) {
      ref.invalidate(rssSourcesProvider);
      ref.invalidate(newsProvider);
    }
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, RssSource s) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Kaynağı sil', style: sora(17, FontWeight.w800, ink)),
        content: Text('“${s.name}” kaldırılacak.',
            style: jakarta(13, FontWeight.w500, SwanColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style:
                    jakarta(13, FontWeight.w700, SwanColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sil',
                style: jakarta(13, FontWeight.w800, const Color(0xFFF43F5E))),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(newsServiceProvider).removeSource(s.id);
    ref.invalidate(rssSourcesProvider);
    ref.invalidate(newsProvider);
  }
}
