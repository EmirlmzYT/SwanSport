import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

/// İçerik şikayet sayfasını açar. Gönderildiyse true döner.
Future<bool?> showReportSheet(
  BuildContext context, {
  required String targetType, // post | comment | profile
  required String targetId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.targetType, required this.targetId});
  final String targetType;
  final String targetId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String _reason = kReportReasons.first.key;
  final _detail = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ref.read(moderationServiceProvider).report(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason,
            detail: _detail.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Şikayetin iletildi. Teşekkürler.'),
            backgroundColor: kTeal));
        Navigator.pop(context, true);
      }
    } catch (e) {
      final msg = '$e'.contains('duplicate') || '$e'.contains('unique')
          ? 'Bu içeriği zaten şikayet ettin.'
          : 'Gönderilemedi: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg), backgroundColor: SwanPalette.light.danger));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final grip = isDark ? const Color(0xFF2E3B4E) : const Color(0xFFE4E9F0);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: grip, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Şikayet Et', style: SwanType.h2(ink)),
            const SizedBox(height: 6),
            Text('Şikayetin platform yöneticisine iletilir; kimliğin '
                'içeriği paylaşan kişiyle paylaşılmaz.',
                style:
                    SwanType.caption(SwanColors.textSecondary)),
            const SizedBox(height: 18),

            Text('Sebep', style: SwanType.h3(ink)),
            const SizedBox(height: 8),
            ...kReportReasons.map((r) {
              final on = _reason == r.key;
              return GestureDetector(
                onTap: () => setState(() => _reason = r.key),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: on ? kTeal.withValues(alpha: .08) : alt,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: on ? kTeal : line),
                  ),
                  child: Row(children: [
                    Icon(
                        on
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 19,
                        color: on ? kTeal : SwanColors.textSecondary),
                    const SizedBox(width: 11),
                    Text(r.label, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 8),
            TextField(
              controller: _detail,
              minLines: 2,
              maxLines: 4,
              style: SwanType.bodySm(ink),
              decoration: InputDecoration(
                hintText: 'Eklemek istediğin bir şey var mı? (isteğe bağlı)',
                hintStyle:
                    SwanType.caption(SwanColors.textSecondary),
                filled: true,
                fillColor: alt,
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kTeal, width: 1.5)),
              ),
            ),
            const SizedBox(height: 18),

            GestureDetector(
              onTap: _busy ? null : _send,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SwanPalette.light.danger,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(_busy ? 'Gönderiliyor…' : 'Şikayeti Gönder',
                    style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Vazgeç',
                    style: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
