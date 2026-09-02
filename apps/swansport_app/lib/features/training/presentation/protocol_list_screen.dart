import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Antrenman şablonları ve oturum başlatma.
///
/// Şablon düzenlemek mevcut satırı DEĞİŞTİRMİYOR, yeni sürüm yazıyor
/// (`revise_training_protocol`). Geçmiş oturumlar başladıkları sürüme bağlı
/// kalıyor — sonuçlarının anlamı değişmiyor. Bu kural veritabanında
/// tetikleyiciyle zorlanıyor, burada yalnızca anlatılıyor.
class ProtocolListScreen extends ConsumerWidget {
  const ProtocolListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final protocols = ref.watch(trainingProtocolsProvider);

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
                  Text('Antrenman şablonları', style: SwanType.h2(c.ink)),
                ]),
                const SizedBox(height: SwanSpace.lg),

                protocols.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Text('$e', style: SwanType.bodySm(c.danger)),
                  data: (list) => list.isEmpty
                      ? Text(
                          'Henüz şablon yok. Platform şablonları kulübünün '
                          'branşına göre görünür.',
                          style: SwanType.bodySm(c.inkMuted))
                      : Column(children: [
                          for (final p in list) _card(context, ref, c, p),
                        ]),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, SwanPalette c,
          TrainingProtocol p) =>
      Container(
        margin: const EdgeInsets.only(bottom: SwanSpace.md),
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          border: Border.all(color: c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.name, style: SwanType.h3(c.ink))),
            if (p.versionLabel != null)
              Text(p.versionLabel!, style: SwanType.caption(c.inkMuted)),
            if (p.isPlatformTemplate) ...[
              const SizedBox(width: SwanSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: SwanSpace.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Text('Hazır', style: SwanType.caption(c.inkMuted)),
              ),
            ],
          ]),

          if (p.description != null) ...[
            const SizedBox(height: SwanSpace.xs),
            Text(p.description!, style: SwanType.bodySm(c.inkMuted)),
          ],

          const SizedBox(height: SwanSpace.md),
          Text(
            _summary(p),
            style: SwanType.caption(c.inkMuted),
          ),

          const SizedBox(height: SwanSpace.md),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _start(context, ref, p),
                style: FilledButton.styleFrom(backgroundColor: c.accent),
                child: const Text('Oturum başlat'),
              ),
            ),
          ]),
        ]),
      );

  /// "10 set × 3 ok · en fazla 10 puan · Puanlı"
  static String _summary(TrainingProtocol p) {
    final cfg = p.config;
    final unit = (p.branch as ArcheryDefinition?)?.unitLabel ?? 'tekrar';
    return '${cfg.setCount} set × ${cfg.unitsPerSet} $unit'
        '  ·  en fazla ${cfg.maxUnitScore} puan'
        '  ·  ${cfg.mode.label}';
  }

  Future<void> _start(
      BuildContext context, WidgetRef ref, TrainingProtocol p) async {
    final rhythm = await showModalBottomSheet<SessionRhythm>(
      context: context,
      builder: (ctx) {
        final c = ctx.swan;
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(SwanSpace.lg),
              child: Text('Katılım biçimi', style: SwanType.h3(c.ink)),
            ),
            for (final r in SessionRhythm.values)
              ListTile(
                title: Text(r.label, style: SwanType.body(c.ink)),
                subtitle: Text(_rhythmHint(r),
                    style: SwanType.caption(c.inkMuted)),
                onTap: () => Navigator.pop(ctx, r),
              ),
            const SizedBox(height: SwanSpace.md),
          ]),
        );
      },
    );
    if (rhythm == null) return;

    final club = await ref.read(activeClubProvider.future);
    if (club == null) return;

    try {
      final res = await ref.read(trainingSessionServiceProvider).startClubSession(
            clubId: club.id,
            protocolId: p.id,
            rhythm: rhythm,
          );
      if (context.mounted) {
        Navigator.pushNamed(context, '/antrenman-oturumu',
            arguments: {'id': res.id});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  static String _rhythmHint(SessionRhythm r) => switch (r) {
        SessionRhythm.shared =>
          'Aşamaları sen başlatırsın, herkes aynı sayaçla ilerler',
        SessionRhythm.individual =>
          'Sporcu kendi setini ve sayacını kendi başlatır',
        SessionRhythm.mixed =>
          'Aşamayı sen başlatırsın, sporcu kendi setini tamamlar',
      };
}
