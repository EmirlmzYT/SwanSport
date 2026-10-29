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
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              color: colors.accent,
              onRefresh: () async {
                ref.invalidate(attendanceSummaryProvider);
                await ref.read(attendanceSummaryProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KATILIM VE DEVAM RAPORLARI',
                              style: TextStyle(
                                color: colors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Tüm kayıtlı yoklamaların özeti',
                              style: TextStyle(
                                color: colors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: host.navigator.openCalendar,
                        tooltip: 'Takvimi aç',
                        icon: const Icon(Icons.calendar_month),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sporcu Devam Tablosu',
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('Tümü')),
                        ButtonSegment(value: 'high', label: Text('%80+')),
                        ButtonSegment(
                          value: 'risk',
                          label: Text('Riskli (<%70)'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.single),
                    ),
                  ),
                  const SizedBox(height: 12),
                  summary.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Text(
                        classifyOperationError(error).userMessage,
                        style: TextStyle(color: colors.inkMuted),
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
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Kayıt bulunamadı.',
                              style: TextStyle(color: colors.inkMuted),
                            ),
                          ),
                        );
                      }
                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Bu filtreye uygun kayıt yok.',
                              style: TextStyle(color: colors.inkMuted),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(child: Text(initials)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('${row.present}/${row.total} Seans Katıldı'),
              ],
            ),
          ),
          Text(
            '%$rate',
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
