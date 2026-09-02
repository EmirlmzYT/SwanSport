import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';

/// İş kuyruğu kartları — mali ve operasyonel kuyruklar aynı bileşeni kullanır.
///
/// Tek yerde durmasının sebebi: konsol girişi, mali iş kuyruğu ve kulüp
/// operasyon merkezi aynı kartı gösteriyor. Üç kopya yazmak, birinde risk
/// rengini düzeltip diğer ikisini unutmak demekti — bu depoda sekme çubuğu
/// tam olarak böyle dört kez kopyalandı.

/// Risk seviyesinin renge çevrimi.
///
/// `swansport_data` renk taşımıyor (değişmez 2); eşleme burada.
({Color fg, Color bg}) _tone(BuildContext context, FinanceRisk risk) {
  final c = Theme.of(context).colorScheme;
  return switch (risk) {
    FinanceRisk.critical => (fg: c.error, bg: c.error.withValues(alpha: 0.10)),
    // Uyarı için ayrı bir jeton yok; ikincil vurgu rengi kullanılıyor.
    FinanceRisk.attention => (
        fg: c.tertiary,
        bg: c.tertiary.withValues(alpha: 0.12)
      ),
    FinanceRisk.info => (fg: c.outline, bg: c.surfaceContainerHighest),
  };
}

String riskLabel(FinanceRisk r) => switch (r) {
      FinanceRisk.critical => 'Kritik',
      FinanceRisk.attention => 'Dikkat',
      FinanceRisk.info => 'Bilgi',
    };

/// Tek bir iş kalemi kartı.
class WorkCard extends StatelessWidget {
  const WorkCard({super.key, required this.item, this.onOpen});

  final FinanceWorkItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tone = _tone(context, item.risk);

    return SizedBox(
      width: 320,
      child: Material(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          onTap: onOpen ?? () => context.go(item.route),
          child: Container(
            padding: const EdgeInsets.all(ConsoleDensity.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ConsoleDensity.radius),
              border: Border.all(color: t.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title,
                          style: t.textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: ConsoleDensity.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ConsoleDensity.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: tone.bg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(riskLabel(item.risk),
                          style: t.textTheme.labelSmall
                              ?.copyWith(color: tone.fg)),
                    ),
                  ],
                ),
                const SizedBox(height: ConsoleDensity.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${item.count}',
                        style: t.textTheme.headlineSmall?.copyWith(
                            color: tone.fg,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                    const SizedBox(width: ConsoleDensity.xs),
                    Text('kayıt', style: t.textTheme.bodySmall),
                    if (item.hasTotal) ...[
                      const Spacer(),
                      Text(fmtMoney(item.total),
                          style: t.textTheme.titleSmall?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                    ],
                  ],
                ),
                const SizedBox(height: ConsoleDensity.sm),
                // Neden önemli. Sayının tek başına anlamı yok: "3 taslak
                // gider" gören kişi ne yapacağını bilmiyor.
                Text(item.why,
                    style: t.textTheme.bodySmall
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kuyruk: en fazla beş kritik iş öne, gerisi katlanabilir listede.
class WorkQueue extends StatefulWidget {
  const WorkQueue({
    super.key,
    required this.top,
    this.others = const [],
    this.emptyTitle = 'Şu anda bekleyen iş yok',
    this.emptyBody,
  });

  final List<FinanceWorkItem> top;
  final List<FinanceWorkItem> others;
  final String emptyTitle;
  final String? emptyBody;

  @override
  State<WorkQueue> createState() => _WorkQueueState();
}

class _WorkQueueState extends State<WorkQueue> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (widget.top.isEmpty && widget.others.isEmpty) {
      // Sade boş durum. Başarı kartı üretilmiyor: yapılacak iş olmadığını
      // söylemenin yolu, yeşil onay işaretleriyle ekranı doldurmak değil.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ConsoleDensity.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          border: Border.all(color: t.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.emptyTitle, style: t.textTheme.titleSmall),
            if (widget.emptyBody != null) ...[
              const SizedBox(height: ConsoleDensity.xs),
              Text(widget.emptyBody!, style: t.textTheme.bodySmall),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: ConsoleDensity.lg,
          runSpacing: ConsoleDensity.lg,
          children: [for (final i in widget.top) WorkCard(item: i)],
        ),
        if (widget.others.isNotEmpty) ...[
          const SizedBox(height: ConsoleDensity.lg),
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded),
            label: Text(_expanded
                ? 'Diğer işleri gizle'
                : 'Tüm işler (${widget.others.length} tane daha)'),
          ),
          if (_expanded) ...[
            const SizedBox(height: ConsoleDensity.sm),
            Wrap(
              spacing: ConsoleDensity.lg,
              runSpacing: ConsoleDensity.lg,
              children: [for (final i in widget.others) WorkCard(item: i)],
            ),
          ],
        ],
      ],
    );
  }
}

/// Ekran başlığı + açıklama — mali ekranların hepsinde aynı.
class ConsolePageHeader extends StatelessWidget {
  const ConsolePageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.textTheme.titleLarge),
              const SizedBox(height: ConsoleDensity.xs),
              Text(subtitle, style: t.textTheme.bodySmall),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Yükleniyor / hata / veri üçlüsü — her mali ekranda tekrar yazılmasın.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.builder,
    this.errorPrefix = 'Veri alınamadı',
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String errorPrefix;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(ConsoleDensity.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      // Hata yutulmuyor: yetkisiz erişim ya da eksik migration "veri yok"
      // gibi görünürse sorun hiç fark edilmiyor.
      error: (e, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ConsoleDensity.lg),
        decoration: BoxDecoration(
          color: t.colorScheme.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          border: Border.all(color: t.colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Text('$errorPrefix: $e',
            style: t.textTheme.bodySmall
                ?.copyWith(color: t.colorScheme.error)),
      ),
      data: builder,
    );
  }
}
