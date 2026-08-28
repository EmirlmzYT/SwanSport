import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';

/// Kulüp profilindeki "Kulübe Başvur" düğmesi.
///
/// Ferdi/lisanslı sporcular ve antrenörler istedikleri kulübe başvurabilir.
/// Zaten üyeyse ya da bekleyen başvurusu varsa durum gösterilir.
class ClubApplyButton extends ConsumerWidget {
  const ClubApplyButton({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  final String clubId;
  final String clubName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final myClubs = ref.watch(myClubsProvider).valueOrNull ?? const [];
    final isMember = myClubs.any((c) => c.id == clubId);
    if (isMember) {
      return _info(surf, line, ink, Icons.check_circle_rounded,
          'Bu kulübün üyesisin', const Color(0xFF10B981));
    }

    final apps = ref.watch(myApplicationsProvider).valueOrNull ?? const [];
    final existing =
        apps.where((a) => a.clubId == clubId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (existing.isNotEmpty && existing.first.isPending) {
      return _info(surf, line, ink, Icons.schedule_rounded,
          'Başvurun inceleniyor', const Color(0xFFD9860B));
    }
    if (existing.isNotEmpty && existing.first.status == 'rejected') {
      return Column(children: [
        _info(surf, line, ink, Icons.cancel_rounded, 'Başvurun reddedildi',
            const Color(0xFFF43F5E)),
        const SizedBox(height: 8),
        _applyButton(context, ref, isDark, ink, label: 'Tekrar Başvur'),
      ]);
    }

    return _applyButton(context, ref, isDark, ink);
  }

  Widget _info(Color surf, Color line, Color ink, IconData icon, String text,
      Color color) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(text, style: jakarta(13.5, FontWeight.w800, color)),
        ],
      ),
    );
  }

  Widget _applyButton(
      BuildContext context, WidgetRef ref, bool isDark, Color ink,
      {String label = 'Kulübe Başvur'}) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    return GestureDetector(
      onTap: () => _openSheet(context, ref),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_add_rounded, size: 18, color: kTeal),
            const SizedBox(width: 8),
            Text(label, style: jakarta(13.5, FontWeight.w800, ink)),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ApplySheet(clubId: clubId, clubName: clubName),
    );
    if (sent == true) {
      ref.invalidate(myApplicationsProvider);
    }
  }
}

class _ApplySheet extends ConsumerStatefulWidget {
  const _ApplySheet({required this.clubId, required this.clubName});
  final String clubId;
  final String clubName;

  @override
  ConsumerState<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends ConsumerState<_ApplySheet> {
  final _msg = TextEditingController();
  String _role = 'athlete';
  bool _busy = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ref.read(clubApplicationServiceProvider).apply(
            widget.clubId,
            role: _role,
            message: _msg.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Başvurun gönderildi'), backgroundColor: kTeal));
        Navigator.pop(context, true);
      }
    } catch (e) {
      final raw = '$e';
      final msg = raw.contains('doğrulat')
          ? 'Başvuru için önce kimliğini doğrulatmalısın.'
          : raw.contains('zaten üyesisin')
              ? 'Bu kulübün zaten üyesisin.'
              : raw.contains('bekleyen bir başvurun')
                  ? 'Bu kulübe bekleyen bir başvurun zaten var.'
                  : 'Başvuru gönderilemedi: $e';
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
          Text('Kulübe Başvur', style: sora(20, FontWeight.w800, ink)),
          const SizedBox(height: 4),
          Text(widget.clubName,
              style: jakarta(13, FontWeight.w700, kTeal)),
          const SizedBox(height: 18),

          Text('NE OLARAK KATILMAK İSTİYORSUN?',
              style: jakarta(10.5, FontWeight.w800, SwanColors.textSecondary,
                  ls: 1.1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: alt, borderRadius: BorderRadius.circular(13)),
            child: Row(children: [
              _roleTab('Sporcu', 'athlete', ink, surf),
              _roleTab('Antrenör', 'coach', ink, surf),
            ]),
          ),
          const SizedBox(height: 16),

          Text('MESAJIN (İSTEĞE BAĞLI)',
              style: jakarta(10.5, FontWeight.w800, SwanColors.textSecondary,
                  ls: 1.1)),
          const SizedBox(height: 8),
          TextField(
            controller: _msg,
            minLines: 2,
            maxLines: 4,
            style: jakarta(13.5, FontWeight.w500, ink),
            decoration: InputDecoration(
              hintText: 'Kendini kısaca tanıt…',
              hintStyle:
                  jakarta(13, FontWeight.w500, SwanColors.textSecondary),
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
                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: kTeal.withValues(alpha: .32),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Text(_busy ? 'Gönderiliyor…' : 'Başvuruyu Gönder',
                  style: jakarta(14.5, FontWeight.w800, Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Kulüp yetkilisi başvurunu inceleyip karar verecek.',
                style:
                    jakarta(11, FontWeight.w500, SwanColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _roleTab(String label, String value, Color ink, Color surf) {
    final on = _role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = value),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: on ? surf : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: jakarta(
                  12.5, FontWeight.w800, on ? ink : SwanColors.textSecondary)),
        ),
      ),
    );
  }
}
