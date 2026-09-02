import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import 'work_queue.dart';

/// Bütçe, faaliyet maliyeti ve nakit tahmini.
///
/// İki kural bu ekranın tamamını belirliyor:
///
/// 1. **Gerçekleşen elle girilmiyor.** "Harcandı" diye bir alan yok; rakam
///    `expenses`'ten geliyor. Elle giriş, defterle bütçenin ayrışması demek
///    ve hangisinin doğru olduğu hiçbir zaman bilinemez.
///
/// 2. **Tahmin kesin bakiye gibi sunulmuyor.** Onaylı, beklenen ve belirsiz
///    ayrı sütunlarda; tek bir "90 gün sonra şu kadar paran olacak" sayısı
///    yok. Kulübün olmayan parayı var sanması, bu ekranın üretebileceği en
///    pahalı hata.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final forecast = ref.watch(cashForecastProvider);
    final lines = ref.watch(budgetLinesProvider);

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        const ConsolePageHeader(
          title: 'Bütçe ve Nakit Tahmini',
          subtitle: 'Gerçekleşen tutarlar defterden hesaplanıyor, elle '
              'girilmiyor. Tahminde onaylı, beklenen ve belirsiz ayrı durur.',
        ),
        const SizedBox(height: ConsoleDensity.xl),

        Text('Nakit tahmini', style: t.textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.sm),
        AsyncSection<List<CashForecast>>(
          value: forecast,
          errorPrefix: 'Nakit tahmini alınamadı',
          builder: (list) => list.isEmpty
              ? Text('Tahmin için yeterli veri yok.',
                  style: t.textTheme.bodySmall)
              : Wrap(
                  spacing: ConsoleDensity.lg,
                  runSpacing: ConsoleDensity.lg,
                  children: [for (final f in list) _ForecastCard(f: f)],
                ),
        ),

        const SizedBox(height: ConsoleDensity.xxl),
        Row(children: [
          Expanded(
              child: Text('Bütçe — gerçekleşen',
                  style: t.textTheme.titleMedium)),
          TextButton.icon(
            onPressed: () => _openBudgetDialog(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Bütçe satırı ekle'),
          ),
        ]),
        const SizedBox(height: ConsoleDensity.sm),
        AsyncSection<List<BudgetLine>>(
          value: lines,
          errorPrefix: 'Bütçe alınamadı',
          builder: (list) => list.isEmpty
              ? Text('Bu dönem için bütçe satırı tanımlanmadı.',
                  style: t.textTheme.bodySmall)
              : Column(children: [for (final l in list) _BudgetRow(line: l)]),
        ),
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.f});

  final CashForecast f;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    Widget line(String label, num value, {String? hint, Color? color}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: t.textTheme.bodySmall?.copyWith(color: color)),
            ),
            Text(fmtMoney(value),
                style: t.textTheme.bodySmall?.copyWith(color: color)),
            if (hint != null) ...[
              const SizedBox(width: ConsoleDensity.xs),
              Tooltip(
                message: hint,
                child: Icon(Icons.info_outline_rounded,
                    size: 13, color: t.colorScheme.outline),
              ),
            ],
          ]),
        );

    return SizedBox(
      width: 340,
      child: Container(
        padding: const EdgeInsets.all(ConsoleDensity.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          border: Border.all(
              color: f.hasShortfall
                  ? t.colorScheme.error.withValues(alpha: 0.4)
                  : t.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${f.horizonDays} gün', style: t.textTheme.titleSmall),
            const SizedBox(height: ConsoleDensity.sm),
            line('Bugünkü bakiye', f.opening),
            line('Onaylı giriş', f.confirmedIn,
                hint: 'Tahsil edilmiş ama hesaba bağlanmamış'),
            line('Onaylı çıkış', -f.confirmedOut),
            const Divider(height: ConsoleDensity.lg),
            // Kötümser uç: yalnızca onaylı hareketler.
            Row(children: [
              Expanded(
                  child: Text('En düşük', style: t.textTheme.labelMedium)),
              Text(fmtMoney(f.projectedLow),
                  style: t.textTheme.titleSmall?.copyWith(
                      color: f.projectedLow < 0 ? t.colorScheme.error : null)),
            ]),
            const SizedBox(height: ConsoleDensity.xs),
            line('Beklenen tahsilat', f.expectedIn),
            line('Vadesi gelen taahhüt', -f.expectedOut),
            Row(children: [
              Expanded(
                  child: Text('En yüksek', style: t.textTheme.labelMedium)),
              Text(fmtMoney(f.projectedHigh),
                  style: t.textTheme.titleSmall),
            ]),
            if (f.uncertainOut > 0) ...[
              const Divider(height: ConsoleDensity.lg),
              // Belirsiz, iki projeksiyonun HİÇBİRİNE dahil değil. Ayrı
              // gösterilmesinin sebebi bu.
              line('Bütçelenmiş, taahhüt edilmemiş', f.uncertainOut,
                  hint: 'Tahmine dahil DEĞİL — planlanmış ama henüz '
                      'harcanmamış veya bağlanmamış tutar',
                  color: t.colorScheme.outline),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.line});

  final BudgetLine line;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ratio = line.planned > 0
        ? ((line.actual + line.committed) / line.planned).clamp(0.0, 1.0)
        : 0.0;

    final critical = line.risk == 'kritik';
    final attention = line.risk == 'dikkat';

    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(
            color: critical
                ? t.colorScheme.error.withValues(alpha: 0.4)
                : t.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('${line.scopeLabel} · ${line.category}',
                  style: t.textTheme.titleSmall),
            ),
            // Renk tek başına bilgi taşımıyor — etiket de var.
            Text(
              critical
                  ? 'Bütçe aşıldı'
                  : attention
                      ? 'Sınıra yakın'
                      : 'Normal',
              style: t.textTheme.labelSmall?.copyWith(
                  color: critical
                      ? t.colorScheme.error
                      : t.colorScheme.onSurfaceVariant),
            ),
          ]),
          const SizedBox(height: ConsoleDensity.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: t.colorScheme.surfaceContainerHighest,
              color: critical
                  ? t.colorScheme.error
                  : attention
                      ? t.colorScheme.tertiary
                      : t.colorScheme.primary,
            ),
          ),
          const SizedBox(height: ConsoleDensity.sm),
          Wrap(
            spacing: ConsoleDensity.lg,
            children: [
              _stat(t, 'Planlanan', fmtMoney(line.planned)),
              _stat(t, 'Harcanan', fmtMoney(line.actual)),
              _stat(t, 'Bağlanan', fmtMoney(line.committed)),
              _stat(t, 'Kalan', fmtMoney(line.remaining),
                  color: line.isOverrun ? t.colorScheme.error : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(ThemeData t, String label, String value, {Color? color}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.textTheme.labelSmall),
          Text(value, style: t.textTheme.bodySmall?.copyWith(color: color)),
        ],
      );
}

