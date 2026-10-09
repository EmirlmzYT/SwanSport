import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

class SupportFixCard extends ConsumerStatefulWidget {
  const SupportFixCard({super.key, required this.ticketId});
  final String ticketId;
  @override
  ConsumerState<SupportFixCard> createState() => _SupportFixCardState();
}

class _SupportFixCardState extends ConsumerState<SupportFixCard> {
  bool _busy = false;
  Future<void> _respond(DiagnosticFixContext fix, String result) async {
    if (_busy) return;
    setState(() => _busy = true);
    final recorder = ref.read(diagnosticsProvider);
    try {
      await ref.read(diagnosticsServiceProvider).respondFix(
            widget.ticketId,
            fix.fixId!,
            result,
            release: recorder.release,
            platform: recorder.platform,
            application: recorder.application,
          );
      ref.invalidate(supportFixProvider(widget.ticketId));
      ref.invalidate(myTicketsProvider);
      ref.invalidate(ticketMessagesProvider(widget.ticketId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Teyit kaydedilemedi. Güncel düzeltmeyi yenileyip tekrar dene.',),),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final recorder = ref.watch(diagnosticsProvider);
    return ref.watch(supportFixProvider(widget.ticketId)).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => TextButton(
              onPressed: () =>
                  ref.invalidate(supportFixProvider(widget.ticketId)),
              child: const Text('Düzeltme bilgisini yeniden yükle'),),
          data: (fix) {
            if (fix == null) return const SizedBox.shrink();
            return Padding(
                padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Düzeltme takibi', style: SwanType.h3(c.ink)),
                    if (fix.fixId == null)
                      const Text(
                          'Bu talep teknik hataya bağlı. Düzeltme bildirimi bekleniyor.',)
                    else ...[
                      Text('Bildirilen sürüm: ${fix.release} · ${fix.platform}',
                          style: SwanType.body(c.ink),),
                      Text(
                          switch (fix.response) {
                            'confirmed' => 'Çözüldüğünü teyit ettin.',
                            'still_failing' =>
                              'Sorunun sürdüğünü bildirdin; talep tekrar incelemede.',
                            _ =>
                              'Bu sürümde aynı işlemi dene ve sonucu bildir.',
                          },
                          style: SwanType.bodySm(c.inkMuted),),
                      if (!fix.canRespond(recorder) &&
                          fix.ticketStatus != 'closed')
                        const Text(
                            'Teyit için belirtilen platformda bu sürüm veya sonrasını kullan. Normal yanıtla ekibe yazabilirsin.',),
                      Wrap(spacing: SwanSpace.sm, children: [
                        FilledButton(
                            onPressed: _busy ||
                                    !fix.canRespond(recorder) ||
                                    fix.response == 'confirmed'
                                ? null
                                : () => _respond(fix, 'confirmed'),
                            child: const Text('Sorun çözüldü'),),
                        OutlinedButton(
                            onPressed: _busy ||
                                    !fix.canRespond(recorder) ||
                                    fix.response == 'still_failing'
                                ? null
                                : () => _respond(fix, 'still_failing'),
                            child: const Text('Sorun devam ediyor'),),
                      ],),
                    ],
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => ref.invalidate(
                                supportFixProvider(widget.ticketId),),
                        child: const Text('Düzeltme durumunu yenile'),),
                  ],
                ),);
          },
        );
  }
}
