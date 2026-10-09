import 'diagnostic_fix_dialog.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/modules/console_module.dart';
import '../../app/theme/console_theme.dart';

typedef DiagnosticQuery = ({
  String? status,
  String? release,
  String? platform,
  String? screen,
  int offset
});
final diagnosticIssuesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, DiagnosticQuery>((ref, q) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(consoleAccessProvider).isPlatformAdmin) {
    return const [];
  }
  return ref.watch(diagnosticsServiceProvider).issues(
      status: q.status,
      release: q.release,
      platform: q.platform,
      screen: q.screen,
      offset: q.offset);
});
final diagnosticOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(consoleAccessProvider).isPlatformAdmin) {
    return const {};
  }
  return ref.watch(diagnosticsServiceProvider).overview();
});
final diagnosticDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(consoleAccessProvider).isPlatformAdmin) {
    return const {};
  }
  return ref.watch(diagnosticsServiceProvider).detail(id);
});

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final _release = TextEditingController(), _screen = TextEditingController();
  String? _status, _platform, _selected, _appliedRelease, _appliedScreen;
  int _offset = 0;
  bool _saving = false;
  DiagnosticQuery get _query => (
        status: _status,
        release: _appliedRelease,
        platform: _platform,
        screen: _appliedScreen,
        offset: _offset
      );
  void _refresh() {
    ref.invalidate(diagnosticOverviewProvider);
    ref.invalidate(diagnosticIssuesProvider);
    ref.invalidate(diagnosticDetailProvider);
  }

  @override
  void dispose() {
    _release.dispose();
    _screen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(consoleAccessProvider).isPlatformAdmin) {
      return const Center(
          child: Text('Bu ekran yalnızca platform yöneticisine açıktır.'));
    }
    final theme = Theme.of(context);
    final prefs = ref.watch(diagnosticPreferencesProvider);
    final overview = ref.watch(diagnosticOverviewProvider);
    final rows = ref.watch(diagnosticIssuesProvider(_query));
    return ListView(
        padding: const EdgeInsets.all(ConsoleDensity.xl),
        children: [
          Row(children: [
            Expanded(
                child: Text('Hata ve kullanım merkezi',
                    style: theme.textTheme.titleLarge)),
            IconButton(
                tooltip: 'Yenile',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh))
          ]),
          const Text(
              'Yalnızca teknik kayıt paylaşmayı seçen oturumları kapsar. Ekran veya kullanıcı içerikleri otomatik kaydedilmez.'),
          const SizedBox(height: ConsoleDensity.lg),
          ExpansionTile(
              title: const Text('Bu cihazdaki konsol kayıt tercihleri'),
              children: [
                SwitchListTile(
                    title: const Text('Konsol hata tanılaması'),
                    value: prefs.errors,
                    onChanged: (v) => _preference(errors: v)),
                SwitchListTile(
                    title: const Text('Konsol kullanım ve performans ölçümü'),
                    value: prefs.usage,
                    onChanged: (v) => _preference(usage: v))
              ]),
          overview.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => _error(),
              data: (data) {
                final alerts = (data['alerts'] as List?) ?? [];
                final flows = (data['flows'] as List?) ?? [];
                final consistency = (data['consistency'] as List?) ?? [];
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: ConsoleDensity.lg, children: [
                        Text('Açık hata: ${data['open_issues'] ?? 0}'),
                        Text('Teyit bekleyen talep: ${data['pending_fix_confirmations'] ?? 0}'),
                        Text('Kullanıcı teyidi: ${data['confirmed_fix_tickets'] ?? 0}'),
                        Text('Düzeltme sonrası sorun: ${data['fix_regressions'] ?? 0}'),
                        Text('Son 24 saat hata: ${data['errors_24h'] ?? 0}'),
                        Text(
                            'Kayıt paylaşan oturum: ${data['sessions_24h'] ?? 0}')
                      ]),
                      if (consistency.isNotEmpty)
                        ExpansionTile(
                          title: const Text('Mali kayıt tutarlılığı'),
                          subtitle: const Text(
                              'Veritabanı kontrolü; teknik kayıt iznine bağlı değildir.'),
                          children: [
                            for (final check in consistency)
                              ListTile(
                                dense: true,
                                title: Text(check['code'] ==
                                        'invalid_financial_amount'
                                    ? 'Geçersiz tutarlı düzeltme'
                                    : 'Onaylı fakat defter hareketi eşleşmeyen düzeltme'),
                                trailing: Text('${check['count']} kayıt'),
                              ),
                            const Padding(
                                padding: EdgeInsets.all(ConsoleDensity.md),
                                child: Text(
                                    'Bu kontrol yalnızca mali ters kayıtları kapsar. Ayrıntı ve inceleme kulübün Mali Operasyonlar ekranındadır.')),
                          ],
                        ),
                      if (alerts.isNotEmpty)
                        Card(
                            child: Padding(
                                padding:
                                    const EdgeInsets.all(ConsoleDensity.lg),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Son saatteki uyarılar',
                                          style: theme.textTheme.titleMedium),
                                      for (final a in alerts)
                                        Text(
                                            '${_alertLabel(a['code'])}: ${a['alert_key']} · ${a['qty']} olay')
                                    ]))),
                      ExpansionTile(
                          title: const Text('Son 24 saat işlem sonuçları'),
                          children: [
                            const Text(
                                'İşlem sayıları ölçümü açık oturumlardan gelir. Tamamlanmama tek başına hata kanıtı değildir.'),
                            for (final f in flows)
                              ListTile(
                                  dense: true,
                                  title: Text('${f['operation']}'),
                                  subtitle: Text(
                                      'Başladı: ${f['started']} · Başarılı: ${f['succeeded']} · Hata: ${f['failed']} · Ortalama: ${f['avg_ms'] ?? 0} ms'))
                          ])
                    ]);
              }),
          const Divider(),
          Wrap(
              spacing: ConsoleDensity.md,
              runSpacing: ConsoleDensity.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _status ?? 'all',
                        decoration: const InputDecoration(labelText: 'Durum'),
                        items: [
                          for (final e in const {
                            'all': 'Tümü',
                            'new': 'Yeni',
                            'investigating': 'İnceleniyor',
                            'resolved': 'Düzeltme bildirildi',
                            'regressed': 'Yeniden oluştu'
                          }.entries)
                            DropdownMenuItem(value: e.key, child: Text(e.value))
                        ],
                        onChanged: (v) => setState(() {
                              _status = v == 'all' ? null : v;
                              _offset = 0;
                              _selected = null;
                            }))),
                SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: 'all',
                        decoration:
                            const InputDecoration(labelText: 'Platform'),
                        items: [
                          for (final p in [
                            'all',
                            'web',
                            'android',
                            'ios',
                            'windows',
                            'linux',
                            'macos'
                          ])
                            DropdownMenuItem(
                                value: p, child: Text(p == 'all' ? 'Tümü' : p))
                        ],
                        onChanged: (v) => setState(() {
                              _platform = v == 'all' ? null : v;
                              _offset = 0;
                              _selected = null;
                            }))),
                SizedBox(
                    width: 160,
                    child: TextField(
                        controller: _release,
                        decoration: const InputDecoration(
                            labelText: 'Sürüm', hintText: '0.5.1+16'))),
                SizedBox(
                    width: 220,
                    child: TextField(
                        controller: _screen,
                        decoration: const InputDecoration(
                            labelText: 'Ekran yolu', hintText: '/destek'))),
                FilledButton(
                    onPressed: () => setState(() {
                          _appliedRelease = _release.text.trim().isEmpty
                              ? null
                              : _release.text.trim();
                          _appliedScreen = _screen.text.trim().isEmpty
                              ? null
                              : _screen.text.trim();
                          _offset = 0;
                          _selected = null;
                        }),
                    child: const Text('Filtrele'))
              ]),
          const SizedBox(height: ConsoleDensity.lg),
          rows.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => _error(),
              data: (list) => Column(children: [
                    if (list.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(ConsoleDensity.lg),
                          child: Text('Bu filtrelerde hata kaydı yok.')),
                    for (final issue in list)
                      Card(
                          child: ListTile(
                              title: Text(
                                  '${issue['operation']} · ${issue['code']}'),
                              subtitle: Text(
                                  '${_stateLabel(issue['state'])} · ${issue['occurrence_count']} tekrar · ${issue['session_count']} oturum\n${issue['release']} · ${issue['platform']} · ${issue['screen']}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => setState(
                                  () => _selected = issue['id'] as String))),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TextButton(
                          onPressed: _offset == 0
                              ? null
                              : () => setState(() {
                                    _offset -= 50;
                                    _selected = null;
                                  }),
                          child: const Text('Önceki')),
                      Text('Sayfa ${_offset ~/ 50 + 1}'),
                      TextButton(
                          onPressed: list.isNotEmpty &&
                                  _offset + list.length <
                                      (list.first['total_count'] as num).toInt()
                              ? () => setState(() {
                                    _offset += 50;
                                    _selected = null;
                                  })
                              : null,
                          child: const Text('Sonraki'))
                    ])
                  ])),
          if (_selected != null) _detail(_selected!),
        ]);
  }

  Widget _error() => const Padding(
      padding: EdgeInsets.all(ConsoleDensity.lg),
      child: Text(
          'Teknik kayıtlar alınamadı. Bağlantıyı ve 0086 migration kurulumunu kontrol edin.'));
  Future<void> _preference({bool? errors, bool? usage}) async {
    try {
      await ref
          .read(diagnosticPreferencesProvider.notifier)
          .update(errors: errors, usage: usage);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tercih kaydedilemedi.')));
      }
    }
  }

  Widget _detail(String id) => ref.watch(diagnosticDetailProvider(id)).when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => _error(),
      data: (data) {
        final events = (data['events'] as List?) ?? [];
        final server = (data['server_events'] as List?) ?? [];
        return Card(
            child: Padding(
                padding: const EdgeInsets.all(ConsoleDensity.lg),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText('Hata kimliği: $id'),
                      Text('Hata ayrıntısı',
                          style: Theme.of(context).textTheme.titleMedium),
                      Wrap(spacing: ConsoleDensity.md, children: [
                        OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _setStatus(id, 'investigating'),
                            child: const Text('İnceleniyor')),
                        FilledButton(
                            onPressed: _saving ? null : () => _declareFix(id),
                            child: const Text('Düzeltildi'))
                      ]),
                      if (data['fix'] is Map) ...[
                        Text(
                            'Bildirilen düzeltme: ${(data['fix'] as Map)['release']} · ${(data['fix'] as Map)['platform']}'),
                        Text(
                            'Bu sürüm ve sonrasında ${(data['fix'] as Map)['regression_count']} teknik tekrar.'),
                        Text(
                            'Kullanıcı teyidi: ${(data['verification'] as Map?)?['confirmed'] ?? 0} çözüldü · ${(data['verification'] as Map?)?['still_failing'] ?? 0} devam ediyor · ${(data['verification'] as Map?)?['pending'] ?? 0} bekliyor'),
                        const Text(
                            'Hata görülmemesi çözümün doğrulandığı anlamına gelmez.'),
                      ],
                      for (final event in events)
                        ExpansionTile(
                            title: Text(
                                '${event['occurred_at']} · ${event['screen']} · ${event['release']}'),
                            subtitle: Text('Takip kodu: ${event['trace_id']}'),
                            children: [
                              SelectableText(
                                  const JsonEncoder.withIndent('  ').convert({
                                'kaynak_konumları': event['frames'],
                                'son_işlemler': event['breadcrumbs'],
                                'sunucudaki_izler': server
                                    .where((s) =>
                                        s['trace_id'] == event['trace_id'])
                                    .toList()
                              }))
                            ])
                    ])));
      });
  Future<void> _declareFix(String id) async {
    final selected = await showDialog<(String, String)>(
        context: context, builder: (_) => const DiagnosticFixDialog());
    if (selected == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(diagnosticsServiceProvider)
          .declareFix(id, selected.$1, selected.$2);
      _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Düzeltme kaydedilemedi. Sürümü ve yetkini kontrol et.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setStatus(String id, String status) async {
    setState(() => _saving = true);
    try {
      await ref.read(diagnosticsServiceProvider).setStatus(id, status);
      _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hata durumu kaydedilemedi.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _stateLabel(dynamic s) => switch (s) {
      'new' => 'Yeni',
      'investigating' => 'İnceleniyor',
      'resolved' => 'Düzeltme bildirildi',
      'regressed' => 'Yeniden oluştu',
      _ => 'Bilinmiyor'
    };
String _alertLabel(dynamic s) => switch (s) {
      'recurring_error' => 'Tekrarlayan hata',
      'high_failure_rate' => 'Yükselen başarısızlık oranı',
      'slow_operation' => 'Yavaş işlem',
      _ => 'Teknik uyarı'
    };
