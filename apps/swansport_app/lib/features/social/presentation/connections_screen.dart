import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_tabs.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Takipçiler / takip edilenler listesi.
///
/// Rota argümanı: `{'id': profilId, 'tab': 0|1, 'name': ad}`.
class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({
    super.key,
    required this.profileId,
    this.initialTab = 0,
    this.title,
  });

  final String profileId;
  final int initialTab;
  final String? title;

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final async = _tab == 0
        ? ref.watch(followersProvider(widget.profileId))
        : ref.watch(followingProvider(widget.profileId));

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
                    Expanded(
                      child: Text(widget.title ?? 'Bağlantılar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sora(20, FontWeight.w800, ink)),
                    ),
                  ]),
                ),

                // Sekmeler
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SwanSegmentedTabs(
                    labels: const ['Takipçiler', 'Takip Edilenler'],
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ),

                Expanded(
                  child: async.when(
                    loading: () => premiumLoading(),
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.people_outline_rounded,
                          title: _tab == 0
                              ? 'Henüz takipçi yok'
                              : 'Henüz kimse takip edilmiyor',
                          subtitle: _tab == 0
                              ? 'Paylaşım yaptıkça takipçiler gelir.'
                              : 'Aramadan kulüp ve sporcu bulabilirsin.',
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }


  Widget _tile(bool isDark, SuggestionRow r) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        r.isClub ? '/kulup-profil' : '/profil',
        arguments: r.id,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          SocialAvatar(
              initials: r.initials,
              imageUrl: r.avatarUrl,
              size: 44,
              gradientIndex: r.name.length % 4),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(13.5, FontWeight.w800, ink)),
                if (r.subtitle != null)
                  Text(r.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(
                          11.5, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }
}
