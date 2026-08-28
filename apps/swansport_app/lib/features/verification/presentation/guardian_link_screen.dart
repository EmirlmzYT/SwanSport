import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';

/// Davet kodu girişi.
///
/// Tek ekran, iki amaç: veli çocuğuna bağlanıyor, muhasebeci kulübün
/// defterine. Kodun ne işe yaradığını sunucu belirliyor (`invite_codes.purpose`),
/// bu yüzden burada ayrı akış yok — ikinci bir ekran yazmak aynı RPC'yi iki
/// yerden çağırmak olurdu.
class GuardianLinkScreen extends ConsumerStatefulWidget {
  const GuardianLinkScreen({super.key});

  @override
  ConsumerState<GuardianLinkScreen> createState() => _GuardianLinkScreenState();
}

class _GuardianLinkScreenState extends ConsumerState<GuardianLinkScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: line),),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 15, color: ink,),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF2563EB)],),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child:
                      Text('V', style: sora(24, FontWeight.w800, Colors.white)),
                ),
                const SizedBox(height: 20),
                Text('Davet kodu', style: sora(28, FontWeight.w800, ink)),
                const SizedBox(height: 8),
                Text(
                    'Sporcunun (veya kulübün) verdiği tek kullanımlık davet '
                    'kodunu gir.',
                    style: jakarta(
                        13.5, FontWeight.w500, SwanColors.textSecondary,),),
                const SizedBox(height: 22),
                TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: sora(22, FontWeight.w800, ink, ls: 4),
                  decoration: InputDecoration(
                    hintText: 'K O D',
                    hintStyle: sora(
                        20, FontWeight.w700, SwanColors.textSecondary,
                        ls: 4,),
                    filled: true,
                    fillColor: surf,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: line),),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: kTeal, width: 1.5),),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: SwanColors.textSecondary,),
                    const SizedBox(width: 6),
                    Text('Kod tek kullanımlık ve süreli — veren kişiden yeni kod iste',
                        style: jakarta(
                            11.5, FontWeight.w600, SwanColors.textSecondary,),),
                  ],
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _busy ? null : _redeem,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                            color: kTeal.withValues(alpha: .34),
                            blurRadius: 18,
                            offset: const Offset(0, 8),),
                      ],
                    ),
                    child: Text(_busy ? 'Bağlanıyor…' : 'Sporcuya Bağlan',
                        style: jakarta(14.5, FontWeight.w800, Colors.white),),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _redeem() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(verificationServiceProvider).redeemInvite(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bağlandın.'),
            backgroundColor: kTeal,),);
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: const Color(0xFFF43F5E),),);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
