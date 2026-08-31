import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Performans — kulüp kadrosunun test ve gelişim durumu.
///
/// Sporcu başına kaç test girilmiş, kaç açık hedefi var ve en son ne zaman
/// ölçüm yapılmış; hepsi gerçek kayıtlardan. Satıra dokununca o sporcunun
/// performans ekranı açılır.
class PerformanceAnalyticsScreen extends ConsumerWidget {
  const PerformanceAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final async = ref.watch(performanceOverviewProvider);

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
                ref.invalidate(performanceOverviewProvider);
                await ref.read(performanceOverviewProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  Text((club?.name ?? 'KULÜP').toUpperCase(),
                      style: jakarta(
                          11, FontWeight.w700, SwanColors.textSecondary,
                          ls: 1.4)),
                  const SizedBox(height: 3),
                  Text('Performans', style: sora(25, FontWeight.w800, ink)),
                  const SizedBox(height: 18),
                  async.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (rows) {
                      if (rows.isEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.bar_chart_rounded,
                          title: 'Kadro boş',
                          subtitle:
                              'Sporcu ekledikten sonra test ve gelişim '
                              'hedeflerini buradan takip edersin.',
                        );
                      }
                      final withTests =
                          rows.where((r) => r.tests > 0).length;
                      return Column(children: [
                        _summary(isDark, ink, rows.length, withTests, rows),
                        const SizedBox(height: 18),
                        _label('SPORCULAR'),
                        for (final r in rows) _row(context, isDark, ink, r),
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                ls: 1.2)),
      );

  Widget _summary(
      bool isDark,
      Color ink,
      int total,
      int withTests,
      List<({String athleteId, String name, int tests, int goals, int progress, DateTime? lastTest})>
          rows) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final openGoals = rows.fold<int>(0, (n, r) => n + r.goals);
    final coverage = total == 0 ? 0.0 : withTests / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ölçüm kapsamı',
                  style: jakarta(
                      10.5, FontWeight.w600, SwanColors.textSecondary)),
              const SizedBox(height: 3),
              Text('$withTests / $total',
                  style: sora(23, FontWeight.w800, ink)),
              const SizedBox(height: 3),
              Text('$openGoals açık gelişim hedefi',
                  style: jakarta(
                      11, FontWeight.w500, SwanColors.textSecondary)),
            ],
          ),
        ),
        SwanRing(
          value: coverage,
          track: line,
          progress: kTeal,
          size: 56,
          stroke: 6,
          center: Text('%${(coverage * 100).round()}',
              style: jakarta(11, FontWeight.w800, ink)),
        ),
      ]),
    );
  }

  Widget _row(
      BuildContext context,
      bool isDark,
      Color ink,
      ({String athleteId, String name, int tests, int goals, int progress, DateTime? lastTest}) r) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final never = r.tests == 0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/sporcu-performans',
          arguments: {'id': r.athleteId, 'name': r.name}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          GradientAvatar(
              initials: r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
              size: 40,
              gradientIndex: r.athleteId.hashCode.abs() % 4),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name.isEmpty ? 'Sporcu' : r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(13.5, FontWeight.w800, ink)),
                const SizedBox(height: 2),
                Text(
                    never
                        ? 'Henüz ölçüm yok'
                        : '${r.tests} test · ${r.goals} açık hedef'
                            '${r.lastTest == null ? '' : ' · son ${r.lastTest!.day}.${r.lastTest!.month}'}',
                    style: jakarta(10.5, FontWeight.w500,
                        never ? const Color(0xFFD9860B)
                              : SwanColors.textSecondary)),
              ],
            ),
          ),
          if (r.goals > 0)
            SizedBox(
              width: 46,
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: r.progress / 100,
                    minHeight: 5,
                    backgroundColor: line,
                    valueColor: const AlwaysStoppedAnimation(kTeal),
                  ),
                ),
                const SizedBox(height: 4),
                Text('%${r.progress}',
                    style: jakarta(10, FontWeight.w700, kTeal)),
              ]),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }
}
