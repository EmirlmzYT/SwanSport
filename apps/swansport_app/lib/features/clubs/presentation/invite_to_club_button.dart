import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';

/// Kişi profilinde "Kulübüne Davet Et" düğmesi.
///
/// Yalnızca kulüp yetkilileri (yönetici/antrenör) görür. Eşleşme çift yönlü:
/// kişi kulübe başvurabildiği gibi kulüp de kişiye teklif sunabilir.
class InviteToClubButton extends ConsumerWidget {
  const InviteToClubButton({
    super.key,
    required this.profileId,
    required this.personName,
  });

  final String profileId;
  final String personName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final canInvite =
        club != null && (club.role == 'club_admin' || club.role == 'coach');
    if (!canInvite) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () => _open(context, ref, club.id, club.name),
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
              const Icon(Icons.mail_outline_rounded, size: 18, color: kTeal),
              const SizedBox(width: 8),
              Text('Kulübüne Davet Et',
                  style: jakarta(13.5, FontWeight.w800, ink)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, String clubId, String clubName) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(
        clubId: clubId,
        clubName: clubName,
        profileId: profileId,
        personName: personName,
      ),
    );
    if (sent == true) {
      ref.invalidate(myApplicationsProvider);
    }
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({
    required this.clubId,
    required this.clubName,
    required this.profileId,
    required this.personName,
  });

  final String clubId;
  final String clubName;
  final String profileId;
  final String personName;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
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
      await ref.read(clubApplicationServiceProvider).offerToPerson(
            widget.clubId,
            widget.profileId,
            role: _role,
            message: _msg.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Davet gönderildi'), backgroundColor: kTeal));
        Navigator.pop(context, true);
      }
    } catch (e) {
      final raw = '$e';
      final msg = raw.contains('zaten kulübün üyesi')
          ? 'Bu kişi zaten kulübün üyesi.'
          : raw.contains('bekleyen bir teklifin')
              ? 'Bu kişiye bekleyen bir teklifin zaten var.'
              : 'Davet gönderilemedi: $e';
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
          Text('Kulübe Davet Et', style: sora(20, FontWeight.w800, ink)),
          const SizedBox(height: 4),
          Text('${widget.personName} → ${widget.clubName}',
              style: jakarta(13, FontWeight.w700, kTeal)),
          const SizedBox(height: 18),

          Text('HANGİ ROLLE?',
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
              hintText: 'Kulübümüze katılmak ister misin?',
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
              ),
              child: Text(_busy ? 'Gönderiliyor…' : 'Daveti Gönder',
                  style: jakarta(14.5, FontWeight.w800, Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Kişi kabul ederse kulübe katılır.',
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
