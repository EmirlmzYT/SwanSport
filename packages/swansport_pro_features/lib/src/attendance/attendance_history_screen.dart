import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_theme.dart';

class SharedAttendanceHistoryScreen extends ConsumerStatefulWidget {
  const SharedAttendanceHistoryScreen({super.key});

  @override
  ConsumerState<SharedAttendanceHistoryScreen> createState() =>
      _SharedAttendanceHistoryScreenState();
}

class _SharedAttendanceHistoryScreenState
    extends ConsumerState<SharedAttendanceHistoryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final colors = host.theme;
    final enabled = ref.watch(
      featureEnabledProvider(FeatureFlags.attendanceOperations),
    );
    if (!enabled) {
      return host.chrome.buildPage(
        context,
        title: 'Yoklama Geçmişi',
        body: const Center(
          child: Text('Yoklama operasyonları şu anda kullanıma kapalı.'),
        ),
      );
    }
    final summary = ref.watch(attendanceSummaryProvider);
    return host.chrome.buildPage(
      context,
      title: 'Yoklama Geçmişi',
      actions: [
        TextButton.icon(
          onPressed: host.navigator.openAttendance,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Yoklama Al'),
        ),
      ],
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              color: colors.accent,
              onRefresh: () async {
                ref.invalidate(attendanceSummaryProvider);
                await ref.read(attendanceSummaryProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 56),
                children: [
                  _HistoryHero(
                    colors: colors,
                    onOpenCalendar: host.navigator.openCalendar,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sporcu Devam Tablosu',
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Katılım oranına göre filtrele ve riskli sporcuları erkenden gör.',
                    style: TextStyle(color: colors.inkMuted, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  _HistoryPanel(
                    colors: colors,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? colors.accent
                                : colors.surface,
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? colors.surface
                                : colors.ink,
                          ),
                          side: WidgetStatePropertyAll(
                            BorderSide(color: colors.line),
                          ),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: 'all',
                            icon: Icon(Icons.people_alt_outlined),
                            label: Text('Tümü'),
                          ),
                          ButtonSegment(
                            value: 'high',
                            icon: Icon(Icons.trending_up_rounded),
                            label: Text('%80+'),
                          ),
                          ButtonSegment(
                            value: 'risk',
                            icon: Icon(Icons.warning_amber_rounded),
                            label: Text('Riskli (<%70)'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (value) =>
                            setState(() => _filter = value.single),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  summary.when(
                    loading: () => _HistoryPanel(
                      colors: colors,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (error, _) => _HistoryPanel(
                      colors: colors,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: colors.danger,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                classifyOperationError(error).userMessage,
                                style: TextStyle(
                                  color: colors.inkMuted,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (rows) {
                      final filtered = rows.where((row) {
                        if (row.total <= 0) return false;
                        final rate = row.present / row.total;
                        if (_filter == 'high') return rate >= .8;
                        if (_filter == 'risk') return rate < .7;
                        return true;
                      }).toList();
                      if (rows.isEmpty) {
                        return _HistoryEmptyState(
                          icon: Icons.fact_check_outlined,
                          message: 'Kayıt bulunamadı.',
                          colors: colors,
                        );
                      }
                      if (filtered.isEmpty) {
                        return _HistoryEmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          message: 'Bu filtreye uygun kayıt yok.',
                          colors: colors,
                        );
                      }
                      final average = (rows.fold<double>(
                                0,
                                (sum, row) =>
                                    sum +
                                    (row.total == 0
                                        ? 0
                                        : row.present / row.total),
                              ) /
                              rows.length *
                              100)
                          .round();
                      final riskCount = rows
                          .where(
                            (row) =>
                                row.total > 0 && row.present / row.total < .7,
                          )
                          .length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HistorySummary(
                            athleteCount: rows.length,
                            averageRate: average,
                            riskCount: riskCount,
                            colors: colors,
                          ),
                          const SizedBox(height: 12),
                          for (final row in filtered)
                            _AttendanceRow(row: row, colors: colors),
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
    );
  }
}

class _HistoryHero extends StatelessWidget {
  const _HistoryHero({required this.colors, required this.onOpenCalendar});

  final ProFeatureThemeData colors;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) => _HistoryPanel(
        colors: colors,
        emphasized: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.insights_outlined,
                        color: colors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'KATILIM VE DEVAM RAPORLARI',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: 44,
                  child: Material(
                    color: colors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: colors.line),
                    ),
                    child: IconButton(
                      onPressed: onOpenCalendar,
                      tooltip: 'Takvimi aç',
                      color: colors.accent,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Devam durumunu tek bakışta izle',
              style: TextStyle(
                color: colors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tüm kayıtlı yoklamaların özeti, katılım oranları ve erken risk sinyalleri.',
              style: TextStyle(color: colors.inkMuted, height: 1.4),
            ),
          ],
        ),
      );
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({
    required this.athleteCount,
    required this.averageRate,
    required this.riskCount,
    required this.colors,
  });

  final int athleteCount;
  final int averageRate;
  final int riskCount;
  final ProFeatureThemeData colors;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SummaryPill(
            icon: Icons.groups_2_outlined,
            label: '$athleteCount sporcu',
            color: colors.accent,
            colors: colors,
          ),
          _SummaryPill(
            icon: Icons.donut_large_rounded,
            label: '%$averageRate ortalama',
            color: colors.success,
            colors: colors,
          ),
          _SummaryPill(
            icon: Icons.warning_amber_rounded,
            label: '$riskCount riskli',
            color: riskCount == 0 ? colors.success : colors.warning,
            colors: colors,
          ),
        ],
      );
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final Color color;
  final ProFeatureThemeData colors;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: colors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.colors,
    required this.child,
    this.emphasized = false,
  });

  final ProFeatureThemeData colors;
  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                emphasized ? colors.accent.withValues(alpha: .3) : colors.line,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.ink.withValues(alpha: .04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({
    required this.icon,
    required this.message,
    required this.colors,
  });

  final IconData icon;
  final String message;
  final ProFeatureThemeData colors;

  @override
  Widget build(BuildContext context) => _HistoryPanel(
        colors: colors,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, color: colors.inkMuted, size: 32),
              const SizedBox(height: 10),
              Text(message, style: TextStyle(color: colors.inkMuted)),
            ],
          ),
        ),
      );
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.row, required this.colors});

  final AttendanceStat row;
  final ProFeatureThemeData colors;

  @override
  Widget build(BuildContext context) {
    final rate = row.total == 0 ? 0 : (100 * row.present / row.total).round();
    final statusColor = rate >= 80
        ? colors.success
        : rate >= 60
            ? colors.warning
            : colors.danger;
    final parts = row.name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? '?'
        : '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'
            .toUpperCase();
    return Container(
      key: Key('attendance-history-${row.athleteId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: TextStyle(
                        color: colors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${row.present}/${row.total} seans katıldı · ${row.absent} devamsız',
                      style: TextStyle(color: colors.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '%$rate',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 7,
              color: statusColor,
              backgroundColor: colors.line,
            ),
          ),
        ],
      ),
    );
  }
}
