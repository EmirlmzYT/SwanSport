import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

class AnnouncementReceiptSheet extends ConsumerStatefulWidget {
  const AnnouncementReceiptSheet({required this.id, super.key});
  final String id;
  @override
  ConsumerState<AnnouncementReceiptSheet> createState() =>
      _AnnouncementReceiptSheetState();
}

class _AnnouncementReceiptSheetState
    extends ConsumerState<AnnouncementReceiptSheet> {
  AnnouncementDetail? _detail;
  bool _busy = true;
  String? _error;
  late final String? _account =
      ref.read(authSessionProvider).valueOrNull?.user.id;
  bool get _valid =>
      mounted && _account == ref.read(authSessionProvider).valueOrNull?.user.id;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail =
          await ref.read(announcementReceiptServiceProvider).load(widget.id);
      if (!_valid) return;
      setState(() {
        _detail = detail;
        _busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_valid) _record(false);
      });
    } catch (_) {
      if (_valid)
        setState(() {
          _busy = false;
          _error = 'Duyuru yüklenemedi. Yeniden dene.';
        });
    }
  }

  Future<void> _record(bool acknowledge) async {
    if (!_valid || _detail == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = await ref
          .read(announcementReceiptServiceProvider)
          .record(_detail!, acknowledge: acknowledge);
      if (_valid)
        setState(() {
          _detail = detail;
          _busy = false;
        });
    } catch (_) {
      if (_valid)
        setState(() {
          _busy = false;
          _error = 'Kayıt doğrulanamadı. Duyuru değişmiş olabilir; yenile.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final account = ref.watch(authSessionProvider).valueOrNull?.user.id;
    if (account != _account) return const SizedBox.shrink();
    final d = _detail;
    return SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(SwanSpace.lg),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (d != null) ...[
                    Text(d.title, style: SwanType.h3(c.ink)),
                    const SizedBox(height: SwanSpace.md),
                    Text(d.body, style: SwanType.bodySm(c.ink)),
                    const SizedBox(height: SwanSpace.md),
                    if (d.readCount != null)
                      Text(
                          '${d.readCount} okundu · ${d.acknowledgedCount} onaylandı',
                          style: SwanType.caption(c.inkMuted)),
                    Text(
                        'Bu işlem duyuruyu okuduğunu belirtir; yoklama veya hukuki rıza değildir.',
                        style: SwanType.caption(c.inkMuted)),
                    const SizedBox(height: SwanSpace.sm),
                    FilledButton.tonal(
                        onPressed: _busy || d.acknowledgedAt != null
                            ? null
                            : () => _record(true),
                        child: Text(d.acknowledgedAt != null
                            ? 'Onayın kaydedildi'
                            : 'Okudum, onaylıyorum')),
                  ],
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(_error!, style: SwanType.bodySm(c.danger)),
                    TextButton(onPressed: _load, child: const Text('Yenile'))
                  ],
                ])));
  }
}
