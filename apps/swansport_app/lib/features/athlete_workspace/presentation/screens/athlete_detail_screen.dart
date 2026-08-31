import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../routing/athlete_detail_route_args.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Sporcu Profili — Supabase verisine bağlı, premium tasarım (v3).
class AthleteDetailScreen extends ConsumerWidget {
  const AthleteDetailScreen({super.key, required this.args});

  const AthleteDetailScreen.invalidRoute({super.key}) : args = null;

  final AthleteDetailRouteArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final id = args?.athleteId.value;
    final async = id == null
        ? const AsyncValue<AthleteFull?>.data(null)
        : ref.watch(athleteByIdProvider(id));

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: async.when(
            loading: () => premiumLoading(),
            error: (e, _) => premiumError(context, '$e'),
            data: (a) {
              if (a == null) {
                return premiumEmpty(
                  context,
                  icon: Icons.person_off_rounded,
                  title: 'Sporcu bulunamadı',
                  subtitle: 'Bu profile ulaşılamadı.',
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  _cover(context),
                  Transform.translate(
                    offset: const Offset(0, -34),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: bg, width: 4),
                                ),
                                child: GradientAvatar(
                                  initials: a.initials,
                                  size: 76,
                                  radius: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          a.fullName,
                                          style: sora(20, FontWeight.w800, ink),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      PremiumStatusChip(
                                        label: a.isActive ? 'Aktif' : 'Pasif',
                                        color: a.isActive
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFD9860B),
                                        icon: a.isActive
                                            ? Icons.check_circle_rounded
                                            : Icons.pause_circle_filled_rounded,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.position ?? 'Sporcu',
                            style: jakarta(
                              12.5,
                              FontWeight.w600,
                              SwanColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _stat(isDark, a.age?.toString() ?? '—', 'Yaş'),
                              const SizedBox(width: 10),
                              _stat(
                                isDark,
                                (a.license != null && a.license!.isNotEmpty)
                                    ? 'Var'
                                    : '—',
                                'Lisans',
                                accent: true,
                              ),
                              const SizedBox(width: 10),
                              _stat(
                                isDark,
                                a.isActive ? 'Aktif' : 'Pasif',
                                'Durum',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _card(
                            isDark,
                            'Lisans',
                            a.license ?? 'Lisans numarası girilmemiş',
                          ),
                          const SizedBox(height: 10),
                          _card(isDark, 'Pozisyon', a.position ?? '—'),
                          const SizedBox(height: 18),
                          // 18 yaş altı ve velisi bağlı değilse uyar
                          if (ref
                                  .watch(needsGuardianProvider(a.id))
                                  .valueOrNull ==
                              true) ...[
                            _guardianWarning(isDark),
                            const SizedBox(height: 12),
                          ],
                          _inviteButton(context, ref, a.id),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  /// 18 yaş altı sporcularda veli bağı zorunludur.
  Widget _guardianWarning(bool isDark) {
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD9860B).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFD9860B).withValues(alpha: .4)),
      ),
      child: Row(children: [
        const Icon(Icons.family_restroom_rounded,
            size: 20, color: Color(0xFFD9860B)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Veli bağı eksik', style: jakarta(13, FontWeight.w800, ink)),
              const SizedBox(height: 2),
              Text(
                  '18 yaş altı sporcularda veli zorunludur. Aşağıdan davet '
                  'kodu üretip veliyle paylaş.',
                  style:
                      jakarta(11.5, FontWeight.w500, SwanColors.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _inviteButton(BuildContext context, WidgetRef ref, String athleteId) {
    return GestureDetector(
      onTap: () => _generateInvite(context, ref, athleteId),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kTeal.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kTeal.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.family_restroom_rounded, size: 19, color: kTeal),
            const SizedBox(width: 9),
            Text(
              'Veli Davet Kodu Üret',
              style: jakarta(14, FontWeight.w800, kTeal),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateInvite(
    BuildContext context,
    WidgetRef ref,
    String athleteId,
  ) async {
    try {
      final code = await ref
          .read(verificationServiceProvider)
          .createGuardianInvite(athleteId);
      if (!context.mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
      final ink = isDark ? Colors.white : SwanColors.textPrimary;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: surf,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text('Veli Davet Kodu', style: sora(18, FontWeight.w800, ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bu kodu veliyle paylaş. Veli, uygulamada “Veli Bağla” ekranına girip bu kodla sporcuya bağlanır.',
                style: jakarta(
                  12.5,
                  FontWeight.w500,
                  SwanColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  code,
                  style: sora(28, FontWeight.w800, kTeal, ls: 5),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '24 saat geçerli · tek kullanımlık',
                style: jakarta(
                  11,
                  FontWeight.w600,
                  SwanColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Kapat',
                style: jakarta(13, FontWeight.w700, SwanColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kod kopyalandı')),
                );
              },
              child:
                  Text('Kopyala', style: jakarta(13, FontWeight.w800, kTeal)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kod üretilemedi: $e'),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    }
  }

  Widget _cover(BuildContext context) {
    return Container(
      height: 132,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.4,
          colors: [kTealBright, kTeal, kTealDeep],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: Tooltip(
              message: 'Geri dön',
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 17, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(bool isDark, String value, String label, {bool accent = false}) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Column(
          children: [
            Text(value, style: sora(18, FontWeight.w800, accent ? kTeal : ink)),
            const SizedBox(height: 2),
            Text(
              label,
              style: jakarta(10.5, FontWeight.w600, SwanColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(bool isDark, String title, String value) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: jakarta(11, FontWeight.w700, SwanColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(value, style: jakarta(13.5, FontWeight.w700, ink)),
        ],
      ),
    );
  }
}
