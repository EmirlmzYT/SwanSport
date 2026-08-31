import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Yoklama geçmişi — sporcu bazında katılım oranı (son 90 gün).
class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final async = ref.watch(attendanceSummaryProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(attendanceSummaryProvider);
                await ref.read(attendanceSummaryProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  Text((club?.name ?? 'SWANSPORT').toUpperCase(),
                      style: jakarta(
                          11, FontWeight.w700, SwanColors.textSecondary,
                          ls: 1.4)),
                  const SizedBox(height: 3),
                  Text('Devam Durumu', style: sora(25, FontWeight.w800, ink)),
                  const SizedBox(height: 4),
                  Text('Son 90 gün',
                      style: jakarta(
                          12, FontWeight.w500, SwanColors.textSecondary)),
                  const SizedBox(height: 18),

                  async.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.fact_check_outlined,
                          title: 'Kayıt yok',
                          subtitle:
                              'Yoklama aldıkça devam oranları burada birikir.',
                          actionLabel: 'Yoklama Al',
                          onAction: () =>
                              Navigator.pushNamed(context, '/attendance'),
                        );
                      }
                      final withData =
                          list.where((r) => r.total > 0).toList();
                      return Column(children: [
                        if (withData.isNotEmpty) _overview(isDark, withData),
                        const SizedBox(height: 16),
                        ...list.map((r) => _row(isDark, r)),
                      ]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  /// Kulüp geneli özet.
  Widget _overview(bool isDark, List<AttendanceStat> list) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final present = list.fold<int>(0, (a, r) => a + r.present);
    final total = list.fold<int>(0, (a, r) => a + r.total);
    final rate = total == 0 ? 0 : (100 * present / total).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        SwanRing(
          value: rate / 100,
          track: line,
          progress: rate >= 80
              ? const Color(0xFF10B981)
              : rate >= 50
                  ? const Color(0xFFD9860B)
                  : const Color(0xFFF43F5E),
          size: 74,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kulüp ortalaması',
                  style: jakarta(
                      11.5, FontWeight.w600, SwanColors.textSecondary)),
              const SizedBox(height: 2),
              Text('%$rate katılım',
                  style: sora(
                      20,
                      FontWeight.w800,
                      isDark ? Colors.white : SwanColors.textPrimary)),
              const SizedBox(height: 4),
              Text('$present / $total yoklama',
                  style: jakarta(
                      11.5, FontWeight.w500, SwanColors.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _row(bool isDark, AttendanceStat r) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final color = r.total == 0
        ? SwanColors.textSecondary
        : r.rate >= 80
            ? const Color(0xFF10B981)
            : r.rate >= 50
                ? const Color(0xFFD9860B)
                : const Color(0xFFF43F5E);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        GradientAvatar(
            initials: r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
            size: 40,
            gradientIndex: r.name.length % 4),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(13.5, FontWeight.w700, ink)),
              const SizedBox(height: 4),
              // Katılım çubuğu
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: r.total == 0 ? 0 : r.rate / 100,
                  minHeight: 6,
                  backgroundColor: line,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                  r.total == 0
                      ? 'Kayıt yok'
                      : '${r.present} katıldı · ${r.absent} gelmedi',
                  style: jakarta(
                      11, FontWeight.w500, SwanColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(r.total == 0 ? '—' : '%${r.rate}',
            style: sora(16, FontWeight.w800, color)),
      ]),
    );
  }
}
