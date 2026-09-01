import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Bekleyen işler — kulüp yöneticisinin "bugün ne yapmam gerekiyor" cevabı.
///
/// **Neden var:** denetimde kulüp yöneticisinin bu soruya cevap bulmak için
/// modül modül gezmek zorunda olduğu çıktı. Onay bekleyen başvuru finansın
/// yanında, gecikmiş aidat başka ekranda; ikisini de görmek için ikisine de
/// girmek gerekiyordu.
///
/// **Hiçbir şey beklemiyorsa hiç çizilmiyor.** Çalışan bir şeyin yanına
/// "her şey yolunda" kutusu koymak ekranı kalabalıklaştırıyor ve zamanla
/// göz onu atlamayı öğreniyor — asıl bir şey belirdiğinde de atlıyor.
///
/// Yeni sorgu yazılmadı: iki sayaç da mevcut sağlayıcılardan geliyor.
class PendingWork extends ConsumerWidget {
  const PendingWork({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;

    final applications =
        ref.watch(clubPendingApplicationsProvider).valueOrNull ?? const [];
    final receivables = ref.watch(receivablesProvider).valueOrNull ?? const [];

    // Gecikmiş: en eski ödenmemişi bir aydan eskiye düşmüş olanlar.
    final overdue = receivables
        .where((r) =>
            r.oldest != null &&
            DateTime.now().difference(r.oldest!).inDays > 30)
        .toList();

    final items = <_Item>[
      if (applications.isNotEmpty)
        _Item(
          icon: Icons.person_add_alt_1_rounded,
          label: applications.length == 1
              ? '1 başvuru onay bekliyor'
              : '${applications.length} başvuru onay bekliyor',
          route: '/onay-paneli',
          tone: c.accent,
        ),
      if (overdue.isNotEmpty)
        _Item(
          icon: Icons.receipt_long_rounded,
          label: overdue.length == 1
              ? '1 sporcunun aidatı gecikti'
              : '${overdue.length} sporcunun aidatı gecikti',
          route: '/finans',
          tone: c.danger,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: SwanSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bekleyen işler', style: SwanType.h3(c.ink)),
          const SizedBox(height: SwanSpace.sm),
          for (final it in items) ...[
            _row(context, c, it),
            const SizedBox(height: SwanSpace.sm),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, SwanPalette c, _Item it) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pushNamed(context, it.route),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.lg, vertical: SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.md),
            // Sol şerit durumu renkle de söylüyor ama metin zaten yazıyor;
            // renk tek başına bilgi taşımıyor.
            border: Border(left: BorderSide(color: it.tone, width: 3)),
          ),
          child: Row(children: [
            Icon(it.icon, size: 18, color: it.tone),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Text(it.label,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.inkMuted),
          ]),
        ),
      );
}

class _Item {
  const _Item({
    required this.icon,
    required this.label,
    required this.route,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String route;
  final Color tone;
}
