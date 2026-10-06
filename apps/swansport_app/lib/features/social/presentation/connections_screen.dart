import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';
import 'widgets/social_widgets.dart';

/// Takipçiler / takip edilenler / kulüp üyeleri listesi (Stitch Calm Athletic Modernism).
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
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _followingState = <String>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleFollow(SuggestionRow item) {
    final currentlyFollowing = _isFollowing(item);
    final next = !currentlyFollowing;

    setState(() {
      if (next) {
        _followingState.add(item.id);
      } else {
        _followingState.remove(item.id);
      }
    });

    unawaited(
      ref.read(socialServiceProvider).setFollow(
            item.targetType,
            item.id,
            next,
          ),
    );
  }

  bool _isFollowing(SuggestionRow item) {
    if (_tab == 1) {
      // In 'following' tab, initially everyone is followed unless toggled off
      return !_followingState.contains(item.id);
    }
    // In 'followers' tab, tracked in set
    return _followingState.contains(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    final followersAsync = ref.watch(followersProvider(widget.profileId));
    final followingAsync = ref.watch(followingProvider(widget.profileId));

    final currentAsync = _tab == 0 ? followersAsync : followingAsync;
    final followersCount = followersAsync.valueOrNull?.length ?? 0;
    final followingCount = followingAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md, SwanSpace.lg, SwanSpace.xs),
                  child: SwanPageHeader(
                    title: widget.title ?? 'Bağlantılar',
                    subtitle: 'Takipçileri ve spor ağını yönet',
                    onBack: () => Navigator.maybePop(context),
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg, vertical: SwanSpace.xs),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: c.inkMuted, size: 20),
                        const SizedBox(width: SwanSpace.xs),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                            style: SwanType.body(c.ink),
                            decoration: InputDecoration(
                              hintText: 'Bağlantılarda ara...',
                              hintStyle: SwanType.bodySm(c.inkMuted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: Icon(Icons.close_rounded, size: 16, color: c.inkMuted),
                          ),
                      ],
                    ),
                  ),
                ),

                // Horizontal Pill Tabs
                const SizedBox(height: SwanSpace.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: Row(
                    children: [
                      _buildPillTab(c, 'Takipçiler', followersCount, 0),
                      const SizedBox(width: SwanSpace.xs),
                      _buildPillTab(c, 'Takip Edilen', followingCount, 1),
                    ],
                  ),
                ),

                // Context Strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md, SwanSpace.lg, SwanSpace.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _tab == 0
                            ? 'SON HAREKETLER • TOPLAM $followersCount KİŞİ'
                            : 'TAKİP EDİLENLER • TOPLAM $followingCount KİŞİ',
                        style: SwanType.caption(c.inkMuted, w: FontWeight.w800),
                      ),
                      Row(
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 16, color: c.accent),
                          const SizedBox(width: 2),
                          Text('Sırala', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Dynamic List
                Expanded(
                  child: currentAsync.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      final filtered = list.where((r) {
                        if (_query.isEmpty) return true;
                        final matchName = r.name.toLowerCase().contains(_query);
                        final matchSub = (r.subtitle ?? '').toLowerCase().contains(_query);
                        return matchName || matchSub;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(SwanSpace.xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: c.surfaceAlt,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.people_outline_rounded, color: c.inkMuted, size: 28),
                                ),
                                const SizedBox(height: SwanSpace.md),
                                Text(
                                  _tab == 0 ? 'Henüz takipçi yok' : 'Henüz kimse takip edilmiyor',
                                  style: SwanType.h3(c.ink),
                                ),
                                const SizedBox(height: SwanSpace.xs),
                                Text(
                                  _tab == 0
                                      ? 'Paylaşım yaptıkça ve kulüp aktivitelerine katıldıkça takipçiler gelir.'
                                      : 'Keşfet sekmesinden kulüp ve antrenörleri bulup takip edebilirsin.',
                                  textAlign: TextAlign.center,
                                  style: SwanType.caption(c.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.xs, SwanSpace.lg, 132),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: SwanSpace.sm),
                        itemBuilder: (_, i) => _buildConnectionCard(c, filtered[i]),
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

  Widget _buildPillTab(SwanPalette c, String label, int count, int index) {
    final on = _tab == index;
    return InkWell(
      onTap: () => setState(() => _tab = index),
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c.accentFill : c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: SwanType.caption(
                on ? Colors.white : c.inkMuted,
                w: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: on ? Colors.white.withValues(alpha: .22) : c.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: SwanType.caption(
                  on ? Colors.white : c.inkMuted,
                  w: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(SwanPalette c, SuggestionRow item) {
    final isFollowing = _isFollowing(item);

    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              SocialAvatar(
                initials: item.initials,
                imageUrl: item.avatarUrl,
                size: 50,
                gradientIndex: item.name.length % 4,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.body(c.ink, w: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.verified_rounded, size: 16, color: c.accent),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle ?? (item.kind == 'coach' ? 'Antrenör • Marmara Okçuluk' : 'Makaralı / Klasik Yay'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(c.inkMuted),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.military_tech_rounded, size: 12, color: c.accent),
                      const SizedBox(width: 3),
                      Text(
                        'Lisanslı Sporcu',
                        style: SwanType.caption(c.accent, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SwanSpace.sm),
          InkWell(
            onTap: () => _toggleFollow(item),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isFollowing ? c.surfaceAlt : c.accentFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isFollowing ? c.line : c.accent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isFollowing) ...[
                    const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    isFollowing ? 'Takip Ediliyor' : 'Geri Takip Et',
                    style: SwanType.caption(
                      isFollowing ? c.ink : Colors.white,
                      w: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
