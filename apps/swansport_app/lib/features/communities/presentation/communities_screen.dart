import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../social/presentation/edit_profile_sheet.dart';
import '../../social/presentation/widgets/social_widgets.dart';

/// Topluluklar — her ilin antrenörlerinin ortak sohbet grubu.
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  @override
  void initState() {
    super.initState();
    // Ekran açılınca uygun gruplara katılım tazelenir (şehir değişmiş olabilir).
    Future.microtask(() async {
      await ref.read(communityServiceProvider).ensureMine();
      if (mounted) ref.invalidate(communityListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final async = ref.watch(communityListProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(children: [
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
                    Text('Topluluklar', style: sora(22, FontWeight.w800, ink)),
                  ]),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(communityListProvider);
                      await ref.read(communityListProvider.future);
                    },
                    child: async.when(
                      loading: () => ListView(children: [premiumLoading()]),
                      error: (e, _) =>
                          ListView(children: [premiumError(context, '$e')]),
                      data: (list) {
                        if (list.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(20, 30, 20, 132),
                            children: [_emptyState(isDark)],
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _tile(isDark, list[i]),
                        );
                      },
                    ),
                  ),
                ),
              ],
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

  /// Boş durum, sebebine göre farklı: antrenör değil mi, yoksa şehri mi yok?
  Widget _emptyState(bool isDark) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final me = uid == null
        ? null
        : ref.watch(socialProfileProvider(uid)).valueOrNull;
    final hasCity = (me?.cityCode ?? '').isNotEmpty;

    if (!hasCity) {
      return Column(children: [
        premiumEmpty(
          context,
          icon: Icons.location_city_rounded,
          title: 'Şehrini seç',
          subtitle:
              'Topluluklar şehre göre kurulu. Şehrini seçince ilinin antrenör '
              'grubuna otomatik katılırsın.',
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: () async {
              if (me == null) return;
              final saved = await showEditProfileSheet(context, me);
              if (saved == true && mounted) {
                ref.invalidate(socialProfileProvider(me.id));
                await ref.read(communityServiceProvider).ensureMine();
                ref.invalidate(communityListProvider);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('Şehrimi seç',
                  style: jakarta(13, FontWeight.w800, Colors.white)),
            ),
          ),
        ),
      ]);
    }

    return premiumEmpty(
      context,
      icon: Icons.forum_outlined,
      title: 'Topluluk yok',
      subtitle:
          'Topluluklar şimdilik doğrulanmış antrenörlere açık. Antrenör '
          'kademeni doğrulattığında ilinin grubu burada görünür.',
    );
  }

  Widget _tile(bool isDark, CommunityRow c) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return GestureDetector(
      onTap: () {
        if (!c.joined) {
          _join(c);
          return;
        }
        Navigator.pushNamed(
            context, c.isFederation ? '/federasyon' : '/topluluk',
            arguments: {'id': c.id, 'name': c.name});
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
                c.isFederation ? Icons.campaign_rounded : Icons.forum_rounded,
                size: 21,
                color: kTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: jakarta(13.5, FontWeight.w700, ink)),
                const SizedBox(height: 3),
                Text(
                  c.joined
                      ? (c.lastBody?.trim().isNotEmpty == true
                          ? c.lastBody!
                          : '${c.memberCount} üye · henüz mesaj yok')
                      : 'Katılmak için dokun · ${c.memberCount} üye',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(11.5, FontWeight.w500, SwanColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!c.joined)
            Text('Katıl', style: jakarta(12, FontWeight.w800, kTeal))
          else
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (c.lastAt != null)
                Text(shortAgo(c.lastAt!),
                    style: jakarta(
                        10.5, FontWeight.w600, SwanColors.textSecondary)),
              if (c.unread > 0) ...[
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 20),
                  decoration: BoxDecoration(
                    color: kTeal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(c.unread > 99 ? '99+' : '${c.unread}',
                      textAlign: TextAlign.center,
                      style: jakarta(10, FontWeight.w800, Colors.white)),
                ),
              ],
            ]),
        ]),
      ),
    );
  }

  Future<void> _join(CommunityRow c) async {
    try {
      await ref.read(communityServiceProvider).join(c.id);
      ref.invalidate(communityListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${c.name} grubuna katıldın'),
          backgroundColor: kTeal));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Katılamadın: $e'),
          backgroundColor: const Color(0xFFF43F5E)));
    }
  }
}
