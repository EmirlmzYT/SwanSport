import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../../app/widgets/console_table.dart';
import '../../app/widgets/csv_export.dart';
import '../../app/widgets/status_pill.dart';

// ============================================================== Kullanıcılar

final _peopleQueryProvider =
    StateProvider<ConsoleTableQuery>((ref) => const ConsoleTableQuery());

/// Kullanıcı arama ve yetki yönetimi.
///
/// Arama sunucuda; platform genelinde binlerce profil olabilir, hepsini
/// indirip tarayıcıda süzmek hem yavaş hem gereksiz veri taşımak olurdu.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final query = ref.watch(_peopleQueryProvider);
    final people = ref.watch(adminPeopleProvider(query.search));

    final columns = <ConsoleColumn<AdminPerson>>[
      ConsoleColumn(
        label: 'Kişi',
        flex: 3,
        csv: (p) => p.name,
        cell: (p) => Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.colorScheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(p.initials,
                  style: t.textTheme.labelSmall
                      ?.copyWith(color: t.colorScheme.primary)),
            ),
            const SizedBox(width: ConsoleDensity.md),
            Flexible(
              child: Text(p.name,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
      ConsoleColumn(
        label: 'Bilgi',
        flex: 4,
        csv: (p) => p.subtitle,
        cell: (p) => Text(p.subtitle,
            overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
      ),
      ConsoleColumn(
        label: 'Kulüp',
        flex: 2,
        csv: (p) => p.clubName ?? '',
        cell: (p) => Text(p.clubName ?? '—',
            overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
      ),
      ConsoleColumn(
        label: 'Yetki',
        width: 150,
        csv: (p) => p.isAdmin ? 'Platform yöneticisi' : '',
        cell: (p) => p.isAdmin
            ? const StatusPill(label: 'Platform yöneticisi', tone: PillTone.bad)
            : const SizedBox.shrink(),
      ),
    ];

    return Column(
      children: [
        ConsoleToolbar(
          query: query,
          searchHint: 'İsim veya kullanıcı adı…',
          onQueryChanged: (q) =>
              ref.read(_peopleQueryProvider.notifier).state = q,
          onExport: () async {
            await downloadCsv(
              fileName: csvFileName('kullanicilar'),
              columns: columns,
              rows: people.valueOrNull ?? const [],
            );
          },
        ),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(
          child: ConsoleTable<AdminPerson>(
            columns: columns,
            rows: people.valueOrNull ?? const [],
            loading: people.isLoading,
            error: people.hasError ? people.error : null,
            query: query,
            // Arama sonucu sunucuda zaten sınırlı; sayfalayıcı gelen sayıyı
            // gösteriyor, sayfa bölmüyor.
            totalCount: (people.valueOrNull ?? const []).length,
            rowId: (p) => p.id,
            emptyMessage: query.search.isEmpty
                ? 'Aramak için bir isim yaz.'
                : 'Eşleşen kullanıcı yok.',
            onQueryChanged: (q) =>
                ref.read(_peopleQueryProvider.notifier).state = q,
            onRowTap: (p) => _toggleAdmin(context, ref, p),
          ),
        ),
      ],
    );
  }

  /// Platform yöneticiliğini açıp kapatır.
  ///
  /// Onay penceresi bilerek var: bu yetki, platformdaki her kulübün verisine
  /// erişim demek. Yanlışlıkla tek tıkla verilmemeli.
  Future<void> _toggleAdmin(
      BuildContext context, WidgetRef ref, AdminPerson p) async {
    final next = !p.isAdmin;
    // Diyalogdan sonra context'e dokunmamak için şimdi alıyoruz.
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(next
            ? 'Platform yöneticisi yapılsın mı?'
            : 'Yöneticilik kaldırılsın mı?'),
        content: Text(
          next
              ? '${p.name} platformdaki tüm kulüplerin verisine ve onay '
                  'panellerine erişebilecek.'
              : '${p.name} artık yönetim ekranlarına erişemeyecek.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Onayla')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(adminServiceProvider).setPlatformAdmin(p.id, next);
      ref.invalidate(adminPeopleProvider);
      messenger.showSnackBar(
          SnackBar(content: Text('${p.name} güncellendi.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Güncellenemedi: $e')));
    }
  }
}

// ================================================================ Moderasyon

/// Açık şikayet kuyruğu.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final async = ref.watch(openReportsProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xxl),
          child: SelectableText('Şikayetler yüklenemedi: $e',
              textAlign: TextAlign.center, style: t.textTheme.bodySmall),
        ),
      ),
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Text('Açık şikayet yok. Kuyruk temiz.',
                style: t.textTheme.bodySmall),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(ConsoleDensity.lg),
          itemCount: reports.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: t.colorScheme.outline),
          itemBuilder: (_, i) => _ReportRowTile(report: reports[i]),
        );
      },
    );
  }
}

