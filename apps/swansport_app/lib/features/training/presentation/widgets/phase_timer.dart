import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.pausedAt,
  });

  final SessionPhase phase;
  final DateTime? endsAt;
  final bool paused;
  final DateTime? pausedAt;
  final int currentSet;
  final int setCount;

  /// Süre dolduğunda gösterilecek eylem. `null` ise yalnızca bilgi yazıyor —
  /// sporcu ortak ritimde aşamayı ilerletemiyor.
  final FutureOr<void> Function()? onExpiredAction;
  final String? expiredActionLabel;

  @override
  State<PhaseTimer> createState() => _PhaseTimerState();
}

class _PhaseTimerState extends State<PhaseTimer> {
  Timer? _tick;
  DateTime? _fallbackPause;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _fallbackPause = widget.paused ? DateTime.now() : null;
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
  void didUpdateWidget(covariant PhaseTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.paused && widget.paused) _fallbackPause = DateTime.now();
    if (!widget.paused) _fallbackPause = null;
    if (oldWidget.phase != widget.phase ||
        oldWidget.currentSet != widget.currentSet) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final now = DateTime.now();
    final left = remaining(
      endsAt: widget.endsAt,
      now: now,
      pausedAt: widget.paused ? widget.pausedAt ?? _fallbackPause : null,
    );
    final expired =
        !widget.paused && phaseExpired(endsAt: widget.endsAt, now: now);

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
          Expanded(
              child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(widget.phase.label,
                key: ValueKey(widget.phase), style: SwanType.h3(c.ink)),
          )),
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
        if (!widget.paused && widget.onExpiredAction != null) ...[
          const SizedBox(height: SwanSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _advancing
                  ? null
                  : () async {
                      setState(() => _advancing = true);
                      try {
                        await widget.onExpiredAction!();
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Aşama ilerletilemedi: $e')));
                      } finally {
                        if (mounted) setState(() => _advancing = false);
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: c.accentFill),
              child: Text(widget.expiredActionLabel ?? 'Devam et'),
            ),
          ),
        ],
      ]),
    );
  }
}
