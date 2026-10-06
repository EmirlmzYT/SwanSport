import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Performans — kulüp kadrosunun test ve gelişim durumu & Biyometrik Kokpit.
class PerformanceAnalyticsScreen extends ConsumerStatefulWidget {
  const PerformanceAnalyticsScreen({super.key});

  @override
  ConsumerState<PerformanceAnalyticsScreen> createState() =>
      _PerformanceAnalyticsScreenState();
}

class _PerformanceAnalyticsScreenState
    extends ConsumerState<PerformanceAnalyticsScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
                children: [
                  _buildHeader(context, ink, surf, line, club?.name),
                  const SizedBox(height: 14),

                  // Search Field
                  _buildSearchBox(surf, line, ink),
                  const SizedBox(height: 14),

                  async.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (rows) {
                      if (rows.isEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.bar_chart_rounded,
                          title: 'Kadro boş',
                          subtitle: 'Sporcu ekledikten sonra test ve gelişim '
                              'hedeflerini buradan takip edersin.',
                        );
                      }

                      final filtered = _filter.isEmpty
                          ? rows
                          : rows
                              .where(
                                (r) => trContains(r.name, _filter),
                              )
                              .toList();

                      final withTests = rows.where((r) => r.tests > 0).length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summary(
                            isDark,
                            ink,
                            rows.length,
                            withTests,
                            rows,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kadro Sporcuları',
                                style: SwanType.h3(ink),
                              ),
                              Text(
                                '${filtered.length} sporcu',
                                style: SwanType.caption(
                                  SwanColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final r in filtered)
                            _row(context, isDark, ink, r),
                        ],
                      );
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

  Widget _buildHeader(
    BuildContext context,
    Color ink,
    Color surf,
    Color line,
    String? clubName,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName ?? 'SwanSport',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
                Text('Performans & Analiz', style: SwanType.h2(ink)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none_rounded, color: ink),
              onPressed: () => Navigator.pushNamed(context, '/bildirimler'),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: kTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBox(Color surf, Color line, Color ink) {
    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _filter = v.trim()),
        style: SwanType.bodySm(ink),
        decoration: InputDecoration(
          hintText: 'Kadroda sporcu ara…',
          hintStyle: SwanType.bodySm(SwanColors.textSecondary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: SwanColors.textSecondary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _summary(
    bool isDark,
    Color ink,
    int total,
    int withTests,
    List<
            ({
              String athleteId,
              String name,
              int tests,
              int goals,
              int progress,
              DateTime? lastTest
            })>
        rows,
  ) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final openGoals = rows.fold<int>(0, (n, r) => n + r.goals);
    final coverage = total == 0 ? 0.0 : withTests / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ölçüm kapsamı',
                  style: SwanType.caption(SwanColors.textSecondary),
                ),
                const SizedBox(height: 3),
                Text('$withTests / $total', style: SwanType.display(ink)),
                const SizedBox(height: 3),
                Text(
                  '$openGoals açık gelişim hedefi',
                  style: SwanType.caption(SwanColors.textSecondary),
                ),
              ],
            ),
          ),
          SwanRing(
            value: coverage,
            track: line,
            progress: kTeal,
            size: 56,
            stroke: 6,
            center: Text(
              '%${(coverage * 100).round()}',
              style: SwanType.caption(ink, w: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    bool isDark,
    Color ink,
    ({
      String athleteId,
      String name,
      int tests,
      int goals,
      int progress,
      DateTime? lastTest
    }) r,
  ) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final never = r.tests == 0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/sporcu-performans',
        arguments: {'id': r.athleteId, 'name': r.name},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(
          children: [
            GradientAvatar(
              initials: r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
              size: 40,
              gradientIndex: r.athleteId.hashCode.abs() % 4,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name.isEmpty ? 'Sporcu' : r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(ink, w: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    never
                        ? 'Henüz ölçüm yok'
                        : '${r.tests} test · ${r.goals} açık hedef'
                            '${r.lastTest == null ? '' : ' · son ${r.lastTest!.day}.${r.lastTest!.month}'}',
                    style: SwanType.caption(
                      never
                          ? SwanPalette.light.warning
                          : SwanColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (r.goals > 0)
              SizedBox(
                width: 46,
                child: Column(
                  children: [
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
                    Text(
                      '%${r.progress}',
                      style: SwanType.caption(kTeal, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: SwanColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
