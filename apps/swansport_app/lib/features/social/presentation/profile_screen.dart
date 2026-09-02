import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_actions.dart';
import '../../../app/widgets/quick_form.dart';
import '../../athlete_workspace/presentation/widgets/athlete_profile_section.dart';
import '../../clubs/presentation/club_apply_button.dart';
import '../../clubs/presentation/invite_to_club_button.dart';
import 'edit_profile_sheet.dart';
import 'widgets/post_card.dart';
import '../../clubs/presentation/club_detail_sections.dart';
import '../../network/presentation/swan_card_sheet.dart';
import 'widgets/profile_sections.dart';
import 'widgets/management_section.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Detaylı profil sayfası — kişi veya kulüp.
///
/// Rota argümanı olarak profil/kulüp id'si alır. [isClub] true ise kulüp
/// profili gösterilir.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.id, this.isClub = false});

  final String? id;
  final bool isClub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final targetId = id ?? myId;

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

    final async = isClub
        ? ref.watch(clubSocialProfileProvider(targetId))
        : ref.watch(socialProfileProvider(targetId));
    final postsAsync = isClub
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
                    if (isClub) {
                      ref.invalidate(clubSocialProfileProvider(targetId));
                      ref.invalidate(clubPostsProvider(targetId));
                    } else {
                      ref.invalidate(socialProfileProvider(targetId));
                      ref.invalidate(authorPostsProvider(targetId));
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
                    children: [
                      _header(context, isDark, ink, surf, line, p),
                      const SizedBox(height: 14),

                      // Avatar + sayaçlar
                      Row(children: [
                        SocialAvatar(
                          initials: p.initials,
                          imageUrl: p.avatarUrl,
                          size: 82,
                          radius: 26,
                          gradientIndex: p.name.length % 4,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              SocialStat(
                                  value: p.postCount, label: 'Gönderi'),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(
                                    context, '/baglantilar',
                                    arguments: {
                                      'id': p.id,
                                      'tab': 0,
                                      'name': p.name,
                                    }),
                                child: SocialStat(
                                    value: p.followerCount, label: 'Takipçi'),
                              ),
                              if (!p.isClub)
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                      context, '/baglantilar',
                                      arguments: {
                                        'id': p.id,
                                        'tab': 1,
                                        'name': p.name,
                                      }),
                                  child: SocialStat(
                                      value: p.followingCount, label: 'Takip'),
                                ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Ad + rozet
                      Row(children: [
                        Flexible(
                          child: Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.h1(context.swan.ink)),
                        ),
                        if (p.isVerified) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(size: 18),
                        ],
                      ]),
                      if (p.username != null) ...[
                        const SizedBox(height: 2),
                        Text('@${p.username}',
                            style: SwanType.bodySm(context.swan.inkMuted)),
                      ],
                      if (p.roleLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(p.roleLabel!,
                            style: SwanType.bodySm(context.swan.accent,
                                w: FontWeight.w700)),
                      ],
                      if (p.bio != null && p.bio!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(p.bio!, style: SwanType.body(context.swan.ink)),
                      ],

                      // Doğrulanmış kimlikler
                      if (p.credentials.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: p.credentials
                              .map((c) => PremiumStatusChip(
                                    label: c,
                                    color: kTeal,
                                    icon: Icons.verified_rounded,
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Eylemler
                      _actions(context, ref, p, isDark, ink, surf, line),

                      // Kişisel şeyler kendi sayfandan açılmalı — bunlar
                      // için modül menüsüne dönmek gerekiyordu.
                      if (p.isMe) ...[
                        const SizedBox(height: 14),
                        const QuickActions(actions: [
                          // Kaydedilenler yalnızca sende görünüyor; başka
                          // kimse kimin ne kaydettiğini göremiyor.
                          QuickAction(
                              icon: Icons.bookmark_border_rounded,
                              label: 'Kaydedilenler',
                              route: '/kaydedilenler'),
                          QuickAction(
                              icon: Icons.receipt_long_rounded,
                              label: 'Aidatlarım',
                              route: '/aidatlarim'),
                          QuickAction(
                              icon: Icons.folder_rounded,
                              label: 'Belgelerim',
                              route: '/documents'),
                          QuickAction(
                              icon: Icons.verified_user_rounded,
                              label: 'Doğrulama',
                              route: '/dogrulama'),
                        ]),
                      ],

                      // Künye bölümleri: sporcuysa başarılar, antrenörse
                      // kademe/kulüpler, kulüpse kadro.
                      if (!p.isClub) ...[
                        AthleteProfileSection(profileId: p.id),
                        CoachProfileSection(profileId: p.id),
                      ] else ...[
                        // Kulüp künyesi: iletişim, teknik kadro, başarılar,
                        // sonra genel üye listesi.
                        ClubIdentitySection(clubId: p.id),
                        ClubCoachesSection(clubId: p.id),
                        ClubAchievementsSection(clubId: p.id),
                        ClubMembersSection(clubId: p.id),
                      ],

                      // Modül menüsünün ikinci yarısı buraya taşındı.
                      // Yalnızca kendi profilinde ve role göre süzülü.
                      if (p.isMe) const ManagementSection(),

                      const SizedBox(height: 22),
                      Text('Gönderiler',
                          style: SwanType.h3(context.swan.ink)),
                      const SizedBox(height: 12),

                      postsAsync.when(
                        loading: () => premiumLoading(),
                        error: (e, _) => Text('Yüklenemedi: $e',
                            style: SwanType.caption(SwanColors.textSecondary)),
                        data: (posts) {
                          if (posts.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Column(children: [
                                  Icon(Icons.photo_library_outlined,
                                      size: 32,
                                      color: SwanColors.textSecondary),
                                  const SizedBox(height: 10),
                                  Text('Henüz gönderi yok',
                                      style: SwanType.bodySm(ink, w: FontWeight.w700)),
                                ]),
                              ),
                            );
                          }
                          return Column(
                              children: posts
                                  .map((post) => PostCard(post: post))
                                  .toList());
                        },
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

  Widget _header(BuildContext context, bool isDark, Color ink, Color surf,
      Color line, SocialProfile? p) {
    return Row(children: [
      GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: line)),
          child:
              Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: ink),
        ),
      ),
      const SizedBox(width: 14),
      Text(isClub ? 'Kulüp Profili' : 'Profil',
          style: SwanType.h3(ink)),
      const Spacer(),
      // SwanSport Kartı — paylaşılabilir QR kimlik.
      if (p != null)
        GestureDetector(
          onTap: () => showSwanCard(
            context,
            id: p.id,
            name: p.name,
            isClub: isClub,
            subtitle: p.roleLabel,
            avatarUrl: p.avatarUrl,
          ),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line)),
            child: Icon(Icons.qr_code_rounded, size: 18, color: ink),
          ),
        ),
    ]);
  }

  Widget _actions(BuildContext context, WidgetRef ref, SocialProfile p,
      bool isDark, Color ink, Color surf, Color line) {
    if (p.isMe) {
      return Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final changed = await showEditProfileSheet(context, p);
              if (changed == true) {
                ref.invalidate(socialProfileProvider(p.id));
              }
            },
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line),
              ),
              child: Text('Profili Düzenle',
                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/settings'),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: line),
            ),
            child: Icon(Icons.settings_rounded, size: 19, color: ink),
          ),
        ),
      ]);
    }

    // Kulüp profilinde: takip + başvuru (+ yöneticiysen düzenle)
    if (isClub) {
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
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
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
    return Column(children: [
      Row(children: [
        Expanded(child: _FollowButton(profile: p, isClub: false)),
        const SizedBox(width: 10),
        // Brief §6 "Mesaj Gönder" diye etiketli bir eylem istiyor; burası
        // etiketsiz 46x46 bir ikondu ve ne yaptığı tahmine kalıyordu.
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
      ]),
      InviteToClubButton(profileId: p.id, personName: p.name),
    ]);
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
          borderRadius: BorderRadius.circular(14),
          border: _following ? Border.all(color: line) : null,
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
