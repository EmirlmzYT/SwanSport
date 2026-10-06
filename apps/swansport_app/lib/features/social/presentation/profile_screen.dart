import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

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
    final bg = isDark ? const Color(0xFF061424) : SwanPalette.light.bg;
    final surfContainer = isDark ? const Color(0xFF132031) : const Color(0xFFF1F5F9);
    final surfHigh = isDark ? const Color(0xFF1E2B3C) : const Color(0xFFE2E8F0);
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = isDark ? const Color(0xFF293547) : SwanPalette.light.line;

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
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 130),
                    children: [
                      // Top Navigation Bar (Stitch Screen 26)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                p.username ?? p.name.toLowerCase().replaceAll(' ', ''),
                                style: GoogleFonts.sora(
                                  color: ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (p.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded,
                                    size: 17, color: kTeal),
                              ],
                              const SizedBox(width: 2),
                              Icon(Icons.expand_more_rounded,
                                  size: 18, color: SwanColors.textSecondary),
                            ],
                          ),
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
                                onTap: () => Navigator.pushNamed(context, '/settings'),
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
                                  gradient: const LinearGradient(
                                    colors: [kTealBright, kTeal],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kTeal.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                                      ? Image.network(
                                          p.avatarUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: surfHigh,
                                          alignment: Alignment.center,
                                          child: Text(
                                            p.initials,
                                            style: GoogleFonts.sora(
                                              color: kTeal,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                            ),
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
                                      color: kTeal,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: bg, width: 2),
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        size: 14, color: Color(0xFF003734)),
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
                                  _statColumn(
                                    label: 'Gönderi',
                                    value: '${p.postCount}',
                                    ink: ink,
                                    isHighlight: false,
                                  ),
                                  GestureDetector(
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
                                  ),
                                  GestureDetector(
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
                                  ),
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
                              style: GoogleFonts.sora(
                                color: ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: kTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: kTeal.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'PRO',
                              style: GoogleFonts.sora(
                                color: kTeal,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${p.username ?? p.name.toLowerCase().replaceAll(' ', '')} • ${p.roleLabel ?? 'SwanSport Sporcusu'}',
                        style: GoogleFonts.plusJakartaSans(
                          color: kTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.bio != null && p.bio!.trim().isNotEmpty
                            ? p.bio!
                            : 'SwanSport sporcusu. Henüz bir biyografi eklenmedi.',
                        style: GoogleFonts.plusJakartaSans(
                          color: SwanColors.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Profile Action Controls (Stitch Screen 26)
                      _actions(context, ref, p, isDark, ink, surfContainer, line),

                      const SizedBox(height: 18),

                      // Weekly Performance HUD (Athletic Glassmorphism - Stitch Screen 26)
                      Consumer(
                        builder: (context, ref, _) {
                          final history = ref.watch(myTrainingHistoryProvider).valueOrNull ?? const [];
                          final now = DateTime.now();
                          final sevenDaysAgo = now.subtract(const Duration(days: 7));
                          final recent = history.where((e) => e.startedAt.isAfter(sevenDaysAgo)).toList();
                          final count = recent.length;
                          final sets = recent.fold<int>(0, (sum, e) => sum + e.setsDone);
                          final totalScore = recent.fold<double>(0.0, (sum, e) => sum + (e.totalScore ?? 0.0));

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfContainer.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: line),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.bolt_rounded,
                                            size: 18, color: kTeal),
                                        const SizedBox(width: 6),
                                        Text(
                                          'HAFTALIK PERFORMANS HUD',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: kTeal,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Son 7 Gün',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: SwanColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _hudMetricCard(
                                      icon: Icons.fitness_center_rounded,
                                      iconColor: kTeal,
                                      value: '$count',
                                      label: 'Antrenman',
                                      surf: surfHigh,
                                      ink: kTeal,
                                    ),
                                    const SizedBox(width: 8),
                                    _hudMetricCard(
                                      icon: Icons.repeat_rounded,
                                      iconColor: const Color(0xFFFF8C6F),
                                      value: '$sets',
                                      label: 'Tamamlanan Set',
                                      surf: surfHigh,
                                      ink: ink,
                                    ),
                                    const SizedBox(width: 8),
                                    _hudMetricCard(
                                      icon: Icons.emoji_events_rounded,
                                      iconColor: const Color(0xFFFFD166),
                                      value: totalScore > 0 ? totalScore.toStringAsFixed(0) : '-',
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

                      // Story Highlights Carousel (Stitch Screen 26)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 2, bottom: 8),
                            child: Text(
                              'ÖNE ÇIKANLAR',
                              style: GoogleFonts.plusJakartaSans(
                                color: SwanColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 84,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _highlightItem(
                                  title: "PR'lar 🏋️‍♂️",
                                  icon: Icons.fitness_center_rounded,
                                  surfHigh: surfHigh,
                                  ink: ink,
                                ),
                                const SizedBox(width: 12),
                                _highlightItem(
                                  title: 'Yarışlar 🏁',
                                  icon: Icons.flag_rounded,
                                  surfHigh: surfHigh,
                                  ink: ink,
                                ),
                                const SizedBox(width: 12),
                                _highlightItem(
                                  title: 'Beslenme 🥑',
                                  icon: Icons.restaurant_rounded,
                                  surfHigh: surfHigh,
                                  ink: ink,
                                ),
                                const SizedBox(width: 12),
                                _highlightItem(
                                  title: 'Ekipman 👟',
                                  icon: Icons.checkroom_rounded,
                                  surfHigh: surfHigh,
                                  ink: ink,
                                ),
                                const SizedBox(width: 12),
                                _highlightItem(
                                  title: 'Q&A 💬',
                                  icon: Icons.chat_rounded,
                                  surfHigh: surfHigh,
                                  ink: ink,
                                ),
                              ],
                            ),
                          ),
                        ],
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
          style: GoogleFonts.sora(
            color: isHighlight ? kTeal : ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: SwanColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
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
              style: GoogleFonts.sora(
                color: ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: SwanColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightItem({
    required String title,
    required IconData icon,
    required Color surfHigh,
    required Color ink,
  }) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [kTeal, Color(0xFF293547)],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: surfHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: kTeal),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: ink,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
                    const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: on ? kTeal : SwanColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: on ? Colors.white : SwanColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
          style: SwanType.caption(SwanColors.textSecondary)),
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
              Icon(Icons.feed_outlined, size: 44, color: SwanColors.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'Henüz paylaşım yok',
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Antrenmanlarını, derecelerini ve spor anlarını toplulukla paylaş.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: SwanColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTeal,
                  side: const BorderSide(color: kTeal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => showPostComposer(context),
                icon: const Icon(Icons.add, size: 16),
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
          Icon(Icons.video_library_outlined, size: 44, color: SwanColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Henüz video veya klip yok',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Önemli antrenman anlarını ve hareket tekrarlarını video olarak kaydedebilirsin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: SwanColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRoutines(
      Color surfContainer, Color surfHigh, Color ink, Color line) {
    return Consumer(
      builder: (context, ref, _) {
        final protocols = ref.watch(trainingProtocolsProvider).valueOrNull ?? const [];
        if (protocols.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.bookmark_border_rounded, size: 44, color: SwanColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'Kayıtlı rutin bulunamadı',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Antrenman protokolleri ve egzersiz rutinlerini buradan takip edebilirsin.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: SwanColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTeal,
                    side: const BorderSide(color: kTeal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/antrenman-programi'),
                  icon: const Icon(Icons.explore_outlined, size: 16),
                  label: const Text('Programları Keşfet'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: protocols.take(5).map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _savedCard(
              title: p.name,
              sub: '${p.sportCode.toUpperCase()} • Protokol v${p.version}',
              icon: Icons.fitness_center_rounded,
              surfContainer: surfContainer,
              surfHigh: surfHigh,
              ink: ink,
              line: line,
            ),
          )).toList(),
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
            child: Icon(icon, size: 20, color: kTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.sora(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.plusJakartaSans(
                    color: SwanColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 18, color: kTeal),
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
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kTeal.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.edit_rounded,
                        size: 16, color: Color(0xFF003734)),
                    const SizedBox(width: 6),
                    Text(
                      'Profili Düzenle',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF003734),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
              child: const Icon(Icons.share_rounded,
                  size: 18, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/analitik'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              child: const Icon(Icons.insights_rounded,
                  size: 18, color: Colors.white70),
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
                    const Icon(Icons.edit_rounded, size: 18, color: kTeal),
                    const SizedBox(width: 8),
                    Text('Kulüp Profilini Düzenle',
                        style: SwanType.bodySm(ink, w: FontWeight.w800)),
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
                      Text('Mesaj',
                          style: SwanType.bodySm(c.ink, w: FontWeight.w800)),
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
              : const LinearGradient(colors: [kTealBright, kTeal]),
          color: _following ? surf : null,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border:
              _following ? Border.all(color: line.withValues(alpha: .5)) : null,
          boxShadow: _following
              ? null
              : [
                  BoxShadow(
                    color: kTeal.withValues(alpha: .3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_following ? Icons.check_rounded : Icons.add_rounded,
                size: 18, color: _following ? ink : Colors.white),
            const SizedBox(width: 7),
            Text(_following ? 'Takiptesin' : 'Takip Et',
                style: SwanType.bodySm(_following ? ink : Colors.white,
                    w: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

