import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

/// Aşama sayacı.
///
/// SAYAÇ ZAMAN DAMGASINDAN HESAPLANIYOR. Bu widget saniye saymıyor; her
/// saniye yeniden **çiziyor** ve kalan süreyi `phase_ends_at` ile şimdiki
/// zamanın farkından buluyor. Fark önemli: uygulama arka plana gidip
/// geldiğinde geri sayan bir sayıcı yanlış devam ederdi, bu etmiyor.
///
/// SÜRE DOLUNCA KENDİLİĞİNDEN İLERLEMİYOR. Sahte durum üretmek yerine
/// "süre doldu" deyip kararı insana bırakıyor — [onExpiredAction] o kararın
/// düğmesi.
class PhaseTimer extends StatefulWidget {
  const PhaseTimer({
    super.key,
    required this.phase,
    required this.endsAt,
    required this.paused,
    required this.currentSet,
    required this.setCount,
    this.onExpiredAction,
    this.expiredActionLabel,
  });

  final SessionPhase phase;
  final DateTime? endsAt;
  final bool paused;
  final int currentSet;
  final int setCount;

  /// Süre dolduğunda gösterilecek eylem. `null` ise yalnızca bilgi yazıyor —
  /// sporcu ortak ritimde aşamayı ilerletemiyor.
  final VoidCallback? onExpiredAction;
  final String? expiredActionLabel;

  @override
  State<PhaseTimer> createState() => _PhaseTimerState();
}

class _PhaseTimerState extends State<PhaseTimer> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Yalnızca yeniden çizim için. Durum burada tutulmuyor.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final now = DateTime.now();
    final left = remaining(
      endsAt: widget.endsAt,
      now: now,
      pausedAt: widget.paused ? widget.endsAt : null,
    );
    final expired = !widget.paused &&
        phaseExpired(endsAt: widget.endsAt, now: now);

    // Renk anlamı taşıyor: süre dolmuşsa uyarı, duraklamışsa sönük.
    final tone = expired
        ? c.warning
        : widget.paused
            ? c.inkMuted
            : c.accent;

    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: expired ? c.warning : c.line),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(widget.phase.label, style: SwanType.h3(c.ink)),
          Text('Set ${widget.currentSet}/${widget.setCount}',
              style: SwanType.caption(c.inkMuted)),
        ]),
        const SizedBox(height: SwanSpace.md),

        if (left != null)
          Text(formatRemaining(left), style: SwanType.display(tone))
        else
          // Süresiz aşama — skor girişi sayaçla sınırlanmıyor.
          Text('—', style: SwanType.display(c.inkMuted)),

        const SizedBox(height: SwanSpace.xs),
        Text(
          widget.paused
              ? 'Duraklatıldı'
              : expired
                  ? 'Süre doldu'
                  : widget.phase.hint,
          style: SwanType.bodySm(expired ? c.warning : c.inkMuted),
          textAlign: TextAlign.center,
        ),

        if (expired && widget.onExpiredAction != null) ...[
          const SizedBox(height: SwanSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onExpiredAction,
              style: FilledButton.styleFrom(backgroundColor: c.accent),
              child: Text(widget.expiredActionLabel ?? 'Devam et'),
            ),
          ),
        ],
      ]),
    );
  }
}
