import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import 'configuration_module_args.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Kulüp Yapılandırma.
///
/// Eskiden altı süslü satırdan ibaretti ve hiçbirine dokunulamıyordu. Artık
/// gerçekten yapılandırılabilen üç şey var: kulübün kimliği, kimin hangi rolde
/// olduğu ve sezonlar. Gerisi ilgili ekranlara kısayol.
class ConfigurationScreen extends ConsumerStatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  ConsumerState<ConfigurationScreen> createState() =>
      _ConfigurationScreenState();
}

class _ConfigurationScreenState extends ConsumerState<ConfigurationScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final identity = ref.watch(clubIdentityProvider).valueOrNull;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: club == null
                ? premiumEmpty(
                    context,
                    icon: Icons.tune_rounded,
                    title: 'Kulüp yok',
                    subtitle:
                        'Yapılandırma bir kulübe bağlıdır. Önce kulüp kur ya '
                        'da bir kulübe katıl.',
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(clubIdentityProvider);
                      ref.invalidate(clubMembersAdminProvider);
                      ref.invalidate(clubSeasonsProvider);
                      await ref.read(clubIdentityProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                      children: [
                        Text((identity?.name ?? club.name).toUpperCase(),
                            style: jakarta(
                                11, FontWeight.w700, SwanColors.textSecondary,
                                ls: 1.4)),
                        const SizedBox(height: 3),
                        Text('Yapılandırma',
                            style: sora(25, FontWeight.w800, ink)),
                        const SizedBox(height: 18),
                        _identityCard(isDark, ink, identity),
                        const SizedBox(height: 22),
                        _membersSection(isDark, ink),
                        const SizedBox(height: 22),
                        _seasonsSection(isDark, ink),
                        const SizedBox(height: 22),
                        _label('KISAYOLLAR'),
                        _link(isDark, ink, Icons.payments_rounded,
                            'Aidat planları', 'Tutar tanımla, sporculara ata',
                            () => Navigator.pushNamed(context, '/finans')),
                        _link(isDark, ink, Icons.shield_rounded, 'Takımlar',
                            'Yaş grupları ve kadro yapısı',
                            () => Navigator.pushNamed(context, '/teams')),
                        _link(isDark, ink, Icons.stadium_rounded, 'Tesisler',
                            'Salon ve saha tanımları',
                            () => Navigator.pushNamed(context, '/facilities')),
                      ],
                    ),
                  ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  // ------------------------------- kimlik ---------------------------------
  Widget _identityCard(bool isDark, Color ink, ClubIdentity? c) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [kTealBright, kTealDeep]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.account_balance_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c?.name ?? '—',
                      style: jakarta(14.5, FontWeight.w800, ink)),
                  const SizedBox(height: 2),
                  Text(
                      [
                        if ((c?.shortName ?? '').isNotEmpty) c!.shortName!,
                        if ((c?.city ?? '').isNotEmpty) c!.city!,
                      ].join(' · '),
                      style: jakarta(
                          11.5, FontWeight.w500, SwanColors.textSecondary)),
                ],
              ),
            ),
            if (c?.isPending ?? false)
              PremiumStatusChip(
                  label: 'Onay bekliyor',
                  color: const Color(0xFFD9860B),
                  icon: Icons.schedule_rounded),
          ]),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: c == null ? null : () => _editIdentity(c),
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text('Kulüp bilgilerini düzenle',
                  style: jakarta(12.5, FontWeight.w800, kTeal)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editIdentity(ClubIdentity c) async {
    final name = FormField_('Kulüp adı', hint: 'Kulüp')
      ..controller.text = c.name;
    final short = FormField_('Kısa ad', hint: 'KSK', required: false)
      ..controller.text = c.shortName ?? '';
    final city = FormField_('Şehir', hint: 'Konya', required: false)
      ..controller.text = c.city ?? '';

    await showQuickForm(
      context,
      title: 'Kulüp bilgileri',
      fields: [name, short, city],
      onSubmit: () => _guard(() async {
        await ref.read(clubConfigServiceProvider).updateIdentity(
              c.id,
              name: name.value,
              shortName: short.value,
              city: city.value,
            );
        ref.invalidate(clubIdentityProvider);
        ref.invalidate(myClubsProvider);
      }, 'Kulüp bilgileri güncellendi'),
    );
  }

  // ------------------------------- üyeler ---------------------------------
  Widget _membersSection(bool isDark, Color ink) {
    final members = ref.watch(clubMembersAdminProvider);
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('ÜYELER & ROLLER'),
        members.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) {
            if (list.isEmpty) {
              return Text('Kulüpte üye yok.',
                  style: jakarta(
                      12, FontWeight.w500, SwanColors.textSecondary));
            }
            final adminCount = list.where((m) => m.isAdmin).length;
            return Column(children: [
              for (final m in list)
                GestureDetector(
                  onTap: () => _memberActions(m, adminCount),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: m.isAdmin
                              ? kTeal.withValues(alpha: .4)
                              : line),
                    ),
                    child: Row(children: [
                      GradientAvatar(initials: m.initials, size: 38),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: jakarta(13, FontWeight.w700, ink)),
                            Text(
                                m.status == 'active'
                                    ? m.roleLabel
                                    : '${m.roleLabel} · ${m.status}',
                                style: jakarta(10.5, FontWeight.w600,
                                    m.isAdmin
                                        ? kTeal
                                        : SwanColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.more_horiz_rounded,
                          size: 18, color: SwanColors.textSecondary),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }

  Future<void> _memberActions(ClubMember m, int adminCount) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    // Kulübün tek yöneticisi rolünü değiştiremez; yoksa kulüp yönetimsiz kalır.
    final locked = m.isAdmin && adminCount <= 1;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GradientAvatar(initials: m.initials, size: 52, radius: 17),
          const SizedBox(height: 10),
          Text(m.name, style: sora(17, FontWeight.w800, ink)),
          Text(m.roleLabel,
              style: jakarta(11.5, FontWeight.w600, SwanColors.textSecondary)),
          const SizedBox(height: 16),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                  'Kulübün tek yöneticisi. Rolünü değiştirmek için önce başka '
                  'birini yönetici yap.',
                  textAlign: TextAlign.center,
                  style: jakarta(
                      11, FontWeight.w500, const Color(0xFFD9860B))),
            ),
          if (!locked) ...[
            for (final r in const [
              ('club_admin', 'Kulüp Yöneticisi'),
              ('coach', 'Antrenör'),
              ('official', 'Görevli'),
              ('athlete', 'Sporcu'),
              ('parent', 'Veli'),
            ])
              ListTile(
                dense: true,
                leading: Icon(
                    m.role == r.$1
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 19,
                    color: m.role == r.$1 ? kTeal : SwanColors.textSecondary),
                title: Text(r.$2, style: jakarta(13, FontWeight.w600, ink)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (m.role != r.$1) _changeRole(m, r.$1);
                },
              ),
            const Divider(height: 18),
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_remove_rounded,
                  size: 19, color: Color(0xFFF43F5E)),
              title: Text('Kulüpten çıkar',
                  style:
                      jakarta(13, FontWeight.w700, const Color(0xFFF43F5E))),
              onTap: () {
                Navigator.pop(ctx);
                _removeMember(m);
              },
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _changeRole(ClubMember m, String role) async {
    int? level;
    if (role == 'coach') {
      final lv = FormField_('Kademe (1-5)', hint: '2');
      var picked = false;
      await showQuickForm(
        context,
        title: '${m.name} · kademe',
        fields: [lv],
        onSubmit: () async {
          level = int.tryParse(lv.value);
          picked = true;
        },
      );
      if (!picked) return;
    }
    await _guard(() async {
      await ref
          .read(clubConfigServiceProvider)
          .setMemberRole(m.membershipId, role, coachLevel: level);
      ref.invalidate(clubMembersAdminProvider);
    }, 'Rol güncellendi');
  }

  Future<void> _removeMember(ClubMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kulüpten çıkar'),
        content: Text('${m.name} kulüpten çıkarılacak. Geçmiş kayıtları '
            '(yoklama, fatura) silinmez.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Çıkar')),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(() async {
      await ref
          .read(clubConfigServiceProvider)
          .removeMember(m.membershipId);
      ref.invalidate(clubMembersAdminProvider);
    }, 'Üye çıkarıldı');
  }

  // ------------------------------- sezonlar --------------------------------
  Widget _seasonsSection(bool isDark, Color ink) {
    final seasons = ref.watch(clubSeasonsProvider);
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _label('SEZONLAR')),
          AddButton(onTap: _addSeason, tooltip: 'Sezon ekle'),
        ]),
        const SizedBox(height: 8),
        seasons.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? Text('Sezon tanımlı değil. "2025-2026 Sezonu" gibi bir sezon '
                  'ekleyip aktif yapabilirsin.',
                  style: jakarta(
                      12, FontWeight.w500, SwanColors.textSecondary))
              : Column(children: [
                  for (final s in list)
                    GestureDetector(
                      onTap: () => _seasonActions(s),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: s.isActive
                                  ? kTeal.withValues(alpha: .4)
                                  : line),
                        ),
                        child: Row(children: [
                          Icon(
                              s.isActive
                                  ? Icons.play_circle_rounded
                                  : Icons.circle_outlined,
                              size: 19,
                              color: s.isActive
                                  ? kTeal
                                  : SwanColors.textSecondary),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.label,
                                    style:
                                        jakarta(13, FontWeight.w700, ink)),
                                if (s.startsOn != null || s.endsOn != null)
                                  Text(
                                      '${_d(s.startsOn)} — ${_d(s.endsOn)}',
                                      style: jakarta(10.5, FontWeight.w500,
                                          SwanColors.textSecondary)),
                              ],
                            ),
                          ),
                          if (s.isActive)
                            Text('Aktif',
                                style:
                                    jakarta(11, FontWeight.w800, kTeal)),
                        ]),
                      ),
                    ),
                ]),
        ),
      ],
    );
  }

  String _d(DateTime? d) =>
      d == null ? '—' : '${d.day}.${d.month}.${d.year}';

  Future<void> _addSeason() async {
    final label = FormField_('Sezon adı', hint: '2025-2026 Sezonu');
    await showQuickForm(
      context,
      title: 'Yeni sezon',
      fields: [label],
      onSubmit: () => _guard(() async {
        final club = ref.read(activeClubProvider).valueOrNull;
        if (club == null) return;
        await ref
            .read(clubConfigServiceProvider)
            .createSeason(club.id, label.value);
        ref.invalidate(clubSeasonsProvider);
      }, 'Sezon eklendi'),
    );
  }

  Future<void> _seasonActions(SeasonRow s) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s.label, style: sora(17, FontWeight.w800, ink)),
          const SizedBox(height: 14),
          if (!s.isActive)
            ListTile(
              dense: true,
              leading: const Icon(Icons.play_circle_rounded,
                  size: 20, color: kTeal),
              title: Text('Aktif sezon yap',
                  style: jakarta(13, FontWeight.w700, ink)),
              onTap: () {
                Navigator.pop(ctx);
                _guard(() async {
                  final club = ref.read(activeClubProvider).valueOrNull;
                  if (club == null) return;
                  await ref
                      .read(clubConfigServiceProvider)
                      .activateSeason(club.id, s.id);
                  ref.invalidate(clubSeasonsProvider);
                }, 'Aktif sezon değişti');
              },
            ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline_rounded,
                size: 20, color: Color(0xFFF43F5E)),
            title: Text('Sezonu sil',
                style: jakarta(13, FontWeight.w700, const Color(0xFFF43F5E))),
            onTap: () {
              Navigator.pop(ctx);
              _guard(() async {
                await ref.read(clubConfigServiceProvider).removeSeason(s.id);
                ref.invalidate(clubSeasonsProvider);
              }, 'Sezon silindi');
            },
          ),
        ]),
      ),
    );
  }

  // ------------------------------- yardımcı --------------------------------
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                ls: 1.2)),
      );

  Widget _link(bool isDark, Color ink, IconData icon, String title, String sub,
      VoidCallback onTap) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Icon(icon, size: 19, color: kTeal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: jakarta(13, FontWeight.w700, ink)),
                Text(sub,
                    style: jakarta(
                        10.5, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }

  Future<void> _guard(Future<void> Function() task, String ok) async {
    try {
      await task();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ok), backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }
}

/// Eski yapılandırma alt ekranı — rotası korunuyor.
class ConfigurationModuleScreen extends ConsumerWidget {
  const ConfigurationModuleScreen({required this.args, super.key});
  final ConfigurationModuleArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Bu bölüm Yapılandırma ekranına taşındı.')),
    );
  }
}
