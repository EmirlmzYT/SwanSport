import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../finance/work_queue.dart';

/// Uygunluk tablosu — kimin sahaya çıkamayacağı.
///
/// **BU EKRANDA KISIT KALDIRMA DÜĞMESİ YOK VE OLMAYACAK.**
///
/// Sağlık kısıtını yalnızca yetkili sağlık görevlisi kaldırabiliyor ve bunu
/// kendi kaydını güncelleyerek yapıyor. Buraya bir "geçersiz kıl" düğmesi
/// koymak, sunucunun reddedeceği bir eylemi kullanıcıya vaat etmek olurdu —
/// ya da daha kötüsü, birileri sunucuyu gevşetmeye çalışırdı.
///
/// Yönetici burada **teşhis görmüyor**: `club_eligibility_board` yalnızca üç
/// rozet ve bir gerekçe etiketi döndürüyor. Rapor, doktor notu ve belge
/// referansı o fonksiyondan hiç çıkmıyor.
class EligibilityScreen extends ConsumerWidget {
  const EligibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final board = ref.watch(eligibilityBoardProvider);
    final risk = ref.watch(operationalRiskProvider);

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        const ConsolePageHeader(
          title: 'Uygunluk ve Operasyon Riski',
          subtitle: 'Sahaya çıkamayacak sporcular ve kulübün açık riskleri. '
              'Sağlık kısıtı burada kaldırılamaz — yalnızca yetkili sağlık '
              'görevlisi kendi kaydını güncelleyerek kaldırabilir.',
        ),
        const SizedBox(height: ConsoleDensity.xl),

        Text('Operasyon riski', style: t.textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.xs),
        Text(
          'Tek bir puan yok. Hangi gerekçenin kaç kayıttan geldiği yazılı; '
          'karta dokunarak ilgili ekrana gidilir.',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: ConsoleDensity.md),
        AsyncSection<OperationalRisk>(
          value: risk,
          errorPrefix: 'Risk tablosu alınamadı',
          builder: (r) {
            final active = r.active;
            if (active.isEmpty) {
              return Text('Açık risk yok.', style: t.textTheme.bodySmall);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _levelChip(context, r),
                const SizedBox(height: ConsoleDensity.md),
                Wrap(
                  spacing: ConsoleDensity.lg,
                  runSpacing: ConsoleDensity.lg,
                  children: [
                    for (final x in active)
                      WorkCard(
                        item: FinanceWorkItem(
                          code: x.code,
                          title: x.label,
                          count: x.qty,
                          total: 0,
                          risk: switch (x.severity) {
                            'kritik' => FinanceRisk.critical,
                            'dikkat' => FinanceRisk.attention,
                            _ => FinanceRisk.info,
                          },
                          why: x.severityLabel,
                          route: x.route,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: ConsoleDensity.xxl),
        Text('Sahaya çıkamayanlar', style: t.textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.xs),
        Text(
          'Kesin engel: süresi dolmuş lisans veya aktif sağlık kısıtı. '
          '"Onay bekliyor" idari bir eksik, tıbbi bir engel değil.',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: ConsoleDensity.md),
        AsyncSection<List<EligibilityRow>>(
          value: board,
          errorPrefix: 'Uygunluk tablosu alınamadı',
          builder: (rows) => rows.isEmpty
              ? Text('Bütün aktif sporcular uygun.',
                  style: t.textTheme.bodySmall)
              : Column(children: [for (final r in rows) _row(context, r)]),
        ),
      ],
    );
  }

  Widget _levelChip(BuildContext context, OperationalRisk r) {
    final t = Theme.of(context);
    final (fg, icon) = switch (r.level) {
      'kritik' => (t.colorScheme.error, Icons.error_outline_rounded),
      'dikkat' => (t.colorScheme.tertiary, Icons.warning_amber_rounded),
      _ => (t.colorScheme.primary, Icons.check_circle_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.md, vertical: ConsoleDensity.sm),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      // Metin + ikon + renk birlikte. Renk tek başına bilgi taşımıyor.
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: ConsoleDensity.sm),
        Text(r.levelLabel,
            style: t.textTheme.titleSmall?.copyWith(color: fg)),
        const SizedBox(width: ConsoleDensity.sm),
        Text('${r.active.length} açık gerekçe',
            style: t.textTheme.bodySmall),
      ]),
    );
  }

  Widget _row(BuildContext context, EligibilityRow r) {
    final t = Theme.of(context);
    final blocked = r.isRestricted;

    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(
            color: blocked
                ? t.colorScheme.error.withValues(alpha: 0.4)
                : t.colorScheme.outlineVariant),
      ),
      child: Row(children: [
        Icon(
            blocked
                ? Icons.block_rounded
                : Icons.hourglass_empty_rounded,
            size: 18,
            color: blocked ? t.colorScheme.error : t.colorScheme.outline),
        const SizedBox(width: ConsoleDensity.md),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ConsoleDensity.sm, vertical: 2),
          decoration: BoxDecoration(
            color: t.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(r.athleteRef,
              style: t.textTheme.labelSmall
                  ?.copyWith(fontFamily: 'monospace')),
        ),
        const SizedBox(width: ConsoleDensity.md),
        Expanded(child: Text(r.reasonLabel, style: t.textTheme.bodyMedium)),
        // Etiket metni: renk tek başına bilgi taşımıyor.
        Text(blocked ? 'Kesin engel' : 'Onay bekliyor',
            style: t.textTheme.labelSmall?.copyWith(
                color: blocked
                    ? t.colorScheme.error
                    : t.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}
