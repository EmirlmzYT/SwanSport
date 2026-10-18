import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/app/widgets/swan_floating_header.dart';
import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_chrome.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
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

  Widget _profileTopBar(SocialProfile p, Color ink) => SwanFloatingHeader(
        leading: Navigator.canPop(context)
            ? SwanHeaderIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Geri dön',
                onPressed: () => Navigator.maybePop(context),
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
        ],
      );

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
      appBar: async.valueOrNull == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(SwanChrome.headerHeight),
              child: _profileTopBar(async.valueOrNull!, ink),
            ),
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
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      SwanSpace.xl * 5,
                    ),
                    children: [
                      const SwanHeaderSpacer(),
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
                                  border: Border.all(color: line),
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
                                            style: SwanType.h1(
                                              context.swan.accent,
                                            ).copyWith(
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
                                      color: context.swan.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: bg, width: 2),
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: context.swan.onAccent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Compact Numbers Matrix (Gönderi, Takipçi, Takip)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: surfContainer.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: line),
                              ),
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
                      const SizedBox(height: 3),
                      Text(
                        '@${p.username ?? p.name.toLowerCase().replaceAll(' ', '')} • ${p.roleLabel ?? 'Üye'}',
                        style: SwanType.caption(
                          context.swan.accent,
                          w: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.bio != null && p.bio!.trim().isNotEmpty
                            ? p.bio!
                            : 'Henüz bir biyografi eklenmedi.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(context.swan.inkMuted),
                      ),

                      const SizedBox(height: 14),

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
                      if (_selectedTab == 0)
                        _buildKineticGrid(
                          postsAsync,
                          ink,
                          surfHigh,
                          isMe: p.isMe,
                        )
                      else ...[
                        Text('Profil bilgileri', style: SwanType.h3(ink)),
                        const SizedBox(height: SwanSpace.sm),
                        Text(
                          p.roleLabel ?? 'Üye',
                          style: SwanType.bodySm(context.swan.inkMuted),
                        ),
                        if (p.bio != null && p.bio!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: SwanSpace.md,
                            ),
                            child: Text(p.bio!, style: SwanType.body(ink)),
                          ),
                        if (!p.isClub) ...[
                          AthleteProfileSection(profileId: p.id),
                          CoachProfileSection(profileId: p.id),
                        ] else ...[
                          ClubIdentitySection(clubId: p.id),
                          ClubCoachesSection(clubId: p.id),
                          ClubAchievementsSection(clubId: p.id),
                          ClubMembersSection(clubId: p.id),
                        ],
                      ],
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

  Widget _buildKineticGrid(
    AsyncValue<List<PostRow>> postsAsync,
    Color ink,
    Color surfHigh, {
    required bool isMe,
  }) {
    return postsAsync.when(
      loading: premiumCardLoading,
      error: (e, _) => Text(
        'Yüklenemedi: $e',
        style: SwanType.caption(context.swan.inkMuted),
      ),
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
        );
      },
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
                onTap: () => Navigator.pushNamed(
                  context,
                  '/sohbet',
                  arguments: {'id': p.id, 'name': p.name},
                ),
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
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: c.ink,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Mesaj',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.bodySm(c.ink, w: FontWeight.w800),
                        ),
                      ),
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
              : LinearGradient(
                  colors: [context.swan.accent, context.swan.accent],
                ),
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
            Icon(
              _following ? Icons.check_rounded : Icons.add_rounded,
              size: 18,
              color: _following ? ink : context.swan.onAccent,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                _following ? 'Takiptesin' : 'Takip Et',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwanType.bodySm(
                  _following ? ink : context.swan.onAccent,
                  w: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
