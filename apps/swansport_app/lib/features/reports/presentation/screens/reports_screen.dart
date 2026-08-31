import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/design/swan_type.dart';

/// Raporlar — kulübün gerçek verilerinden derlenen özet.
///
/// Eskiden sabit rapor kartlarıydı ve hiçbiri açılmıyordu. Artık kadro,
/// yoklama, tahsilat ve sağlık verisinden hesaplanıyor.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final athletes = ref.watch(clubAthletesProvider).valueOrNull ?? const [];
    final attendance = ref.watch(attendanceSummaryProvider);
    final finance = ref.watch(financeSummaryProvider).valueOrNull;
    final injuries = ref.watch(injuriesProvider).valueOrNull ?? const [];

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
                    icon: Icons.description_rounded,
                    title: 'Kulüp yok',
                    subtitle: 'Raporlar bir kulübün verisinden derlenir.',
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(attendanceSummaryProvider);
                      ref.invalidate(financeSummaryProvider);
                      ref.invalidate(injuriesProvider);
                      await ref.read(attendanceSummaryProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                      children: [
                        Text(club.name.toUpperCase(),
                            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text('Raporlar',
                            style: SwanType.h2(ink)),
                        const SizedBox(height: 18),

                        // ---------------------------------------- kadro
                        _section(ink, 'KADRO'),
                        _statCard(isDark, ink, [
                          ('Sporcu', '${athletes.length}', false),
                          (
                            'Sakat',
                            '${injuries.where((i) => i.status == 'injured').length}',
                            injuries.any((i) => i.status == 'injured')
                          ),
                          (
                            'Takipte',
                            '${injuries.where((i) => i.status == 'pending').length}',
                            false
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // ---------------------------------------- finans
                        _section(ink, 'TAHSİLAT'),
                        _financeCard(isDark, ink, finance),
                        const SizedBox(height: 20),

                        // ---------------------------------------- devam
                        _section(ink, 'DEVAM DURUMU (son 90 gün)'),
                        attendance.when(
                          loading: premiumLoading,
                          error: (e, _) => premiumError(context, '$e'),
                          data: (list) => list.isEmpty
                              ? Text(
                                  'Henüz yoklama alınmamış. Yoklama aldıkça '
                                  'devam oranları burada birikir.',
                                  style: SwanType.caption(SwanColors.textSecondary))
                              : _attendanceCard(isDark, ink, list),
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

  Widget _section(Color ink, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
      );

  Widget _statCard(
      bool isDark, Color ink, List<(String, String, bool)> stats) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        for (final s in stats)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.$2,
                    style: SwanType.h2(s.$3 ? const Color(0xFFF43F5E) : ink)),
                const SizedBox(height: 2),
                Text(s.$1,
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _financeCard(bool isDark, Color ink, FinanceSummary? f) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final rate = f?.rate ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tahsilat oranı',
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('%${(rate * 100).round()}',
                    style: SwanType.h2(ink)),
              ],
            ),
          ),
          SwanRing(
            value: rate,
            track: line,
            progress: kTeal,
            size: 52,
            stroke: 6,
          ),
        ]),
        const SizedBox(height: 14),
        Divider(color: line, height: 1),
        const SizedBox(height: 14),
        Row(children: [
          _mini(ink, 'Tahakkuk', money(f?.billed ?? 0)),
          _mini(ink, 'Tahsil', money(f?.collected ?? 0)),
          _mini(ink, 'Gecikmiş', money(f?.overdueTotal ?? 0),
              alert: (f?.overdueCount ?? 0) > 0),
        ]),
      ]),
    );
  }

  Widget _mini(Color ink, String label, String value, {bool alert = false}) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: SwanType.caption(alert ? const Color(0xFFF43F5E) : ink, w: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
          ],
        ),
      );

  Widget _attendanceCard(
      bool isDark, Color ink, List<AttendanceStat> list) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final sorted = [...list]..sort((a, b) => a.rate.compareTo(b.rate));
    final avg = list.isEmpty
        ? 0
        : (list.fold<int>(0, (n, r) => n + r.rate) / list.length).round();

    return Column(children: [
      Container(
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
                Text('Kulüp ortalaması',
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('%$avg', style: SwanType.h2(ink)),
              ],
            ),
          ),
          Text('${list.length} sporcu',
              style:
                  SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 12),
      // En düşük devam oranları önce: rapor okuyanın ilgilendiği taraf bu.
      for (final r in sorted.take(10))
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name.isEmpty ? 'Sporcu' : r.name,
                      style: SwanType.caption(ink, w: FontWeight.w700)),
                  Text('${r.present} katıldı · ${r.absent} gelmedi',
                      style: SwanType.caption(SwanColors.textSecondary)),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: r.rate / 100,
                  minHeight: 6,
                  backgroundColor: line,
                  valueColor: AlwaysStoppedAnimation(
                      r.rate < 60 ? const Color(0xFFF43F5E) : kTeal),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('%${r.rate}',
                style: SwanType.caption(r.rate < 60 ? const Color(0xFFF43F5E) : ink, w: FontWeight.w800)),
          ]),
        ),
    ]);
  }
}
