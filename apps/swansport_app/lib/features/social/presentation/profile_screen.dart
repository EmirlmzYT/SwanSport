import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/app/widgets/swan_floating_header.dart';
import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design/swan_chrome.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/media/image_picker_sheet.dart';
import '../../../app/navigation/app_routes.dart';
import '../../../app/navigation/swan_back_navigation.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_tabs.dart';
import '../../athlete_workspace/presentation/widgets/athlete_profile_section.dart';
import '../../clubs/presentation/club_apply_button.dart';
import '../../clubs/presentation/club_detail_sections.dart';
import '../../clubs/presentation/invite_to_club_button.dart';
import 'edit_profile_sheet.dart';
import 'post_composer_sheet.dart';
import 'widgets/post_card.dart';
import 'widgets/profile_sections.dart';
import 'widgets/report_sheet.dart';
import 'widgets/swan_profile_menu_sheet.dart';

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
  int _selectedTab = 0; // Gönderiler / Hakkında
  bool _isGridView = false;
  bool _changingAvatar = false;
  bool _bioExpanded = false;

  Future<void> _changeAvatar(SocialProfile profile) async {
    if (_changingAvatar) return;
    setState(() => _changingAvatar = true);
    try {
      final image =
          await showSingleImagePicker(context, title: 'Profil fotoğrafı');
      if (image == null || !mounted) return;
      await ref.read(socialServiceProvider).updateProfile(
            avatarBytes: image.bytes,
            avatarName: image.name,
          );
      ref.invalidate(socialProfileProvider(profile.id));
      ref.invalidate(currentProfileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profil fotoğrafı kaydedilemedi. Tekrar deneyebilirsin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _changingAvatar = false);
    }
  }

  Widget _profileTopBar(SocialProfile p, Color ink) => SwanFloatingHeader(
        leading: SwanBackNavigation.shouldShow(
          context,
          fallbackRoute: widget.isClub ? AppRoutes.clubs : AppRoutes.explore,
        )
            ? SwanHeaderIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Geri dön',
                onPressed: () => SwanBackNavigation.back(
                  context,
                  fallbackRoute:
                      widget.isClub ? AppRoutes.clubs : AppRoutes.explore,
                ),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                p.username ?? p.name.toLowerCase().replaceAll(' ', ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwanType.h3(ink),
              ),
            ),
            if (p.isVerified) ...[
              const SizedBox(width: SwanSpace.xs),
              Icon(
                Icons.verified_rounded,
                size: SwanSpace.lg,
                color: context.swan.accent,
              ),
            ],
          ],
        ),
        actions: [
          if (p.isMe)
            SwanHeaderIconButton(
              icon: Icons.menu_rounded,
              tooltip: 'Profil menüsü',
              onPressed: () => showSwanProfileMenu(context, p),
            ),
          if (!p.isMe && !p.isClub)
            SwanHeaderIconButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'Profil seçenekleri',
              onPressed: () => _showVisitorOptions(p),
            ),
        ],
      );

  Future<void> _showVisitorOptions(SocialProfile profile) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Profili şikâyet et'),
              onTap: () => Navigator.pop(sheetContext, 'report'),
            ),
            ListTile(
              minTileHeight: 56,
              leading: Icon(
                Icons.block_rounded,
                color: sheetContext.swan.danger,
              ),
              title: const Text('Kullanıcıyı engelle'),
              onTap: () => Navigator.pop(sheetContext, 'block'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'report') {
      await showReportSheet(
        context,
        targetType: 'profile',
        targetId: profile.id,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kullanıcıyı engelle'),
        content: Text(
          '${profile.name} artık gönderilerini göremez ve sen de bu kullanıcının içeriklerini görmezsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(moderationServiceProvider).block(profile.id);
      ref.invalidate(hiddenProfilesProvider);
      if (mounted) Navigator.maybePop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı engellenemedi. Tekrar dene.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? context.swan.bg : SwanPalette.light.bg;
    final surfContainer = isDark ? context.swan.surface : context.swan.surface;
    final surfHigh = isDark ? context.swan.surfaceAlt : context.swan.surfaceAlt;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = isDark ? context.swan.line : SwanPalette.light.line;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final targetId = widget.id ?? myId;

    if (targetId == null) {
      return SwanScaffold(
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

    return SwanScaffold(
      extendBody: true,
      scrollUnderHeader: true,
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(SwanChrome.headerHeight),
        child: async.valueOrNull == null
            ? SwanFloatingHeader(
                leading: SwanBackNavigation.shouldShow(
                  context,
                  fallbackRoute:
                      widget.isClub ? AppRoutes.clubs : AppRoutes.explore,
                )
                    ? SwanHeaderIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Geri dön',
                        onPressed: () => SwanBackNavigation.back(
                          context,
                          fallbackRoute: widget.isClub
                              ? AppRoutes.clubs
                              : AppRoutes.explore,
                        ),
                      )
                    : null,
                title: Text('Profil', style: SwanType.h3(ink)),
              )
            : _profileTopBar(async.valueOrNull!, ink),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: async.when(
              loading: () => premiumLoading(),
              error: (e, _) => premiumError(
                context,
                e,
                onRetry: () {
                  if (widget.isClub) {
                    ref.invalidate(clubSocialProfileProvider(targetId));
                    ref.invalidate(clubPostsProvider(targetId));
                  } else {
                    ref.invalidate(socialProfileProvider(targetId));
                    ref.invalidate(authorPostsProvider(targetId));
                  }
                },
              ),
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
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SwanHeaderSpacer(),
                              const SizedBox(height: 16),

                              // Identity & Social Stats Row (Stitch Screen 26)
                              Row(
                                children: [
                                  // Kendi fotoğrafına dokunarak doğrudan değiştirebilir.
                                  Semantics(
                                    button: p.isMe && !p.isClub,
                                    label: p.isMe && !p.isClub
                                        ? 'Profil fotoğrafını değiştir'
                                        : 'Profil fotoğrafı',
                                    child: GestureDetector(
                                      onTap: p.isMe &&
                                              !p.isClub &&
                                              !_changingAvatar
                                          ? () => _changeAvatar(p)
                                          : null,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: line),
                                            ),
                                            child: ClipOval(
                                              child: p.avatarUrl != null &&
                                                      p.avatarUrl!.isNotEmpty
                                                  ? Image.network(
                                                      p.avatarUrl!,
                                                      fit: BoxFit.cover,
                                                      cacheWidth: (80 *
                                                              MediaQuery
                                                                  .devicePixelRatioOf(
                                                                context,
                                                              ))
                                                          .round(),
                                                      cacheHeight: (80 *
                                                              MediaQuery
                                                                  .devicePixelRatioOf(
                                                                context,
                                                              ))
                                                          .round(),
                                                    )
                                                  : Container(
                                                      color: surfHigh,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        p.initials,
                                                        style: SwanType.h1(
                                                          context.swan.accent,
                                                        ).copyWith(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          if (p.isMe && !p.isClub)
                                            Positioned(
                                              bottom: -2,
                                              right: -2,
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: context.swan.accent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: bg,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: _changingAvatar
                                                    ? const Padding(
                                                        padding:
                                                            EdgeInsets.all(3),
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .photo_camera_rounded,
                                                        size: 14,
                                                        color: context
                                                            .swan.onAccent,
                                                      ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Compact Numbers Matrix (Gönderi, Takipçi, Takip)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 12,
                                      ),
                                      decoration: const BoxDecoration(),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Expanded(
                                            child: _statColumn(
                                              label: 'Gönderi',
                                              value: '${p.postCount}',
                                              ink: ink,
                                              isHighlight: false,
                                            ),
                                          ),
                                          Expanded(
                                            child: GestureDetector(
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
                                          ),
                                          Expanded(
                                            child: GestureDetector(
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
                                      style: SwanType.h2(
                                        ink,
                                      ).copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${p.username ?? p.name.toLowerCase().replaceAll(' ', '')}',
                                style: SwanType.bodySm(context.swan.inkMuted),
                              ),
                              const SizedBox(height: 8),

                              if ((p.roleLabel != null &&
                                      p.roleLabel!.isNotEmpty) ||
                                  (p.primarySport != null &&
                                      p.primarySport!.trim().isNotEmpty)) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (p.roleLabel != null &&
                                        p.roleLabel!.isNotEmpty)
                                      _roleBadge(context, p.roleLabel!),
                                    if (p.primarySport != null &&
                                        p.primarySport!.trim().isNotEmpty)
                                      _sportBadge(
                                        context,
                                        p.primarySport!,
                                        p.position,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (_coachCredentials(p).isNotEmpty) ...[
                                _credentialSummaryButton(context, p),
                                const SizedBox(height: SwanSpace.xs),
                              ],
                              if (p.bio != null &&
                                  p.bio!.trim().isNotEmpty) ...[
                                const SizedBox(height: SwanSpace.xs),
                                Text(
                                  p.bio!,
                                  maxLines: _bioExpanded ? null : 3,
                                  overflow: _bioExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: SwanType.bodySm(context.swan.inkMuted),
                                ),
                                if (p.bio!.trim().length > 120)
                                  TextButton(
                                    onPressed: () => setState(
                                      () => _bioExpanded = !_bioExpanded,
                                    ),
                                    child: Text(
                                      _bioExpanded
                                          ? 'Daha az göster'
                                          : 'Devamını gör',
                                    ),
                                  ),
                              ],

                              if (_hasLinksOrContact(p)) ...[
                                const SizedBox(height: SwanSpace.xs),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _selectedTab = 1),
                                    icon: const Icon(Icons.link_rounded),
                                    label: const Text(
                                      'İletişim ve bağlantılar',
                                    ),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: SwanSpace.xs,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: SwanSpace.sm),

                              // Profile Action Controls (Stitch Screen 26)
                              _actions(
                                context,
                                ref,
                                p,
                                isDark,
                                ink,
                                surfContainer,
                                line,
                              ),

                              const SizedBox(height: 18),

                              SwanSegmentedTabs(
                                labels: const ['Gönderiler', 'Hakkında'],
                                selected: _selectedTab,
                                onSelect: (index) =>
                                    setState(() => _selectedTab = index),
                              ),
                              const SizedBox(height: SwanSpace.md),
                              if (_selectedTab == 0) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Semantics(
                                      selected: _isGridView,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.grid_on_rounded,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                          () => _isGridView = true,
                                        ),
                                        tooltip: 'Kare ızgara',
                                        style: IconButton.styleFrom(
                                          foregroundColor: _isGridView
                                              ? context.swan.accent
                                              : context.swan.inkMuted,
                                          backgroundColor: _isGridView
                                              ? context.swan.accent
                                                  .withValues(alpha: .1)
                                              : Colors.transparent,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    Semantics(
                                      selected: !_isGridView,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.view_agenda_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                          () => _isGridView = false,
                                        ),
                                        tooltip: 'Akış görünümü',
                                        style: IconButton.styleFrom(
                                          foregroundColor: !_isGridView
                                              ? context.swan.accent
                                              : context.swan.inkMuted,
                                          backgroundColor: !_isGridView
                                              ? context.swan.accent
                                                  .withValues(alpha: .1)
                                              : Colors.transparent,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_selectedTab == 0)
                        ..._buildKineticGridSlivers(
                          postsAsync,
                          ink,
                          surfHigh,
                          isMe: p.isMe,
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: _aboutContent(context, p, ink),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: SwanSpace.xl * 5),
                      ),
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

  Widget _aboutContent(BuildContext context, SocialProfile p, Color ink) {
    final c = context.swan;
    final hasSportDetails = p.primarySport?.trim().isNotEmpty == true ||
        p.position?.trim().isNotEmpty == true ||
        p.heightCm != null ||
        p.weightKg != null ||
        p.dominantSide?.trim().isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.bio?.trim().isNotEmpty == true) ...[
          Text(
            p.isClub ? 'Kulüp hakkında' : 'Tanıtım',
            style: SwanType.h3(ink),
          ),
          const SizedBox(height: SwanSpace.sm),
          Text(p.bio!, style: SwanType.body(ink)),
          const SizedBox(height: SwanSpace.xl),
        ],
        if (!p.isClub && hasSportDetails) ...[
          Text('Spor bilgileri', style: SwanType.h3(ink)),
          const SizedBox(height: SwanSpace.sm),
          Wrap(
            spacing: SwanSpace.lg,
            runSpacing: SwanSpace.sm,
            children: [
              if (p.primarySport?.trim().isNotEmpty == true)
                _aboutFact('Branş', p.primarySport!),
              if (p.position?.trim().isNotEmpty == true)
                _aboutFact('Pozisyon', p.position!),
              if (p.heightCm != null) _aboutFact('Boy', '${p.heightCm} cm'),
              if (p.weightKg != null) _aboutFact('Kilo', '${p.weightKg} kg'),
              if (p.dominantSide?.trim().isNotEmpty == true)
                _aboutFact('Baskın taraf', p.dominantSide!),
            ],
          ),
          const SizedBox(height: SwanSpace.xl),
        ],
        if (!p.isClub && _coachCredentials(p).isNotEmpty) ...[
          Text('Antrenörlük ve belgeler', style: SwanType.h3(ink)),
          const SizedBox(height: SwanSpace.sm),
          _CoachCredentialList(credentials: _coachCredentials(p)),
          const SizedBox(height: SwanSpace.xl),
        ],
        if (_hasLinksOrContact(p)) ...[
          Text('İletişim ve bağlantılar', style: SwanType.h3(ink)),
          const SizedBox(height: SwanSpace.sm),
          _socialAndContactChips(context, p),
          const SizedBox(height: SwanSpace.xl),
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
        if (p.bio?.trim().isNotEmpty != true &&
            !hasSportDetails &&
            !_hasLinksOrContact(p))
          Text(
            p.isMe
                ? 'Profil bilgilerini düzenleyerek spor kimliğini tamamlayabilirsin.'
                : 'Bu profil henüz ek bilgi paylaşmadı.',
            style: SwanType.bodySm(c.inkMuted),
          ),
      ],
    );
  }

  Widget _aboutFact(String label, String value) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: SwanType.caption(context.swan.inkMuted)),
            const SizedBox(height: SwanSpace.xs),
            Text(value, style: SwanType.bodySm(context.swan.ink)),
          ],
        ),
      );

  Widget _roleBadge(BuildContext context, String roleLabel) {
    final c = context.swan;
    final lower = roleLabel.toLowerCase();
    final IconData icon;
    if (lower.contains('yönetici') || lower.contains('admin')) {
      icon = Icons.admin_panel_settings_rounded;
    } else if (lower.contains('antrenör') || lower.contains('koç')) {
      icon = Icons.sports_rounded;
    } else if (lower.contains('sporcu') || lower.contains('oyuncu')) {
      icon = Icons.directions_run_rounded;
    } else if (lower.contains('veli')) {
      icon = Icons.family_restroom_rounded;
    } else if (lower.contains('hakem')) {
      icon = Icons.sports_handball_rounded;
    } else if (lower.contains('sağlık') || lower.contains('doktor')) {
      icon = Icons.medical_services_rounded;
    } else if (lower.contains('muhasebe')) {
      icon = Icons.receipt_long_rounded;
    } else {
      icon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: c.accent.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.accent),
          const SizedBox(width: 4.5),
          Flexible(
            child: Text(
              roleLabel,
              style: SwanType.caption(c.accent, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sportBadge(BuildContext context, String sport, String? position) {
    final c = context.swan;
    final lower = sport.toLowerCase();
    final IconData icon;
    if (lower.contains('futbol')) {
      icon = Icons.sports_soccer_rounded;
    } else if (lower.contains('basketbol')) {
      icon = Icons.sports_basketball_rounded;
    } else if (lower.contains('voleybol')) {
      icon = Icons.sports_volleyball_rounded;
    } else if (lower.contains('tenis')) {
      icon = Icons.sports_tennis_rounded;
    } else if (lower.contains('yüzme')) {
      icon = Icons.pool_rounded;
    } else if (lower.contains('koşu') || lower.contains('atletizm')) {
      icon = Icons.directions_run_rounded;
    } else if (lower.contains('fitness') || lower.contains('ağırlık')) {
      icon = Icons.fitness_center_rounded;
    } else {
      icon = Icons.sports_rounded;
    }

    final text = position != null && position.trim().isNotEmpty
        ? '$sport · $position'
        : sport;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: c.line.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.inkMuted),
          const SizedBox(width: 4.5),
          Flexible(
            child: Text(
              text,
              style: SwanType.caption(c.ink, w: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  List<SocialCredentialSummary> _coachCredentials(SocialProfile profile) {
    final unique = <String, SocialCredentialSummary>{};
    for (final credential in profile.credentialDetails) {
      if (credential.isCoach) unique[credential.id] = credential;
    }
    if (unique.isEmpty) {
      // Eski fixture/projeksiyon uyumluluğu. Canlı profil sorgusu kimlikli
      // credentialDetails üretir; düz metin yalnızca eski çağıranlar içindir.
      for (final label in profile.credentials) {
        if (!label.toLowerCase().contains('antrenör')) continue;
        unique['legacy:$label'] = SocialCredentialSummary(
          id: 'legacy:$label',
          kind: 'coach',
          sportName: label,
        );
      }
    }
    return unique.values.toList(growable: false);
  }

  Widget _credentialSummaryButton(
    BuildContext context,
    SocialProfile profile,
  ) {
    final credentials = _coachCredentials(profile);
    final label = credentials.length == 1
        ? credentials.single.detailLabel
        : '${credentials.length} antrenörlük belgesi';
    return Semantics(
      button: true,
      label: '$label, ayrıntıları aç',
      child: InkWell(
        onTap: () => _showCredentialSheet(context, credentials),
        borderRadius: BorderRadius.circular(SwanSpace.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 19,
                color: context.swan.accent,
              ),
              const SizedBox(width: SwanSpace.sm),
              Expanded(
                child: Text(
                  label,
                  style: SwanType.bodySm(
                    context.swan.ink,
                    w: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: context.swan.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCredentialSheet(
    BuildContext context,
    List<SocialCredentialSummary> credentials,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .48,
        minChildSize: .32,
        maxChildSize: .85,
        builder: (context, controller) => SafeArea(
          top: false,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(
              SwanSpace.lg,
              SwanSpace.xs,
              SwanSpace.lg,
              SwanSpace.xl,
            ),
            children: [
              Text(
                'Antrenörlük ve belgeler',
                style: SwanType.h2(context.swan.ink),
              ),
              const SizedBox(height: SwanSpace.xs),
              Text(
                'Profilde paylaşılabilen onaylı antrenörlük bilgileri.',
                style: SwanType.bodySm(context.swan.inkMuted),
              ),
              const SizedBox(height: SwanSpace.lg),
              _CoachCredentialList(credentials: credentials),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasLinksOrContact(SocialProfile p) {
    final hasIg = p.instagram != null && p.instagram!.trim().isNotEmpty;
    final hasTw = p.twitter != null && p.twitter!.trim().isNotEmpty;
    final hasWeb = p.website != null && p.website!.trim().isNotEmpty;
    final hasPhone = p.phone != null &&
        p.phone!.trim().isNotEmpty &&
        (!p.phoneHidden || p.isMe);
    return hasIg || hasTw || hasWeb || hasPhone;
  }

  Widget _socialAndContactChips(BuildContext context, SocialProfile p) {
    final c = context.swan;
    final hasIg = p.instagram != null && p.instagram!.trim().isNotEmpty;
    final hasTw = p.twitter != null && p.twitter!.trim().isNotEmpty;
    final hasWeb = p.website != null && p.website!.trim().isNotEmpty;
    final hasPhone = p.phone != null &&
        p.phone!.trim().isNotEmpty &&
        (!p.phoneHidden || p.isMe);

    String cleanHandle(String raw) {
      var s = raw.trim();
      if (s.startsWith('@')) s = s.substring(1);
      if (s.startsWith('http://') || s.startsWith('https://')) {
        final uri = Uri.tryParse(s);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.first;
        }
      }
      return s;
    }

    String cleanWeb(String raw) {
      var s = raw.trim();
      s = s.replaceFirst(RegExp(r'^https?://'), '');
      if (s.endsWith('/')) s = s.substring(0, s.length - 1);
      return s;
    }

    Future<void> launchSafe(String url) async {
      try {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (hasWeb)
          _chipItem(
            icon: Icons.link_rounded,
            label: cleanWeb(p.website!),
            c: c,
            onTap: () {
              final raw = p.website!.trim();
              final url = raw.startsWith('http') ? raw : 'https://$raw';
              launchSafe(url);
            },
          ),
        if (hasIg)
          _chipItem(
            icon: Icons.camera_alt_outlined,
            label: '@${cleanHandle(p.instagram!)}',
            c: c,
            onTap: () {
              final handle = cleanHandle(p.instagram!);
              launchSafe('https://instagram.com/$handle');
            },
          ),
        if (hasTw)
          _chipItem(
            icon: Icons.alternate_email_rounded,
            label: '@${cleanHandle(p.twitter!)}',
            c: c,
            onTap: () {
              final handle = cleanHandle(p.twitter!);
              launchSafe('https://x.com/$handle');
            },
          ),
        if (hasPhone) ...[
          _chipItem(
            icon: p.phoneHidden
                ? Icons.lock_outline_rounded
                : Icons.phone_outlined,
            label: p.phoneHidden ? '${p.phone!} (Gizli)' : p.phone!,
            c: c,
            onTap: () {
              final numClean = p.phone!.replaceAll(RegExp(r'\s+'), '');
              launchSafe('tel:$numClean');
            },
          ),
          if (!p.phoneHidden)
            _chipItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'WhatsApp',
              c: c,
              onTap: () {
                var numClean = p.phone!.replaceAll(RegExp(r'[^0-9]'), '');
                if (numClean.startsWith('0')) {
                  numClean = '90${numClean.substring(1)}';
                } else if (!numClean.startsWith('90') &&
                    numClean.length == 10) {
                  numClean = '90$numClean';
                }
                launchSafe('https://wa.me/$numClean');
              },
            ),
        ],
      ],
    );
  }

  Widget _chipItem({
    required IconData icon,
    required String label,
    required SwanPalette c,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.line.withValues(alpha: .4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c.inkMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: SwanType.caption(c.ink, w: FontWeight.w600),
            ),
          ],
        ),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SwanType.h3(
            isHighlight ? context.swan.accent : ink,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SwanType.caption(context.swan.inkMuted, w: FontWeight.w700),
        ),
      ],
    );
  }

  List<Widget> _buildKineticGridSlivers(
    AsyncValue<List<PostRow>> postsAsync,
    Color ink,
    Color surfHigh, {
    required bool isMe,
  }) {
    return postsAsync.when(
      loading: () => [
        SliverToBoxAdapter(child: premiumCardLoading()),
      ],
      error: (e, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              friendlyErrorMessage(
                e,
                defaultMessage: 'Gönderiler yüklenemedi.',
              ),
              style: SwanType.caption(context.swan.inkMuted),
            ),
          ),
        ),
      ],
      data: (posts) {
        if (posts.isNotEmpty) {
          if (_isGridView) {
            final cacheWidth =
                ((MediaQuery.sizeOf(context).width.clamp(320.0, 620.0) / 3) *
                        MediaQuery.devicePixelRatioOf(context))
                    .round();
            return [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final post = posts[i];
                      return InkWell(
                        key: ValueKey('grid_${post.id}'),
                        onTap: () => _openPostDetail(context, post),
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (post.imageUrl != null &&
                                  post.imageUrl!.isNotEmpty)
                                Image.network(
                                  post.imageUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: cacheWidth,
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Center(
                                    child: Text(
                                      post.body,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: SwanType.caption(ink),
                                    ),
                                  ),
                                ),
                              if (post.sourcePostId != null)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(
                                    Icons.repeat_rounded,
                                    size: 14,
                                    color: context.swan.onAccent
                                        .withValues(alpha: .9),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: posts.length,
                  ),
                ),
              ),
            ];
          }
          return [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => PostCard(
                    key: ValueKey('post_${posts[i].id}'),
                    post: posts[i],
                  ),
                  childCount: posts.length,
                ),
              ),
            ),
          ];
        }
        return [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.feed_outlined,
                    size: 44,
                    color: context.swan.inkMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz paylaşım yok',
                    style: SwanType.bodySm(ink, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMe
                        ? 'Spor anlarını ilk gönderinle paylaş.'
                        : 'Bu profilin gönderileri burada görünecek.',
                    textAlign: TextAlign.center,
                    style: SwanType.caption(context.swan.inkMuted),
                  ),
                  if (isMe) ...[
                    const SizedBox(height: SwanSpace.md),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.swan.accent,
                        side: BorderSide(color: context.swan.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => showPostComposer(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('İlk Gönderini Paylaş'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ];
      },
    );
  }

  void _openPostDetail(BuildContext context, PostRow post) {
    final c = context.swan;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: PostCard(post: post),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    SocialProfile p,
    bool isDark,
    Color ink,
    Color surf,
    Color line,
  ) {
    if (p.isMe) {
      return OutlinedButton.icon(
        onPressed: () async {
          final changed = await showEditProfileSheet(context, p);
          if (changed == true) ref.invalidate(socialProfileProvider(p.id));
        },
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Profili Düzenle'),
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: line),
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanRadius.md),
          ),
        ),
      );
    }

    // Kulüp profilinde: takip + başvuru (+ yöneticiysen düzenle)
    if (widget.isClub) {
      final myClub = ref.watch(activeClubProvider).valueOrNull;
      final isClubAdmin = myClub?.id == p.id && myClub?.role == 'club_admin';
      return Column(
        children: [
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
                    Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: context.swan.accent,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Kulüp Profilini Düzenle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(ink, w: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ClubApplyButton(clubId: p.id, clubName: p.name),
          const SizedBox(height: 10),
          _FollowButton(profile: p, isClub: true, secondary: true),
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
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/sohbet',
                  arguments: {'id': p.id, 'name': p.name},
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Mesaj'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.ink,
                  backgroundColor: c.surfaceAlt,
                  side: BorderSide.none,
                  minimumSize: const Size.fromHeight(48),
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
  BuildContext context,
  WidgetRef ref,
  SocialProfile p,
) async {
  final bio = FormField_(
    'Kulüp tanıtımı',
    hint: 'Kısaca kulübünü anlat',
    required: false,
  )..controller.text = p.bio ?? '';
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
class _CoachCredentialList extends StatelessWidget {
  const _CoachCredentialList({required this.credentials});

  final List<SocialCredentialSummary> credentials;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanSpace.md),
      ),
      child: Column(
        children: [
          for (var index = 0; index < credentials.length; index++) ...[
            _CoachCredentialTile(credential: credentials[index]),
            if (index != credentials.length - 1)
              Divider(height: 1, indent: SwanSpace.lg, color: c.line),
          ],
        ],
      ),
    );
  }
}

class _CoachCredentialTile extends StatelessWidget {
  const _CoachCredentialTile({required this.credential});

  final SocialCredentialSummary credential;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final statusLabel = switch (credential.status) {
      'approved' => 'Onaylandı',
      'pending' => 'İnceleniyor',
      'rejected' => 'Reddedildi',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.all(SwanSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            color: c.accent,
            semanticLabel: 'Antrenörlük belgesi',
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credential.title,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: SwanSpace.xs),
                Text(
                  credential.detailLabel,
                  style: SwanType.bodySm(c.inkMuted),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(height: SwanSpace.xs),
                  Text(
                    statusLabel,
                    style: SwanType.caption(
                      credential.status == 'approved' ? c.accent : c.inkMuted,
                      w: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({
    required this.profile,
    required this.isClub,
    this.secondary = false,
  });
  final SocialProfile profile;
  final bool isClub;
  final bool secondary;

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
      if (mounted) {
        setState(() => _following = !next);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Takip durumu güncellenemedi. Tekrar dene.'),
          ),
        );
      }
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

    final label = _following ? 'Takiptesin' : 'Takip et';
    return Semantics(
      button: true,
      selected: _following,
      label: _busy ? '$label, işlem sürüyor' : label,
      child: _following || widget.secondary
          ? OutlinedButton.icon(
              onPressed: _busy ? null : _toggle,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                backgroundColor: surf,
                side: BorderSide(color: line),
                minimumSize: const Size.fromHeight(48),
              ),
            )
          : FilledButton.icon(
              onPressed: _busy ? null : _toggle,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(label),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
    );
  }
}
