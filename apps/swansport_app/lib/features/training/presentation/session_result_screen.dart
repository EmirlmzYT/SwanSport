import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Antrenör sonuç ekranı.
///
/// SIRALAMA YOK. Sporcular arasında herkese açık bir leaderboard bilerek
/// üretilmiyor; liste ada göre sıralı geliyor, puana göre değil. Bu ekranı
/// yalnızca kulüp personeli görüyor (`session_summary` gövdesinde kontrol).
///
/// Uyarılar "bak" demek, "yanlış" demek değil: eksik set, az atış, son sette
/// düşüş. Antrenör inceler, sistem hüküm vermez.
class SessionResultScreen extends ConsumerWidget {
  const SessionResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final args = ModalRoute.of(context)?.settings.arguments;
    final id = args is Map ? args['id'] as String? : args as String?;

    if (id == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Center(
            child: Text('Oturum seçilmedi', style: SwanType.bodySm(c.inkMuted)),
          ),
        ),
        bottomNavigationBar: const SwanBottomNav(),
      );
    }

    final overview = ref.watch(sessionOverviewProvider(id));
    final rows = ref.watch(sessionSummaryProvider(id));

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 120),
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(SwanRadius.sm),
                        border: Border.all(color: c.line),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.md),
                  Text('Oturum sonucu', style: SwanType.h2(c.ink)),
                ]),
                const SizedBox(height: SwanSpace.lg),

                overview.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Text('$e', style: SwanType.bodySm(c.danger)),
                  data: (o) => o == null
                      ? const SizedBox.shrink()
                      : _overviewCard(context, ref, c, id, o),
                ),

                const SizedBox(height: SwanSpace.xl),
                Text('Sporcular', style: SwanType.h3(c.ink)),
                const SizedBox(height: SwanSpace.sm),

                rows.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Text('$e', style: SwanType.bodySm(c.danger)),
                  data: (list) => list.isEmpty
                      ? Text('Bu oturuma kimse katılmadı.',
                          style: SwanType.bodySm(c.inkMuted))
                      : Column(
                          children: [for (final r in list) _row(c, r)],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _overviewCard(BuildContext context, WidgetRef ref, SwanPalette c,
          String id, SessionOverview o) =>
      Container(
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          border: Border.all(color: c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(o.protocolName, style: SwanType.h3(c.ink)),
          if (o.protocolVersion > 1)
            Text('Şablon sürümü v${o.protocolVersion}',
                style: SwanType.caption(c.inkMuted)),
          const SizedBox(height: SwanSpace.md),

          Wrap(spacing: SwanSpace.xl, runSpacing: SwanSpace.md, children: [
            _stat(c, 'Katılan', '${o.joinedCount}'),
            _stat(c, 'Tamamlayan', '${o.completedCount}'),
            _stat(c, 'Skor girmeyen', '${o.noScoreCount}',
                warn: o.noScoreCount > 0),
            _stat(c, 'Onay bekleyen', '${o.awaitingLock}'),
          ]),
          const SizedBox(height: SwanSpace.md),
          Wrap(spacing: SwanSpace.xl, runSpacing: SwanSpace.md, children: [
            _stat(c, 'Takım toplamı', _num(o.teamTotal)),
            _stat(c, 'Oturum ortalaması', _num(o.sessionAvg)),
            // Hedeflenen ve kaydedilen atış — spec'in istediği karşılaştırma.
            _stat(c, 'Atış', '${o.unitsRecorded}/${o.unitsExpected}'),
          ]),

          if (o.status == 'review') ...[
            const SizedBox(height: SwanSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final ok = await _confirmLock(context);
                  if (ok != true) return;
                  await ref
                      .read(trainingSessionServiceProvider)
                      .lockResults(id);
                  ref.invalidate(sessionOverviewProvider(id));
                  ref.invalidate(sessionSummaryProvider(id));
                },
                style: FilledButton.styleFrom(backgroundColor: c.accent),
                child: const Text('Onayla ve kilitle'),
              ),
            ),
            const SizedBox(height: SwanSpace.xs),
            Text(
              'Onaydan sonra sporcular skorlarını değiştiremez. Düzeltme '
              'gerekirse gerekçeyle sen yaparsın.',
              style: SwanType.caption(c.inkMuted),
            ),
          ],
        ]),
      );

  Future<bool?> _confirmLock(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sonuçları onayla'),
          content: const Text(
              'Skorlar kilitlenecek ve sporcular değiştiremeyecek. '
              'Eksik sonuçlar eksik olarak kalır.'),
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

  Widget _stat(SwanPalette c, String label, String value,
          {bool warn = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: SwanType.h2(warn ? c.warning : c.ink)),
        Text(label, style: SwanType.caption(c.inkMuted)),
      ]);

  Widget _row(SwanPalette c, SessionSummaryRow r) => Container(
        margin: const EdgeInsets.only(bottom: SwanSpace.sm),
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: r.needsReview ? c.warning : c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.athleteName, style: SwanType.body(c.ink))),
            if (r.lane != null)
              Text('Kulvar ${r.lane}', style: SwanType.caption(c.inkMuted)),
            if (r.locked) ...[
              const SizedBox(width: SwanSpace.sm),
              Icon(Icons.lock_rounded, size: 13, color: c.inkMuted),
            ],
          ]),
          const SizedBox(height: SwanSpace.sm),

          Wrap(spacing: SwanSpace.lg, runSpacing: SwanSpace.xs, children: [
            _mini(c, 'Toplam', _num(r.totalScore)),
            _mini(c, 'Set ort.', _num(r.avgSet)),
            _mini(c, 'En iyi', _num(r.bestSet)),
            _mini(c, 'Set', '${r.setsDone}/${r.setsExpected}'),
            _mini(c, 'Atış', '${r.unitsRecorded}/${r.unitsExpected}'),
            if (r.rpe != null) _mini(c, 'Zorluk', '${r.rpe}/10'),
          ]),

          if (r.progression.isNotEmpty) ...[
            const SizedBox(height: SwanSpace.sm),
            Text(
              // Girilmemiş set "—" görünüyor; 0 çizmek düşüş gibi okunurdu.
              r.progression
                  .map((v) => v == null ? '—' : _num(v))
                  .join('  →  '),
              style: SwanType.bodySm(c.ink),
            ),
          ],

          if (r.scoreBuckets.isNotEmpty) ...[
            const SizedBox(height: SwanSpace.xs),
            Text(
              _buckets(r.scoreBuckets),
              style: SwanType.caption(c.inkMuted),
            ),
          ],

          if (r.needsReview) ...[
            const SizedBox(height: SwanSpace.sm),
            Wrap(spacing: SwanSpace.xs, runSpacing: SwanSpace.xs, children: [
              for (final f in r.reviewFlags)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SwanSpace.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                  ),
                  child: Text(r.flagLabel(f),
                      style: SwanType.caption(c.warning)),
                ),
            ]),
          ],
        ]),
      );

  Widget _mini(SwanPalette c, String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
        Text(label, style: SwanType.caption(c.inkMuted)),
      ]);

  /// `10 × 4 · 9 × 7` — yüksek puandan aşağı.
  static String _buckets(Map<String, int> b) {
    final keys = b.keys.toList()
      ..sort((a, z) =>
          (num.tryParse(z) ?? 0).compareTo(num.tryParse(a) ?? 0));
    return keys.map((k) => '$k × ${b[k]}').join('  ·  ');
  }

  static String _num(num? v) {
    if (v == null) return '—';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }
}
