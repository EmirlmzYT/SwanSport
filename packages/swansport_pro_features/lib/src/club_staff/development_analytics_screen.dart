import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';

final class ProDevelopmentAnalyticsScreen extends ConsumerStatefulWidget {
  const ProDevelopmentAnalyticsScreen({super.key});

  @override
  ConsumerState<ProDevelopmentAnalyticsScreen> createState() =>
      _ProDevelopmentAnalyticsScreenState();
}

final class _ProDevelopmentAnalyticsScreenState
    extends ConsumerState<ProDevelopmentAnalyticsScreen> {
  String? _athleteId;
  String? _teamId;
  String? _sportCode;
  String _query = '';
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 90));
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final enabled = ref.watch(
      featureEnabledProvider(FeatureFlags.developmentReport),
    );
    final athletes = ref.watch(
      reportAthletesProvider((query: _query, offset: 0)),
    );
    return host.chrome.buildPage(
      context,
      title: 'Performans ve Gelişim',
      body: !enabled
          ? const _ReportMessage('Gelişim raporu özelliği etkin değil')
          : athletes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ReportMessage(
                classifyOperationError(error).userMessage,
                onRetry: () => ref.invalidate(
                  reportAthletesProvider((query: _query, offset: 0)),
                ),
              ),
              data: _content,
            ),
    );
  }

  Widget _content(ReportAthletePage page) {
    final filtered = page.athletes.where((athlete) {
      return (_teamId == null || athlete.teamId == _teamId) &&
          (_sportCode == null || athlete.sportCode == _sportCode);
    }).toList();
    final teams = <String, String>{
      for (final athlete in page.athletes)
        if (athlete.teamId != null && athlete.teamName != null)
          athlete.teamId!: athlete.teamName!,
    };
    final sports = <String>{
      for (final athlete in page.athletes)
        if (athlete.sportCode != null) athlete.sportCode!,
    }.toList()
      ..sort();
    final reportRequest = _athleteId == null
        ? null
        : (athleteId: _athleteId!, from: _from, to: _to);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          key: const Key('development-report-search'),
          decoration: const InputDecoration(
            labelText: 'Sporcu, takım veya branş ara',
            prefixIcon: Icon(Icons.search),
          ),
          onFieldSubmitted: (value) => setState(() => _query = value.trim()),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                key: const Key('development-report-team'),
                initialValue: teams.containsKey(_teamId) ? _teamId : null,
                decoration: const InputDecoration(labelText: 'Takım'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tüm takımlar'),
                  ),
                  for (final team in teams.entries)
                    DropdownMenuItem(value: team.key, child: Text(team.value)),
                ],
                onChanged: (value) => setState(() {
                  _teamId = value;
                  _athleteId = null;
                }),
              ),
            ),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                key: const Key('development-report-sport'),
                initialValue: sports.contains(_sportCode) ? _sportCode : null,
                decoration: const InputDecoration(labelText: 'Branş'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tüm branşlar'),
                  ),
                  for (final sport in sports)
                    DropdownMenuItem(value: sport, child: Text(sport)),
                ],
                onChanged: (value) => setState(() {
                  _sportCode = value;
                  _athleteId = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('development-report-athlete'),
          initialValue:
              filtered.any((a) => a.id == _athleteId) ? _athleteId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sporcu'),
          items: [
            for (final athlete in filtered)
              DropdownMenuItem(value: athlete.id, child: Text(athlete.name)),
          ],
          onChanged: (value) => setState(() => _athleteId = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickDate(from: true),
              icon: const Icon(Icons.date_range_outlined),
              label: Text('Başlangıç ${reportDate(_from)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(from: false),
              icon: const Icon(Icons.event_outlined),
              label: Text('Bitiş ${reportDate(_to)}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const _ReportMessage('Bu filtrelerde yetkili sporcu bulunamadı')
        else if (_athleteId == null)
          const _ReportMessage('Rapor için sporcu seçin')
        else
          ref
              .watch(
                developmentReportProvider(reportRequest!),
              )
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    _ReportMessage(classifyOperationError(error).userMessage),
                data: (report) => _ReportBody(report),
              ),
      ],
    );
  }

  Future<void> _pickDate({required bool from}) async {
    final value = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (from) {
        _from = value.isAfter(_to) ? _to : value;
      } else {
        _to = value.isBefore(_from) ? _from : value;
      }
    });
  }
}

final class _ReportBody extends StatelessWidget {
  const _ReportBody(this.report);
  final DevelopmentReport report;

  @override
  Widget build(BuildContext context) {
    final rate = report.attendance.rate?.toDouble();
    final attendanceText = rate == null
        ? 'Devam eğilimi hesaplanamıyor; yeterli kayıt yok.'
        : 'Kayıtlı etkinliklerde devam oranı yüzde ${reportNumber(rate)}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReportCard(
          report.athlete.name,
          '${reportDate(report.from)} – ${reportDate(report.to)}',
        ),
        Semantics(
          label: attendanceText,
          child: _ReportCard(
            'Devam eğilimi',
            '$attendanceText\nKatıldı ${report.attendance.present} · Geç ${report.attendance.late} · Gelmedi ${report.attendance.absent} · İzinli ${report.attendance.excused}',
            progress: rate == null ? 0 : rate / 100,
          ),
        ),
        for (final metric in report.metrics)
          _ReportCard(metric.name, metric.summary),
        if (report.trainingResults.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Antrenman sonuçları',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        for (final result in report.trainingResults)
          _ReportCard(
            '${reportDate(result.startedAt)} · ${result.protocolName}',
            result.totalScore == null
                ? '${result.setsRecorded} kayıtlı set · skor kaydı yok'
                : '${result.setsRecorded} set · Toplam ${reportNumber(result.totalScore!)} · Ortalama ${reportNumber(result.averageSet!)} · En iyi ${reportNumber(result.bestSet!)}',
          ),
        for (final gap in report.gaps) Text('• $gap'),
      ],
    );
  }
}

final class _ReportCard extends StatelessWidget {
  const _ReportCard(this.title, this.body, {this.progress});
  final String title, body;
  final double? progress;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (progress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
              ],
              const SizedBox(height: 6),
              Text(body),
            ],
          ),
        ),
      );
}

final class _ReportMessage extends StatelessWidget {
  const _ReportMessage(this.text, {this.onRetry});
  final String text;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      );
}
