import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../app/widgets/premium.dart';
import 'demo_role.dart';

/// DEMO — rol değiştirici ekran (/demo-rol).
/// Rolleri gruplu listeler; seçince demoRoleProvider'ı ayarlar ve o rolün
/// ana ekranına gider. Kademe hiyerarşisi merdiven olarak gösterilir.
class DemoRoleScreen extends ConsumerWidget {
  const DemoRoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final active = ref.watch(demoRoleProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                Row(children: [
                  _back(context, surf, line, ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Demo Modu',
                            style: sora(22, FontWeight.w800, ink)),
                        Text('Rol seç — her rol farklı ekranları görür',
                            style: jakarta(
                                11.5, FontWeight.w500, SwanColors.textSecondary)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // Aktif durum şeridi + gerçek role dönüş
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: active == null
                        ? surf
                        : kTeal.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: active == null
                            ? line
                            : kTeal.withValues(alpha: .4)),
                  ),
                  child: Row(children: [
                    Icon(
                        active == null
                            ? Icons.person_outline_rounded
                            : Icons.theater_comedy_rounded,
                        size: 20,
                        color: active == null
                            ? SwanColors.textSecondary
                            : kTeal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          active == null
                              ? 'Demo kapalı — gerçek rolündesin'
                              : 'Aktif demo rolü: ${active.shortLabel}',
                          style: jakarta(12.5, FontWeight.w700,
                              active == null ? SwanColors.textSecondary : ink)),
                    ),
                    if (active != null)
                      GestureDetector(
                        onTap: () {
                          ref.read(demoRoleProvider.notifier).state = null;
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/dashboard', (_) => false);
                        },
                        child: Text('Gerçeğe dön',
                            style: jakarta(12, FontWeight.w800, kCoral)),
                      ),
                  ]),
                ),
                _scopeNotice(isDark, ink, line),
                const SizedBox(height: 20),

                ..._group(context, ref, isDark, active, 'PLATFORM',
                    DemoRoleGroup.platform),
                ..._group(context, ref, isDark, active, 'KULÜP YÖNETİMİ',
                    DemoRoleGroup.club),
                ..._group(context, ref, isDark, active,
                    'ANTRENÖRLER (KADEME HİYERARŞİSİ)', DemoRoleGroup.coach),
                ..._group(context, ref, isDark, active, 'SPORCULAR',
                    DemoRoleGroup.athlete),
                ..._group(
                    context, ref, isDark, active, 'AİLE', DemoRoleGroup.family),
                ..._group(context, ref, isDark, active, 'ÜYELİK',
                    DemoRoleGroup.member),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _group(BuildContext context, WidgetRef ref, bool isDark,
      DemoRole? active, String title, DemoRoleGroup group) {
    final roles =
        kDemoRolesOrdered.where((r) => r.group == group).toList();
    if (roles.isEmpty) return const [];
    final isCoach = group == DemoRoleGroup.coach;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
        child: Text(title,
            style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                ls: 1.2)),
      ),
      for (final r in roles)
        _roleCard(context, ref, isDark, r, active == r, isCoach),
      const SizedBox(height: 12),
    ];
  }

  Widget _roleCard(BuildContext context, WidgetRef ref, bool isDark,
      DemoRole role, bool selected, bool isCoach) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final count = role.allowedRoutes.length;
    final kademe = role.kademe;

    return GestureDetector(
      onTap: () {
        ref.read(demoRoleProvider.notifier).state = role;
        Navigator.pushNamedAndRemoveUntil(
            context, role.homeRoute, (_) => false);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kTeal.withValues(alpha: .08) : surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? kTeal : line, width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          // Kademe rozeti veya ikon
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _roleColors(role),
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: kademe != null
                ? Text('$kademe',
                    style: sora(18, FontWeight.w800, Colors.white))
                : Icon(_roleIcon(role), size: 20, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role.shortLabel, style: jakarta(13.5, FontWeight.w800, ink)),
                const SizedBox(height: 2),
                Text(_roleHint(role, count),
                    style: jakarta(
                        11, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded, size: 22, color: kTeal)
          else
            Icon(Icons.chevron_right_rounded,
                size: 20, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }

  String _roleHint(DemoRole role, int count) {
    if (role == DemoRole.coach1) {
      return '$count modül · 2. kademe+ süpervizöre bağlı';
    }
    if (role == DemoRole.coach5) {
      return '$count modül · alt kademelerin tümü + yapılandırma';
    }
    if (role.kademe != null && role.kademe! >= 2) {
      return '$count modül · alt kademeleri kapsar';
    }
    return '$count modül görünür';
  }

  List<Color> _roleColors(DemoRole role) => switch (role.group) {
        DemoRoleGroup.platform => const [Color(0xFFF43F5E), Color(0xFFB91C3C)],
        DemoRoleGroup.club => const [kTealBright, kTealDeep],
        DemoRoleGroup.coach => const [Color(0xFF7C5CE6), Color(0xFF4C3AA8)],
        DemoRoleGroup.athlete => const [Color(0xFF10B981), Color(0xFF047857)],
        DemoRoleGroup.family => const [Color(0xFF4FC3F7), Color(0xFF2563EB)],
        DemoRoleGroup.member => const [Color(0xFF94A3B8), Color(0xFF64748B)],
      };

  IconData _roleIcon(DemoRole role) => switch (role) {
        DemoRole.platformAdmin => Icons.admin_panel_settings_rounded,
        DemoRole.clubAdmin => Icons.account_balance_rounded,
        DemoRole.athleteLicensed => Icons.sports_rounded,
        DemoRole.athleteIndividual => Icons.directions_run_rounded,
        DemoRole.guardian => Icons.family_restroom_rounded,
        DemoRole.member => Icons.person_rounded,
        _ => Icons.sports_rounded,
      };


  /// Demo modunun sınırını açıkça yazar.
  ///
  /// En sık kafa karıştıran nokta bu: rol değişince menü değişiyor ama
  /// veriler değişmiyor. Kullanıcı bunu bilmeden "çalışmıyor" sanıyor.
  Widget _scopeNotice(bool isDark, Color ink, Color line) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFD9860B).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFD9860B).withValues(alpha: .3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded,
            size: 17, color: Color(0xFFD9860B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Demo modu neyi değiştirir?',
                  style: jakarta(12, FontWeight.w800, ink)),
              const SizedBox(height: 4),
              Text(
                  'Menüyü, alt barı ve hangi ekranlara girebildiğini değiştirir. '
                  'Ekranlardaki VERİ değişmez — hepsi kendi hesabına ait. '
                  'Yetki gerektiren bir ekranı demoyla açarsan (ör. onay paneli) '
                  'liste boş görünebilir; bu hata değil, veritabanı hâlâ gerçek '
                  'kimliğini görüyor.',
                  style: jakarta(11, FontWeight.w500, SwanColors.textSecondary)
                      .copyWith(height: 1.45)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _back(BuildContext context, Color surf, Color line, Color ink) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: line)),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: ink),
      ),
    );
  }
}
