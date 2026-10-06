import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/shared_content_card.dart';
import '../../../app/push/push_service.dart';
import '../../../app/widgets/premium.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Sohbet listesi — gruplar ve birebir sohbetler tek akışta (Google Stitch Screen 21).
///
/// Google Stitch "SwanSport - Mesajlar & Antrenman Grupları" tasarımını uygular:
/// - Canlı Kulvar (Aktif sporcular / Story rayı)
/// - Segment kategori filtreleri (Tüm Mesajlar, Antrenörler, Kulüp Grupları)
/// - Sabitlenmiş Koç Kartı & Antrenman Grupları
/// - Toplu Antrenman Odası Hızlı Aksiyon Kartı
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _Entry {
  const _Entry.group(CommunityRow this.group) : dm = null;
  const _Entry.dm(ConversationRow this.dm) : group = null;

  final CommunityRow? group;
  final ConversationRow? dm;

  DateTime? get at => group?.lastAt ?? dm?.lastAt;
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _selectedFilter = 0; // 0 = Tüm Mesajlar, 1 = Antrenörler, 2 = Kulüp Grupları

  final List<String> _filters = const ['Tüm Mesajlar', 'Antrenörler', 'Kulüp Grupları'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(communityServiceProvider).ensureMine();
      if (mounted) ref.invalidate(communityListProvider);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    ref.listen(dmChangesProvider, (_, next) {
      if (next is AsyncData) ref.invalidate(conversationsProvider);
    });

    final dms = ref.watch(conversationsProvider);
    final groups = ref.watch(communityListProvider).valueOrNull ?? const [];

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              color: c.accent,
              backgroundColor: c.surface,
              onRefresh: () async {
                ref.invalidate(conversationsProvider);
                ref.invalidate(communityListProvider);
                await ref.read(conversationsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
                children: [
                  _buildHeader(c),
                  const SizedBox(height: SwanSpace.sm),

                  _buildSearchField(c),
                  const SizedBox(height: SwanSpace.md),

                  if (_query.isEmpty) ...[
                    _buildActiveAthletesReel(c),
                    const SizedBox(height: SwanSpace.sm),
                  ],

                  _buildCategoryFilters(c),
                  const SizedBox(height: SwanSpace.sm),

                  // Dynamic list or curated Stitch chat roster
                  dms.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(SwanSpace.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) => _buildChatRoster(c, list, groups),
                  ),

                  if (_query.isEmpty) ...[
                    const SizedBox(height: SwanSpace.md),
                    _buildQuickCourtsideCard(c),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SwanSpace.md, SwanSpace.sm, SwanSpace.md, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İLETİŞİM & KOÇLUK',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: c.accent,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'Mesajlar',
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.tune_rounded, size: 20, color: c.inkMuted),
                style: IconButton.styleFrom(backgroundColor: c.surfaceAlt),
                tooltip: 'Filtreler',
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/ara'),
                icon: const Icon(Icons.edit_square, size: 16, color: Colors.black),
                label: const Text('Yeni Sohbet'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          style: SwanType.bodySm(c.ink),
          decoration: InputDecoration(
            hintText: 'Sporcu, antrenör veya kulüp ara...',
            hintStyle: SwanType.bodySm(c.inkMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.inkMuted),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveAthletesReel(SwanPalette c) {
    final athletes = [
      (
        name: 'Mert Koç',
        avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop',
        badge: '⚡',
        isCoach: true,
      ),
      (
        name: 'Selin K.',
        avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200&auto=format&fit=crop',
        badge: '🏃‍♂️',
        isCoach: false,
      ),
      (
        name: 'Bora C.',
        avatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=200&auto=format&fit=crop',
        badge: '💪',
        isCoach: false,
      ),
      (
        name: 'Derya N.',
        avatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=200&auto=format&fit=crop',
        badge: '🏊‍♀️',
        isCoach: false,
      ),
      (
        name: 'Caner T.',
        avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=200&auto=format&fit=crop',
        badge: '🚴',
        isCoach: false,
      ),
      (
        name: 'Melis E.',
        avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=200&auto=format&fit=crop',
        badge: '🧘',
        isCoach: false,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Canlı Kulvar (6 Sporcu)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
              Text(
                'Tümü',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
            scrollDirection: Axis.horizontal,
            itemCount: athletes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final a = athletes[i];
              return InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/sohbet', arguments: {
                    'id': 'mert-koc-demo',
                    'name': a.name,
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: a.isCoach ? c.accent : c.surfaceAlt,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              a.avatar,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: c.surfaceAlt,
                                child: Icon(Icons.person, color: c.inkMuted),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: c.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Text(a.badge, style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Row(
          children: _filters.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            final isSelected = _selectedFilter == idx;

            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedFilter = idx),
                borderRadius: BorderRadius.circular(SwanRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? Colors.black : c.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChatRoster(SwanPalette c, List<ConversationRow> dms, List<CommunityRow> groups) {
    final entries = <_Entry>[
      for (final g in groups.where((g) => g.joined)) _Entry.group(g),
      for (final dm in dms) _Entry.dm(dm),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Column(
        children: [
          // Pinned Coach Mert Koç Priority Tile (Stitch Screen 21 Feature)
          if (_selectedFilter == 0 || _selectedFilter == 1)
            _buildPinnedCoachTile(c),

          // Community Group Tile: Swan Runners Kadıköy (Stitch Screen 21 Feature)
          if (_selectedFilter == 0 || _selectedFilter == 2)
            _buildClubGroupTile(c),

          // Stitch Curated Row: Selin Kaya
          if (_selectedFilter == 0)
            _buildCuratedChatTile(
              c,
              name: 'Selin Kaya',
              avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200&auto=format&fit=crop',
              time: 'Dün',
              message: 'Tebrikler: 82 Günlük seri harika gidiyor! 🔥',
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFFFB6A4),
            ),

          // Stitch Curated Row: Bora Calisthenics
          if (_selectedFilter == 0)
            _buildCuratedChatTile(
              c,
              name: 'Bora Calisthenics',
              avatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=200&auto=format&fit=crop',
              time: '2 gün önce',
              message: 'Kas gücü antrenman videosunu paylaştı (0:48)',
              icon: Icons.videocam_rounded,
              iconColor: c.accent,
            ),

          // Real Supabase dynamic entries
          for (final e in entries)
            if (e.group != null && (_selectedFilter == 0 || _selectedFilter == 2))
              _buildRealGroupTile(c, e.group!)
            else if (e.dm != null && (_selectedFilter == 0 || _selectedFilter == 1))
              _buildRealDmTile(c, e.dm!),
        ],
      ),
    );
  }

  Widget _buildPinnedCoachTile(SwanPalette c) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/sohbet', arguments: {
            'id': 'mert-koc-demo',
            'name': 'Mert Koç',
          });
        },
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: const NetworkImage(
                    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop',
                  ),
                  backgroundColor: c.surfaceAlt,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Mert Koç',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'KUVVET KOÇU',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: c.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text('12:45', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Yarınki squat seansında ağırlığı 5kg artırıyoruz 💪',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                  child: const Center(
                    child: Text('2', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.push_pin_rounded, size: 14, color: c.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubGroupTile(SwanPalette c) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/kulup-detay');
        },
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Icon(Icons.groups_rounded, size: 26, color: c.accent),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                    child: Icon(Icons.verified_rounded, size: 12, color: c.accent),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Swan Runners Kadıköy',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '28 Üye',
                              style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      Text('11:20', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Caner: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.accent,
                          ),
                        ),
                        TextSpan(
                          text: 'Sabah 06:30 sahil koşusu için toplanıyoruz! 👟',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuratedChatTile(
    SwanPalette c, {
    required String name,
    required String avatar,
    required String time,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/sohbet', arguments: {
            'id': name,
            'name': name,
          });
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: NetworkImage(avatar),
              backgroundColor: c.surfaceAlt,
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      Text(time, style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          message,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: c.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealGroupTile(SwanPalette c, CommunityRow g) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          g.isFederation ? '/federasyon' : '/topluluk',
          arguments: {'id': g.id, 'name': g.name},
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Icon(
                g.isFederation ? Icons.campaign_rounded : Icons.forum_rounded,
                size: 24,
                color: c.accent,
              ),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(g.name, style: SwanType.body(c.ink, w: FontWeight.w700)),
                      if (g.lastAt != null)
                        Text(shortAgo(g.lastAt!), style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    g.lastBody?.trim().isNotEmpty == true
                        ? g.lastBody!
                        : '${g.memberCount} üye',
                    style: SwanType.caption(c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealDmTile(SwanPalette c, ConversationRow dm) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/sohbet', arguments: {
          'id': dm.otherId,
          'name': dm.otherName,
        }),
        child: Row(
          children: [
            SocialAvatar(
              initials: dm.initials,
              imageUrl: dm.otherAvatarUrl,
              size: 52,
              gradientIndex: dm.otherName.length % 4,
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dm.otherName, style: SwanType.body(c.ink, w: FontWeight.w700)),
                      Text(shortAgo(dm.lastAt), style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dm.lastBody,
                    style: SwanType.caption(c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (dm.unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(999)),
                child: Text('${dm.unread}', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCourtsideCard(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Container(
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Icon(Icons.fitness_center_rounded, size: 20, color: c.accent),
                ),
                const SizedBox(width: SwanSpace.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toplu Antrenman Odası',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      'Bu akşam 19:30 · 14 sporcu katılıyor',
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Toplu Antrenman Odasına katılımınız kaydedildi.')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.sm)),
              ),
              child: Text(
                'Katıl',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Birebir sohbet ekranı (Google Stitch Screen 22).
///
/// Google Stitch "SwanSport - Sohbet Detayı (Mert Koç)" tasarımını uygular:
/// - Instagram DM / Sporcu sohbet üst çubuğu
/// - Özel Antrenman Planı Kartı (A2 Kuvvet & Mobilite, RPE 8.5)
/// - Sesli Antrenör Mesajı & Simüle Dalga Formu
/// - Hızlı Etkileşim Hapları (Form Analizi İste, RPE Günlüğü, Makro Özeti)
/// - Medya, Antrenman ve Ses Kayıt Giriş Alanı
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.otherId, required this.otherName});

  final String otherId;
  final String otherName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<MessageRow> _pending = [];
  final Set<String> _marked = {};
  bool _perMessageMarkUnavailable = false;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    OpenChat.open(widget.otherId, widget.otherName);
    Future.microtask(() async {
      await ref.read(notificationServiceProvider).markConversationRead(widget.otherId);
      if (mounted) ref.invalidate(conversationsProvider);
    });
  }

  @override
  void dispose() {
    OpenChat.close(widget.otherId);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _markVisible(List<MessageRow> list) {
    final ids = list
        .where((m) => !m.isMine && !m.isRead && !_marked.contains(m.id))
        .map((m) => m.id)
        .toList();
    if (ids.isEmpty) return;
    _marked.addAll(ids);
    final svc = ref.read(notificationServiceProvider);

    Future.microtask(() async {
      try {
        if (_perMessageMarkUnavailable) {
          await svc.markConversationRead(widget.otherId);
        } else {
          await svc.markMessagesRead(ids);
        }
        if (mounted) ref.invalidate(conversationsProvider);
      } catch (_) {
        if (_perMessageMarkUnavailable) return;
        _perMessageMarkUnavailable = true;
        try {
          await svc.markConversationRead(widget.otherId);
          if (mounted) ref.invalidate(conversationsProvider);
        } catch (_) {}
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await _deliver(text);
  }

  Future<void> _deliver(String text, {String? retryId}) async {
    final id = retryId ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _pending
        ..removeWhere((m) => m.id == id)
        ..add(MessageRow(
          id: id,
          body: text,
          createdAt: DateTime.now(),
          isMine: true,
          status: MessageStatus.sending,
        ));
    });
    _scrollToEnd();

    try {
      await ref.read(notificationServiceProvider).send(widget.otherId, text);
      if (mounted) setState(() => _pending.removeWhere((m) => m.id == id));
      ref.invalidate(conversationsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _pending.indexWhere((m) => m.id == id);
        if (i >= 0) {
          _pending[i] = _pending[i].copyWith(status: MessageStatus.failed);
        }
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final async = ref.watch(chatProvider(widget.otherId));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                _buildChatHeader(c),
                Expanded(
                  child: async.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      _markVisible(list);
                      final all = [...list, ..._pending];

                      return ListView(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        children: [
                          // Pending / dynamic messages
                          for (int i = 0; i < all.length; i++)
                            _bubble(c, all[all.length - 1 - i]),

                          // Stitch Curated Message Stream Items for Coach Mert
                          _buildStitchCoachConversation(c),
                        ],
                      );
                    },
                  ),
                ),

                // Interactive Quick Chips Row
                _buildQuickActionChips(c),

                // Bottom Message Input Bar
                _buildInputBar(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.sm, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: c.ink),
                tooltip: 'Geri',
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: const NetworkImage(
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop',
                    ),
                    backgroundColor: c.surfaceAlt,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.otherName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 14, color: c.accent),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Kuvvet Koçu • Çevrim İçi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sesli arama başlatılıyor...')),
                  );
                },
                icon: Icon(Icons.call_rounded, size: 20, color: c.ink),
                tooltip: 'Ara',
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Görüntülü arama başlatılıyor...')),
                  );
                },
                icon: Icon(Icons.videocam_rounded, size: 22, color: c.ink),
                tooltip: 'Görüntülü Ara',
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/profil', arguments: widget.otherId),
                icon: Icon(Icons.info_outline_rounded, size: 20, color: c.ink),
                tooltip: 'Profil',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStitchCoachConversation(SwanPalette c) {
    return Column(
      children: [
        // Date divider
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'BUGÜN',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: c.inkMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),

        // Message 1 from Coach
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selam Emir! Dünkü 180kg deadlift form videonu inceledim. Bar hızın harikaydı, bel kilitlemen çok temizdi 🔥',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4, color: c.ink),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text('10:42', style: SwanType.caption(c.inkMuted)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Workout Recommendation Card
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SwanRadius.lg),
              border: Border.all(color: c.accent.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fitness_center_rounded, size: 16, color: c.accent),
                        const SizedBox(width: 6),
                        Text(
                          'ÖZEL ANTRENMAN PLANI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: c.accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Yarın', style: SwanType.caption(c.inkMuted)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'A2 Kuvvet & Mobilite',
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink),
                ),
                Text(
                  'Squat 5×5 @ 140kg • Bench 4×8 @ 100kg',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.inkMuted),
                ),
                const SizedBox(height: 10),

                // Target summary grid
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 16, color: c.accent),
                            const SizedBox(width: 4),
                            Text('65 Dakika', style: SwanType.caption(c.ink, w: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFFB6A4)),
                            const SizedBox(width: 4),
                            Text('RPE 8.5 Hedef', style: SwanType.caption(c.ink, w: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/antrenman-oturumu'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.black),
                  label: Text(
                    'Antrenmanı İncele',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    minimumSize: const Size(double.infinity, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.sm)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // User outgoing message
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTealBright, kTeal]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teşekkürler hocam! Yarın squat seansında kemersiz denemeyi düşünüyorum, ne dersin?',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4, color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Text('10:45', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    SizedBox(width: 4),
                    Icon(Icons.done_all_rounded, size: 14, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Audio Message from Coach
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: c.accent,
                  child: IconButton(
                    onPressed: () => setState(() => _isPlayingAudio = !_isPlayingAudio),
                    icon: Icon(
                      _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (int b = 0; b < 16; b++)
                            Container(
                              width: 3,
                              height: 6.0 + ((b * 7) % 18),
                              decoration: BoxDecoration(
                                color: b < 7 ? c.accent : c.inkMuted.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_isPlayingAudio ? '0:14' : '0:00', style: SwanType.caption(c.inkMuted)),
                          Text('0:24', style: SwanType.caption(c.inkMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildQuickActionChips(SwanPalette c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 6),
      child: Row(
        children: [
          _buildActionChip(c, 'Form Analizi İste +', Icons.video_library_rounded, () {
            Navigator.pushNamed(context, '/antrenman-sonuc');
          }),
          const SizedBox(width: 6),
          _buildActionChip(c, 'RPE Günlüğü Paylaş', Icons.insert_chart_rounded, () {
            Navigator.pushNamed(context, '/hazirbulunusluk');
          }),
          const SizedBox(width: 6),
          _buildActionChip(c, 'Makro Özeti', Icons.restaurant_rounded, () {
            Navigator.pushNamed(context, '/beslenme');
          }),
        ],
      ),
    );
  }

  Widget _buildActionChip(SwanPalette c, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c.accent),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(SwanSpace.md, 6, SwanSpace.md, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.add_photo_alternate_rounded, size: 20, color: c.inkMuted),
            tooltip: 'Görsel ekle',
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.attachment_rounded, size: 20, color: c.inkMuted),
            tooltip: 'Antrenman bağla',
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              style: SwanType.bodySm(c.ink),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Mesaj yaz veya antrenman ekle...',
                hintStyle: SwanType.bodySm(c.inkMuted),
                filled: true,
                fillColor: c.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.mic_rounded, size: 20, color: c.inkMuted),
            tooltip: 'Ses kaydet',
          ),
          InkWell(
            onTap: _send,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(SwanPalette c, MessageRow m) {
    return Align(
      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: m.status == MessageStatus.failed ? () => _deliver(m.body, retryId: m.id) : null,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: m.isMine ? const LinearGradient(colors: [kTealBright, kTeal]) : null,
            color: m.isMine ? null : c.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(m.isMine ? 16 : 4),
              bottomRight: Radius.circular(m.isMine ? 4 : 16),
            ),
            border: m.isMine ? null : Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.isShare && m.sharedId != null)
                SharedContentCard(
                  kind: m.sharedKind ?? m.contentType,
                  id: m.sharedId!,
                  onDark: m.isMine,
                ),
              if (m.body.isNotEmpty)
                Text(
                  m.body,
                  style: SwanType.bodySm(m.isMine ? Colors.white : c.ink).copyWith(height: 1.35),
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.status == MessageStatus.failed
                        ? 'Gönderilemedi · dokun, tekrar dene'
                        : shortAgo(m.createdAt),
                    style: SwanType.caption(m.isMine ? Colors.white70 : c.inkMuted, w: FontWeight.w600),
                  ),
                  if (m.isMine) ...[
                    const SizedBox(width: 5),
                    _tick(m),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tick(MessageRow m) => switch (m.status) {
        MessageStatus.sending => const SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(strokeWidth: 1.4, color: Colors.white70),
          ),
        MessageStatus.failed => const Icon(Icons.refresh_rounded, size: 13, color: Colors.white),
        MessageStatus.sent => Icon(
            m.isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 13,
            color: m.isRead ? Colors.white : Colors.white60,
          ),
      };
}
