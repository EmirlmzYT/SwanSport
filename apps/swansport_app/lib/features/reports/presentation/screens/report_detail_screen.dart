import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/reports_controller.dart';
import '../routing/report_detail_args.dart';

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({required this.args, super.key});
  final ReportDetailArgs? args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsControllerProvider);
    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Geçersiz rapor bağlantısı.')),
      );
    }
    final found = state.templates.where((r) => r.id == args!.reportId);
    if (found.isEmpty) {
      return const Scaffold(body: Center(child: Text('Rapor bulunamadı.')));
    }
    final report = found.single;
    return Scaffold(
      appBar: AppBar(title: const Text('Rapor Ayrıntısı')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            report.title,
            key: const Key('report-detail-title'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          Text(report.description),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(report.category.displayName)),
              Chip(label: Text('Sertifika: ${report.certification.name}')),
              Chip(label: Text('Tazelik: ${report.freshness.name}')),
            ],
          ),
          Text(
            'Sahip: ${report.owner} • Son üretim: ${report.lastGenerated}\nKaynaklar: ${report.sourceModules.join(", ")}',
          ),
          const SizedBox(height: 16),
          const Text(
            'Temel Metrikler',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          ...state.metrics.map(
            (m) => Card(
              child: ListTile(
                title: Text('${m.name} (${m.unit})'),
                subtitle: Text(
                  '${m.description}\nHesaplama: ${m.calculation}\nKaynak: ${m.source} • Sürüm ${m.version} • ${m.state.name}',
                ),
              ),
            ),
          ),
          const Text(
            'Erişilebilir Veri Tablosu',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const Card(
            child: ListTile(
              title: Text('Katılım Oranı: %88.5'),
              subtitle: Text(
                'Dönem: Temmuz 2026 • Kaynak: Attendance • Güncel',
              ),
            ),
          ),
          const Text(
            'İnsan Yorumu',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          ...state.commentary.map(
            (c) => ListTile(
              leading: const Icon(Icons.comment),
              title: Text(c.text),
              subtitle:
                  Text('${c.author} (${c.role}) • ${c.timestamp} • Yorum'),
            ),
          ),
          const Text(
            'Karar Günlüğü',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          ...state.decisions.map(
            (d) => ListTile(
              leading: const Icon(Icons.gavel),
              title: Text(d.title),
              subtitle: Text('${d.owner} • ${d.status.name} • ${d.action}'),
            ),
          ),
          const Text(
            'Rapor Denetimi',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          ...state.audit.where((a) => a.reportId == report.id).map(
                (a) => ListTile(
                  title: Text(a.action),
                  subtitle: Text(
                    '${a.actor} (${a.role}) • ${a.previousValue} → ${a.newValue} • ${a.timestamp}',
                  ),
                ),
              ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {},
                child: const Text('PDF Dışa Aktar (Demo)'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('CSV Dışa Aktar (Demo)'),
              ),
              OutlinedButton(
                onPressed: () => ref
                    .read(reportsControllerProvider.notifier)
                    .saveView(report.id, 'Kaydedilmiş Görünüm'),
                child: const Text('Görünümü Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
