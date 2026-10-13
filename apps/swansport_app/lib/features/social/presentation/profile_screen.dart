import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_actions.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../athlete_workspace/presentation/widgets/athlete_profile_section.dart';
import '../../clubs/presentation/club_apply_button.dart';
import '../../clubs/presentation/club_detail_sections.dart';
import '../../clubs/presentation/invite_to_club_button.dart';
import '../../network/presentation/swan_card_sheet.dart';
import 'edit_profile_sheet.dart';
import 'post_composer_sheet.dart';
import 'widgets/management_section.dart';
import 'widgets/post_card.dart';
import 'widgets/profile_sections.dart';
import '../../referee/referee_widgets.dart';

/// Detaylı profil sayfası — Stitch Calm Athletic Modernism.
///
/// Sporcu, antrenör veya kulüp profili.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.id, this.isClub = false});

  final String? id;
  final bool isClub;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _selectedTab = 0; // 0: Grid, 1: Reels, 2: Saved

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? context.swan.bg : SwanPalette.light.bg;
    final surfContainer =
        isDark ? context.swan.surface : context.swan.surface;
    final surfHigh = isDark ? context.swan.surfaceAlt : context.swan.surfaceAlt;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = isDark ? context.swan.line : SwanPalette.light.line;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final targetId = widget.id ?? myId;

    if (targetId == null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: premiumEmpty(
            context,
            icon: Icons.person_off_rounded,
            title: 'Profil bulunamadı',
            subtitle: 'Bu profile ulaşılamadı.',
          ),
        ),
      );
    }

    final async = widget.isClub
        ? ref.watch(clubSocialProfileProvider(targetId))
        : ref.watch(socialProfileProvider(targetId));
    final postsAsync = widget.isClub
        ? ref.watch(clubPostsProvider(targetId))
        : ref.watch(authorPostsProvider(targetId));

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: async.when(
              loading: () => premiumLoading(),
              error: (e, _) => premiumError(context, '$e'),
              data: (p) {
                if (p == null) {
                  return premiumEmpty(
                    context,
                    icon: Icons.person_off_rounded,
                    title: 'Profil bulunamadı',
                    subtitle: 'Bu profile ulaşılamadı.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    if (widget.isClub) {
                      ref.invalidate(clubSocialProfileProvider(targetId));
                      ref.invalidate(clubPostsProvider(targetId));
                    } else {
                      ref.invalidate(socialProfileProvider(targetId));
                      ref.invalidate(authorPostsProvider(targetId));
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, SwanSpace.xl * 5),
                    children: [
                      // Top Navigation Bar (Stitch Screen 26)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Row(
                            children: [
                              Flexible(child: Text(
                                p.username ??
                                    p.name.toLowerCase().replaceAll(' ', ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.h3(ink).copyWith(fontWeight: FontWeight.w800),
                              )),
                              if (p.isVerified) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified_rounded,
                                    size: 17, color: context.swan.accent),
                              ],
                            ],
                          )),
                          Row(
                            children: [
                              _headerCircleBtn(
                                icon: Icons.qr_code_2_rounded,
                                onTap: () => showSwanCard(
                                  context,
                                  id: p.id,
                                  name: p.name,
                                  isClub: widget.isClub,
                                  subtitle: p.roleLabel,
                                  avatarUrl: p.avatarUrl,
                                ),
                                surfContainer: surfContainer,
                                ink: ink,
                              ),
                              const SizedBox(width: 8),
                              _headerCircleBtn(
                                icon: Icons.settings_rounded,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/settings'),
                                surfContainer: surfContainer,
                                ink: ink,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Identity & Social Stats Row (Stitch Screen 26)
                      Row(
                        children: [
                          // Avatar with Dynamic Cyan Halo Ring
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [context.swan.accent, context.swan.accent],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.swan.accent.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: p.avatarUrl != null &&
                                          p.avatarUrl!.isNotEmpty
                                      ? Image.network(
                                          p.avatarUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: surfHigh,
                                          alignment: Alignment.center,
                                          child: Text(
                                            p.initials,
                                            style: SwanType.h1(context.swan.accent).copyWith(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                ),
                              ),
                              if (p.isVerified)
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: context.swan.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: bg, width: 2),
                                    ),
                                    child: Icon(Icons.check_rounded,
                                        size: 14, color: context.swan.onAccent),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Compact Numbers Matrix (Gönderi, Takipçi, Takip)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                color: surfContainer.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: line),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(child: _statColumn(
                                    label: 'Gönderi',
                                    value: '${p.postCount}',
                                    ink: ink,
                                    isHighlight: false,
                                  )),
                                  Expanded(child: GestureDetector(
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/baglantilar',
                                      arguments: {
                                        'id': p.id,
                                        'tab': 0,
                                        'name': p.name,
                                      },
                                    ),
                                    child: _statColumn(
                                      label: 'Takipçi',
                                      value: '${p.followerCount}',
                                      ink: ink,
                                      isHighlight: true,
                                    ),
                                  )),
                                  Expanded(child: GestureDetector(
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/baglantilar',
                                      arguments: {
                                        'id': p.id,
                                        'tab': 1,
                                        'name': p.name,
                                      },
                                    ),
                                    child: _statColumn(
                                      label: 'Takip',
                                      value: '${p.followingCount}',
                                      ink: ink,
                                      isHighlight: false,
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Name, PRO badge, affiliation & Bio
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.h2(ink).copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${p.username ?? p.name.toLowerCase().replaceAll(' ', '')} • ${p.roleLabel ?? 'Üye'}',
                        style: SwanType.caption(context.swan.accent, w: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.bio != null && p.bio!.trim().isNotEmpty
                            ? p.bio!
                            : 'Henüz bir biyografi eklenmedi.',
                        style: SwanType.bodySm(context.swan.inkMuted),
                      ),

                      const SizedBox(height: 14),

                      // Profile Action Controls (Stitch Screen 26)
                      _actions(
                          context, ref, p, isDark, ink, surfContainer, line),

                      const SizedBox(height: 18),

                      // Weekly Performance HUD (Athletic Glassmorphism - Stitch Screen 26)
                      Consumer(
                        builder: (context, ref, _) {
                          final history = ref
                                  .watch(myTrainingHistoryProvider)
                                  .valueOrNull ??
                              const [];
                          final now = DateTime.now();
                          final sevenDaysAgo =
                              now.subtract(const Duration(days: 7));
                          final recent = history
                              .where((e) => e.startedAt.isAfter(sevenDaysAgo))
                              .toList();
                          final count = recent.length;
                          final sets =
                              recent.fold<int>(0, (sum, e) => sum + e.setsDone);
                          final totalScore = recent.fold<double>(
                              0.0, (sum, e) => sum + (e.totalScore ?? 0.0));

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfContainer.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: line),
                              boxShadow: [
                                BoxShadow(
                                  color: context.swan.shadow,
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Row(
                                      children: [
                                        Icon(Icons.bolt_rounded,
                                            size: 18, color: context.swan.accent),
                                        const SizedBox(width: 6),
                                        Flexible(child: Text(
                                          'HAFTALIK PERFORMANS HUD', maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.caption(context.swan.accent, w: FontWeight.w800),
                                        )),
                                      ],
                                    )),
                                    Flexible(child: Text(
                                      'Son 7 Gün',
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.caption(context.swan.inkMuted),
                                    )),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _hudMetricCard(
                                      icon: Icons.fitness_center_rounded,
                                      iconColor: context.swan.accent,
                                      value: '$count',
                                      label: 'Antrenman',
                                      surf: surfHigh,
                                      ink: context.swan.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    _hudMetricCard(
                                      icon: Icons.repeat_rounded,
                                      iconColor: context.swan.warning,
                                      value: '$sets',
                                      label: 'Tamamlanan Set',
                                      surf: surfHigh,
                                      ink: ink,
                                    ),
                                    const SizedBox(width: 8),
                                    _hudMetricCard(
                                      icon: Icons.emoji_events_rounded,
                                      iconColor: context.swan.warning,
                                      value: totalScore > 0
                                          ? totalScore.toStringAsFixed(0)
                                          : '-',
                                      label: 'Puan / Skor',
                                      surf: surfHigh,
                                      ink: ink,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Segmented 3-Way Tab Bar (Grid, Reels, Saved)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: surfContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: line),
                        ),
                        child: Row(
                          children: [
                            _tabBtn(
                              index: 0,
                              icon: Icons.grid_on_rounded,
                              label: 'Gönderiler',
                              surfHigh: surfHigh,
                            ),
                            _tabBtn(
                              index: 1,
                              icon: Icons.play_circle_outline_rounded,
                              label: 'Reels',
                              surfHigh: surfHigh,
                            ),
                            _tabBtn(
                              index: 2,
                              icon: Icons.bookmark_border_rounded,
                              label: 'Kayıtlar',
                              surfHigh: surfHigh,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Content Views based on Tab
                      if (_selectedTab == 0) ...[
                        // Tab 0: Kinetic 3x3 Post Grid (Stitch Screen 26)
                        _buildKineticGrid(postsAsync, ink, surfHigh),
                      ] else if (_selectedTab == 1) ...[
                        // Tab 1: Video & Reels Grid (Stitch Screen 26)
                        _buildReelsGrid(surfHigh, ink),
                      ] else ...[
                        // Tab 2: Saved Workout Routines (Stitch Screen 26)
                        _buildSavedRoutines(surfContainer, surfHigh, ink, line),
                      ],

                      // Personal & Management Sections
                      if (p.isMe) ...[
                        const SizedBox(height: 20),
                        QuickActions(actions: [
                          const QuickAction(
                              icon: Icons.bookmark_border_rounded,
                              label: 'Kaydedilenler',
                              route: '/kaydedilenler'),
                          if (ref.watch(featureEnabledProvider(
                              FeatureFlags.sportTrainingSessions)))
                            const QuickAction(
                                icon: Icons.sports_rounded,
                                label: 'Antrenmanlarım',
                                route: '/antrenmanlarim'),
                          const QuickAction(
                              icon: Icons.receipt_long_rounded,
                              label: 'Aidatlarım',
                              route: '/aidatlarim'),
                          const QuickAction(
                              icon: Icons.folder_rounded,
                              label: 'Belgelerim',
                              route: '/documents'),
                          const QuickAction(
                              icon: Icons.verified_user_rounded,
                              label: 'Doğrulama',
                              route: '/dogrulama'),
                        ]),
                      ],

                      if (!p.isClub) ...[
                        AthleteProfileSection(profileId: p.id),
                        CoachProfileSection(profileId: p.id),
                      ] else ...[
                        ClubIdentitySection(clubId: p.id),
                        ClubCoachesSection(clubId: p.id),
                        ClubAchievementsSection(clubId: p.id),
                        ClubMembersSection(clubId: p.id),
                      ],

                      if (p.isMe) const ManagementSection(),
                      if (p.isMe && !p.isClub &&
                          ref.watch(swanAccessProvider).isReferee &&
                          ref.watch(featureEnabledProvider(FeatureFlags.refereeCockpit)))
                        const RefereeEntryCard(route: '/hakem/gorevler'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _headerCircleBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color surfContainer,
    required Color ink,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: surfContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: ink),
      ),
    );
  }

  Widget _statColumn({
    required String label,
    required String value,
    required Color ink,
    required bool isHighlight,
  }) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.h3(isHighlight ? context.swan.accent : ink).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.caption(context.swan.inkMuted, w: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _hudMetricCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color surf,
    required Color ink,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: surf.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: SwanType.h3(ink).copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: SwanType.caption(context.swan.inkMuted, w: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn({
    required int index,
    required IconData icon,
    required String label,
    required Color surfHigh,
  }) {
    final on = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: on ? surfHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: context.swan.shadow,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17, color: on ? context.swan.accentFill : context.swan.inkMuted),
              const SizedBox(width: 6),
              Flexible(child: Text(
                label,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.caption(on ? context.swan.ink : context.swan.inkMuted, w: FontWeight.w700),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKineticGrid(
      AsyncValue<List<PostRow>> postsAsync, Color ink, Color surfHigh) {
    return postsAsync.when(
      loading: premiumCardLoading,
      error: (e, _) => Text('Yüklenemedi: $e',
          style: SwanType.caption(context.swan.inkMuted)),
      data: (posts) {
        if (posts.isNotEmpty) {
          return Column(
            children: posts.map((post) => PostCard(post: post)).toList(),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          alignment: Alignment.center,
          child: Column(
            children: [
              Icon(Icons.feed_outlined,
                  size: 44,
                  color: context.swan.inkMuted.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'Henüz paylaşım yok',
                style: SwanType.bodySm(ink, w: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Antrenmanlarını, derecelerini ve spor anlarını toplulukla paylaş.',
                textAlign: TextAlign.center,
                style: SwanType.caption(context.swan.inkMuted),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.swan.accent,
                  side: BorderSide(color: context.swan.accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => showPostComposer(context),
                icon: Icon(Icons.add, size: 16),
                label: const Text('İlk Gönderini Paylaş'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReelsGrid(Color surfHigh, Color ink) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.video_library_outlined,
              size: 44, color: context.swan.inkMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Henüz video veya klip yok',
            style: SwanType.bodySm(ink, w: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Önemli antrenman anlarını ve hareket tekrarlarını video olarak kaydedebilirsin.',
            textAlign: TextAlign.center,
            style: SwanType.caption(context.swan.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRoutines(
      Color surfContainer, Color surfHigh, Color ink, Color line) {
    return Consumer(
      builder: (context, ref, _) {
        final protocols =
            ref.watch(trainingProtocolsProvider).valueOrNull ?? const [];
        if (protocols.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.bookmark_border_rounded,
                    size: 44,
                    color: context.swan.inkMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'Kayıtlı rutin bulunamadı',
                  style: SwanType.bodySm(ink, w: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Antrenman protokolleri ve egzersiz rutinlerini buradan takip edebilirsin.',
                  textAlign: TextAlign.center,
                  style: SwanType.caption(context.swan.inkMuted),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.swan.accent,
                    side: BorderSide(color: context.swan.accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/antrenman-sablonlari'),
                  icon: Icon(Icons.explore_outlined, size: 16),
                  label: const Text('Programları Keşfet'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: protocols
              .take(5)
              .map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _savedCard(
                      title: p.name,
                      sub:
                          '${p.sportCode.toUpperCase()} • Protokol v${p.version}',
                      icon: Icons.fitness_center_rounded,
                      surfContainer: surfContainer,
                      surfHigh: surfHigh,
                      ink: ink,
                      line: line,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _savedCard({
    required String title,
    required String sub,
    required IconData icon,
    required Color surfContainer,
    required Color surfHigh,
    required Color ink,
    required Color line,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: surfHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: context.swan.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SwanType.caption(ink, w: FontWeight.w700),
                ),
                Text(
                  sub,
                  style: SwanType.caption(context.swan.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, size: 18, color: context.swan.accent),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, SocialProfile p,
      bool isDark, Color ink, Color surf, Color line) {
    if (p.isMe) {
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final changed = await showEditProfileSheet(context, p);
                if (changed == true) {
                  ref.invalidate(socialProfileProvider(p.id));
                }
              },
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [context.swan.accentFill, context.swan.accentFill]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.swan.accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded,
                        size: 16, color: context.swan.onAccent),
                    const SizedBox(width: 6),
                    Flexible(child: Text(
                      'Profili Düzenle',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.bodySm(context.swan.onAccent, w: FontWeight.w800),
                    )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showSwanCard(
              context,
              id: p.id,
              name: p.name,
              isClub: widget.isClub,
              subtitle: p.roleLabel,
              avatarUrl: p.avatarUrl,
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              child: Icon(Icons.share_rounded,
                  size: 18, color: context.swan.inkMuted),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/antrenmanlarim'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              child: Icon(Icons.insights_rounded,
                  size: 18, color: context.swan.inkMuted),
            ),
          ),
        ],
      );
    }

    // Kulüp profilinde: takip + başvuru (+ yöneticiysen düzenle)
    if (widget.isClub) {
      final myClub = ref.watch(activeClubProvider).valueOrNull;
      final isClubAdmin = myClub?.id == p.id && myClub?.role == 'club_admin';
      return Column(
        children: [
          _FollowButton(profile: p, isClub: true),
          const SizedBox(height: 10),
          if (isClubAdmin)
            GestureDetector(
              onTap: () => _editClub(context, ref, p),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  border: Border.all(color: line.withValues(alpha: .5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: context.swan.accent),
                    const SizedBox(width: 8),
                    Flexible(child: Text('Kulüp Profilini Düzenle',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.bodySm(ink, w: FontWeight.w800))),
                  ],
                ),
              ),
            )
          else
            ClubApplyButton(clubId: p.id, clubName: p.name),
        ],
      );
    }

    // Kişi profilinde: takip + mesaj (+ yetkiliysen kulübe davet)
    final c = context.swan;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _FollowButton(profile: p, isClub: false)),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pushNamed(context, '/sohbet',
                    arguments: {'id': p.id, 'name': p.name}),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 18, color: c.ink),
                      const SizedBox(width: 7),
                      Flexible(child: Text('Mesaj',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.bodySm(c.ink, w: FontWeight.w800))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        InviteToClubButton(profileId: p.id, personName: p.name),
      ],
    );
  }
}

/// Kulüp profilini düzenleme formu (yalnızca kulüp yöneticisi).
Future<void> _editClub(
    BuildContext context, WidgetRef ref, SocialProfile p) async {
  final bio = FormField_('Kulüp tanıtımı',
      hint: 'Kısaca kulübünü anlat', required: false)
    ..controller.text = p.bio ?? '';
  final city = FormField_('Şehir', hint: 'İstanbul', required: false)
    ..controller.text = p.roleLabel ?? '';

  final ok = await showQuickForm(
    context,
    title: 'Kulüp Profili',
    fields: [bio, city],
    onSubmit: () => ref.read(clubDataServiceProvider).updateClubProfile(
          p.id,
          bio: bio.value.isEmpty ? null : bio.value,
          city: city.value.isEmpty ? null : city.value,
        ),
  );
  if (ok == true) ref.invalidate(clubSocialProfileProvider(p.id));
}

/// Takip et / Takiptesin düğmesi — anında tepki verir.
class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.profile, required this.isClub});
  final SocialProfile profile;
  final bool isClub;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  late bool _following = widget.profile.isFollowedByMe;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_following;
    setState(() {
      _busy = true;
      _following = next;
    });
    try {
      await ref.read(socialServiceProvider).setFollow(
            widget.isClub ? 'club' : 'profile',
            widget.profile.id,
            next,
          );
      ref.invalidate(feedProvider);
    } catch (_) {
      if (mounted) setState(() => _following = !next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: _following
              ? null
              : LinearGradient(colors: [context.swan.accent, context.swan.accent]),
          color: _following ? surf : null,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border:
              _following ? Border.all(color: line.withValues(alpha: .5)) : null,
          boxShadow: _following
              ? null
              : [
                  BoxShadow(
                    color: context.swan.accent.withValues(alpha: .3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_following ? Icons.check_rounded : Icons.add_rounded,
                size: 18, color: _following ? ink : context.swan.onAccent),
            const SizedBox(width: 7),
            Flexible(child: Text(_following ? 'Takiptesin' : 'Takip Et',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.bodySm(_following ? ink : context.swan.onAccent,
                    w: FontWeight.w800))),
          ],
        ),
      ),
    );
  }
}