class _ReportRowTile extends ConsumerWidget {
  const _ReportRowTile({required this.report});

  final ReportRow report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ConsoleDensity.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: StatusPill(
                label: report.targetLabel, tone: PillTone.warning),
          ),
          const SizedBox(width: ConsoleDensity.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.reasonLabel,
                    style: t.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (report.detail != null && report.detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  SelectableText(report.detail!,
                      style: t.textTheme.bodySmall),
                ],
                const SizedBox(height: 2),
                Text(
                  '${report.reporterName ?? 'Bilinmeyen'} · '
                  '${_fmt(report.createdAt)}',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: ConsoleDensity.lg),
          OutlinedButton(
            onPressed: () => _review(context, ref, dismiss: true),
            child: const Text('Yersiz'),
          ),
          const SizedBox(width: ConsoleDensity.sm),
          FilledButton(
            onPressed: () => _review(context, ref, dismiss: false),
            child: const Text('İşlem yapıldı'),
          ),
        ],
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref, {
    required bool dismiss,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(moderationServiceProvider)
          .reviewReport(report.id, dismiss: dismiss);
      ref.invalidate(openReportsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(dismiss
            ? 'Şikayet yersiz olarak kapatıldı.'
            : 'Şikayet işlendi olarak kapatıldı.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Kapatılamadı: $e')));
    }
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// ================================================================== Metrikler

/// Platform geneli sayılar.
class MetricsScreen extends ConsumerWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final async = ref.watch(platformStatsProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xxl),
          child: SelectableText('Metrikler yüklenemedi: $e',
              textAlign: TextAlign.center, style: t.textTheme.bodySmall),
        ),
      ),
      data: (s) => SingleChildScrollView(
        padding: const EdgeInsets.all(ConsoleDensity.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bekleyen işler', style: t.textTheme.titleMedium),
            const SizedBox(height: ConsoleDensity.md),
            Wrap(
              spacing: ConsoleDensity.lg,
              runSpacing: ConsoleDensity.lg,
              children: [
                // Önce eyleme çağıran sayılar: bunlar sıfır değilse birinin
                // bir şey yapması gerekiyor demektir.
                _Stat(
                    label: 'Onay bekleyen kulüp',
                    value: s.clubsPending,
                    urgent: s.clubsPending > 0),
                _Stat(
                    label: 'Onay bekleyen kimlik',
                    value: s.credsPending,
                    urgent: s.credsPending > 0),
                _Stat(
                    label: 'Açık şikayet',
                    value: s.reportsOpen,
                    urgent: s.reportsOpen > 0),
              ],
            ),
            const SizedBox(height: ConsoleDensity.xxl),
            Text('Platform', style: t.textTheme.titleMedium),
            const SizedBox(height: ConsoleDensity.md),
            Wrap(
              spacing: ConsoleDensity.lg,
              runSpacing: ConsoleDensity.lg,
              children: [
                _Stat(label: 'Kullanıcı', value: s.people),
                _Stat(label: 'Aktif kulüp', value: s.clubsActive),
                _Stat(label: 'Antrenör', value: s.coaches),
                _Stat(label: 'Sporcu', value: s.athletes),
                _Stat(label: 'Gönderi', value: s.posts),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.urgent = false,
  });

  final String label;
  final int value;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final accent = urgent ? t.colorScheme.error : t.colorScheme.primary;

    return Container(
      width: 190,
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        border: Border.all(
            color: urgent
                ? accent.withValues(alpha: .35)
                : t.colorScheme.outline),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        color: urgent ? accent.withValues(alpha: .06) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: t.textTheme.labelSmall),
          const SizedBox(height: ConsoleDensity.sm),
          Text(
            '$value',
            style: t.textTheme.titleLarge?.copyWith(
              fontSize: 28,
              color: urgent ? accent : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
