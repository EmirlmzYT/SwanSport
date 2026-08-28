import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';

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
            content: Text(msg), backgroundColor: const Color(0xFFF43F5E)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
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
            Text('Şikayet Et', style: sora(20, FontWeight.w800, ink)),
            const SizedBox(height: 6),
            Text('Şikayetin platform yöneticisine iletilir; kimliğin '
                'içeriği paylaşan kişiyle paylaşılmaz.',
                style:
                    jakarta(12, FontWeight.w500, SwanColors.textSecondary)),
            const SizedBox(height: 18),

            Text('SEBEP',
                style: jakarta(10.5, FontWeight.w800, SwanColors.textSecondary,
                    ls: 1.1)),
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
                    Text(r.label, style: jakarta(13, FontWeight.w700, ink)),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 8),
            TextField(
              controller: _detail,
              minLines: 2,
              maxLines: 4,
              style: jakarta(13.5, FontWeight.w500, ink),
              decoration: InputDecoration(
                hintText: 'Eklemek istediğin bir şey var mı? (isteğe bağlı)',
                hintStyle:
                    jakarta(12.5, FontWeight.w500, SwanColors.textSecondary),
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
                  color: const Color(0xFFF43F5E),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(_busy ? 'Gönderiliyor…' : 'Şikayeti Gönder',
                    style: jakarta(14.5, FontWeight.w800, Colors.white)),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Vazgeç',
                    style: jakarta(
                        13, FontWeight.w700, SwanColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
