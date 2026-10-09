import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';

class TurfDutyInviteDialog extends ConsumerStatefulWidget {
  const TurfDutyInviteDialog({super.key, required this.fieldId});
  final String fieldId;
  @override
  ConsumerState<TurfDutyInviteDialog> createState() =>
      _TurfDutyInviteDialogState();
}

class _TurfDutyInviteDialogState extends ConsumerState<TurfDutyInviteDialog> {
  int _hours = 4;
  String? _op, _error;
  bool _busy = false, _sessionChanged = false;
  TurfDutyInvite? _invite;
  Future<void> _create() async {
    if (_busy || _sessionChanged) return;
    setState(() {
      _busy = true;
      _error = null;
      _op ??= diagnosticId();
    });
    try {
      final invite = await ref
          .read(sahaOperationsServiceProvider)
          .createDuty(widget.fieldId, _hours, _op!);
      if (!mounted || _sessionChanged) return;
      setState(() => _invite = invite);
      ref.invalidate(turfDutiesProvider);
    } catch (_) {
      if (mounted && !_sessionChanged) {
        setState(
          () => _error =
              'Davet sonucu doğrulanamadı. Aynı işlemle tekrar dene veya Saha İşlemlerim’de kontrol et.',
        );
      }
    } finally {
      if (mounted && !_sessionChanged) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.hasValue == true &&
          next.hasValue &&
          previous!.valueOrNull?.user.id != next.valueOrNull?.user.id) {
        _sessionChanged = true;
        unawaited(Navigator.maybePop(context));
      }
    });
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text('Saha görevini devret', style: SwanType.h3(c.ink)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_invite == null) ...[
              Text(
                'Görev süresi şimdi başlar. Davet en fazla 24 saatte kabul edilir. Yalnız doluluk işaretleme açılır; kalıcı yöneticilik ve yeniden devir hakkı verilmez.',
                style: SwanType.bodySm(c.ink),
              ),
              DropdownButton<int>(
                value: _hours,
                isExpanded: true,
                onChanged: _busy || _op != null
                    ? null
                    : (value) => setState(() => _hours = value!),
                items: [
                  for (final hours in [1, 4, 12, 24, 72, 168])
                    DropdownMenuItem(value: hours, child: Text('$hours saat')),
                ],
              ),
            ] else ...[
              Text(_invite!.code, style: SwanType.body(c.ink)),
              Text(
                'Görev bitişi: ${sahaTime(_invite!.validUntil)}',
                style: SwanType.bodySm(c.inkMuted),
              ),
              Text(
                'Son kabul: ${sahaTime(_invite!.inviteUntil)}',
                style: SwanType.bodySm(c.inkMuted),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: _invite!.code));
                    if (mounted && !_sessionChanged) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Davet kodu kopyalandı.'),
                        ),
                      );
                    }
                  } catch (_) {
                    if (mounted) setState(() => _error = 'Kod kopyalanamadı.');
                  }
                },
                child: const Text('Kodu kopyala'),
              ),
            ],
            if (_error != null) Text(_error!, style: SwanType.bodySm(c.danger)),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        if (_invite == null)
          FilledButton(
            onPressed: _busy ? null : _create,
            child: Text(
              _op == null ? 'Davet oluştur' : 'Aynı işlemi tekrar dene',
            ),
          ),
      ],
    );
  }
}