Future<void> _openBudgetDialog(BuildContext context, WidgetRef ref) async {
  final planned = TextEditingController();
  final now = DateTime.now();
  var from = DateTime(now.year, now.month, 1);
  var to = DateTime(now.year, now.month + 1, 0);

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Bütçe satırı ekle'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kulüp geneli, bu ay. Takım/tesis/etkinlik kırılımı bütçe '
                'satırı oluştuktan sonra düzenlenebilir.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: ConsoleDensity.md),
              TextField(
                controller: planned,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Planlanan tutar'),
              ),
              const SizedBox(height: ConsoleDensity.md),
              Text('Dönem: ${fmtDate(from)} – ${fmtDate(to)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet')),
        ],
      ),
    ),
  );

  if (ok != true) return;
  final value = num.tryParse(planned.text.replaceAll(',', '.'));
  if (value == null || value <= 0) return;

  final club = await ref.read(activeClubProvider.future);
  if (club == null) return;

  String d(DateTime x) => '${x.year.toString().padLeft(4, '0')}-'
      '${x.month.toString().padLeft(2, '0')}-'
      '${x.day.toString().padLeft(2, '0')}';

  try {
    await ref.read(financeOpsServiceProvider).saveBudget({
      'club_id': club.id,
      'period_from': d(from),
      'period_to': d(to),
      'scope': 'club',
      'planned': value,
      'status': 'approved',
    });
    ref.invalidate(budgetLinesProvider);
    ref.invalidate(cashForecastProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
