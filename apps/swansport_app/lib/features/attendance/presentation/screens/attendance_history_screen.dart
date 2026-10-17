import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_app/app/widgets/swan_module_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Yoklama Geçmişi — Stitch "Calm Athletic Modernism" Devam & Katılım Analitikleri.
class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final async = ref.watch(attendanceSummaryProvider);

    return SwanScaffold(
      appBar: swanModuleAppBar(context, title: 'Yoklama Geçmişi', actions: [
        TextButton.icon(onPressed: () => Navigator.pushNamed(context, '/attendance'), icon: Icon(Icons.add_rounded), label: Text('Yoklama Al', style: SwanType.caption(context.swan.accent))),
      ]),
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                // Top Header


                // Main Scrollable Area
                Expanded(
                  child: RefreshIndicator(
                    color: c.accent,
                    onRefresh: () async {
                      ref.invalidate(attendanceSummaryProvider);
                      await ref.read(attendanceSummaryProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, SwanSpace.xl * 5),
                      children: [
                        // 1. Subheader
                        _buildSubheader(c, club),
                        const SizedBox(height: 14),

                        // 7. Sporcu Devam Tablosu & Filters
                        _buildRosterAttendanceSection(c, async),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------


  // ---------------------------------------------------------------------------
  // SUBHEADER
  // ---------------------------------------------------------------------------
  Widget _buildSubheader(SwanPalette c, ClubRef? club) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KATILIM VE DEVAM RAPORLARI',
              style: SwanType.caption(c.accent, w: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Tüm kayıtlı yoklamaların özeti',
              style: SwanType.bodySm(c.ink, w: FontWeight.w600),
            ),
          ],
        )),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/calendar'),
          tooltip: 'Takvimi aç',
          icon: Icon(Icons.calendar_month, color: c.accent, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PERIOD TABS
  // ---------------------------------------------------------------------------
  Widget _buildRosterAttendanceSection(
    SwanPalette c,
    AsyncValue<List<AttendanceStat>> async,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(
              'Sporcu Devam Tablosu', maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.h3(c.ink).copyWith(fontWeight: FontWeight.w700),
            )),
            Expanded(child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pillFilter(c, 'Tümü', _selectedFilter == 'all',
                      () => setState(() => _selectedFilter = 'all')),
                  const SizedBox(width: 6),
                  _pillFilter(c, '%80+', _selectedFilter == 'high',
                      () => setState(() => _selectedFilter = 'high')),
                  const SizedBox(width: 6),
                  _pillFilter(c, 'Riskli (<%70)', _selectedFilter == 'risk',
                      () => setState(() => _selectedFilter = 'risk')),
                ],
              ),
            )),
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: premiumLoading,
          error: (e, _) => Center(
            child: Text('Veri yüklenemedi: $e',
                style: SwanType.caption(c.inkMuted)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Kayıt bulunamadı.',
                      style: SwanType.bodySm(c.inkMuted)),
                ),
              );
            }

            final withData = list.where((r) => r.total > 0).toList();
            final filtered = withData.where((r) {
              final rate = r.total == 0 ? 0 : (r.present / r.total);
              if (_selectedFilter == 'high') return rate >= 0.8;
              if (_selectedFilter == 'risk') return rate < 0.7;
              return true;
            }).toList();

            return Column(
              children: filtered.map((r) => _buildAthleteRow(c, r)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _pillFilter(
      SwanPalette c, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c.accentFill : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? c.accentFill : c.line),
        ),
        child: Text(
          label,
          style: SwanType.caption(
            active ? context.swan.onAccent : c.inkMuted,
            w: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildAthleteRow(SwanPalette c, AttendanceStat r) {
    final rate = r.total == 0 ? 0 : (100 * r.present / r.total).round();
    final initials = _initials(r.name);
    final statusColor = rate >= 80
        ? c.accent
        : (rate >= 60 ? context.swan.warning : context.swan.danger);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.bg,
              shape: BoxShape.circle,
              border: Border.all(color: c.line),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: SwanType.caption(c.accent, w: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.present}/${r.total} Seans Katıldı',
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '%$rate',
              style: SwanType.caption(statusColor, w: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return (a + b).toUpperCase();
  }
}
