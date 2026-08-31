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
class MetricsScreen extends ConsumerStatefulWidget {
  const MetricsScreen({super.key});

  @override
  ConsumerState<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends ConsumerState<MetricsScreen> {
  /// Ölçüm penceresi. Belediye görüşmesinde "son 30 gün" konuşulacak ama
  /// 7 ve 90 da lazım: 7 "sistem şu an yaşıyor mu", 90 "kalıcı mı".
  int _days = 30;

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: ConsoleDensity.xxl),
            _courtUsage(t),
          ],
        ),
      ),
    );
  }

  // --------------------------- kort kullanımı ------------------------------

  /// Halka açık kort kullanımı — belediye görüşmesinin gövdesi.
  ///
  /// Diğer metriklerden ayrı duruyor çünkü farklı bir soruyu cevaplıyor:
  /// yukarısı "platform ne durumda", burası "belediyeye ne anlatacağız".
  Widget _courtUsage(ThemeData t) {
    final usage = ref.watch(courtUsageProvider(_days));
    final byCourt = ref.watch(courtUsageByCourtProvider(_days));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Halka açık kortlar', style: t.textTheme.titleMedium),
          const SizedBox(width: ConsoleDensity.lg),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 gün')),
              ButtonSegment(value: 30, label: Text('30 gün')),
              ButtonSegment(value: 90, label: Text('90 gün')),
            ],
            selected: {_days},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _days = v.first),
          ),
        ]),
        const SizedBox(height: ConsoleDensity.md),
        usage.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(ConsoleDensity.lg),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          // Hatayı yutmuyoruz: 0041 migration'ı çalıştırılmadıysa RPC yok ve
          // "0 kutu" göstermek yanlış olurdu — sistem kullanılmamış gibi
          // görünürdü. Mesajda sebebi yazıyor.
          error: (e, _) => _Notice(
            'Kort ölçümü okunamadı: $e\n'
            '0041 migration çalıştırıldı mı? Ölçüm ona bağlı.',
          ),
          data: (u) {
            if (u.isEmpty) {
              return const _Notice(
                  'Bu aralıkta hiç kort saati alınmamış. '
                  'Sayı sıfır değil — henüz veri yok.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: ConsoleDensity.lg,
                  runSpacing: ConsoleDensity.lg,
                  children: [
                    // Belediyenin asıl sorusu kutu sayısı değil "kaç kişiye
                    // ulaştı" — o yüzden ilk sırada.
                    _Stat(label: 'Kortta olan kişi', value: u.totalPeople),
                    _Stat(label: 'Tekil kullanıcı', value: u.uniquePlayers),
                    _Stat(label: 'Alınan saat', value: u.slotsTotal),
                    _Stat(label: 'Oynanan saat', value: u.slotsDone),
                    _Pct(
                        label: 'Gelmeme oranı',
                        value: u.noShowPct,
                        urgent: u.noShowPct > 25),
                    _Pct(label: 'Konum doğrulama', value: u.checkinPct),
                    _Stat(label: 'En yoğun saat', value: u.peakHour,
                        suffix: ':00'),
                    _Stat(label: 'İptal', value: u.slotsCancelled),
                  ],
                ),
                const SizedBox(height: ConsoleDensity.xl),
                byCourt.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (rows) => rows.isEmpty
                      ? const SizedBox.shrink()
                      : _CourtTable(rows: rows),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Sayı değil oran gösteren kutu — `_Stat`'in yüzdelik kardeşi.
class _Pct extends StatelessWidget {
  const _Pct({required this.label, required this.value, this.urgent = false});

  final String label;
  final double value;
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
            '${value.toStringAsFixed(1)}%',
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

/// Kort kırılımı. Hiç kullanılmamış kort de listede — "sıfır" da bir bilgi.
class _CourtTable extends StatelessWidget {
  const _CourtTable({required this.rows});

  final List<CourtUsageRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: t.colorScheme.outline),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      ),
      // Dar pencerede tablo yatay kayar; sayfa yana kaymaz.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Kort')),
            DataColumn(label: Text('Alınan'), numeric: true),
            DataColumn(label: Text('Oynanan'), numeric: true),
            DataColumn(label: Text('Gelmeme'), numeric: true),
            DataColumn(label: Text('Doluluk'), numeric: true),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text(r.venue == null
                    ? r.courtName
                    : '${r.venue} · ${r.courtName}')),
                DataCell(Text('${r.slotsTotal}')),
                DataCell(Text('${r.slotsDone}')),
                DataCell(Text('${r.noShowPct.toStringAsFixed(1)}%')),
                DataCell(Text('${r.fillPct.toStringAsFixed(1)}%')),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Kısa açıklama kutusu — boş/hatalı durumu sessiz bırakmamak için.
class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        border: Border.all(color: t.colorScheme.outline),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      ),
      child: SelectableText(text, style: t.textTheme.bodySmall),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.urgent = false,
    this.suffix = '',
  });

  final String label;
  final int value;
  final bool urgent;

  /// "En yoğun saat" için `:00` — sayının kendisi saat, birimsiz yazınca
  /// 19 kutu alınmış gibi okunuyor.
  final String suffix;

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
            '$value$suffix',
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
